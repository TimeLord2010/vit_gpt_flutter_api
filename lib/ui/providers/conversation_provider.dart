import 'dart:async';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vit_dart_extensions/vit_dart_extensions.dart';
import 'package:vit_gpt_dart_api/factories/http_client.dart';
import 'package:vit_gpt_dart_api/repositories/assistant_repository.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';

import '../../data/enums/chat_status.dart';
import '../../factories/logger.dart';
import '../../features/repositories/debouncer.dart';
import '../../features/usecases/get_error_message.dart';
import 'voice_mode_provider.dart';

class ConversationProvider with ChangeNotifier {
  final BuildContext context;
  Conversation? originalConversation;
  final void Function(Conversation) onCreate;
  final void Function(String id) onDelete;
  final void Function(Map<String, dynamic>)? onJsonComplete;

  /// Called after the user sent a message and the model finished responding
  /// by text.
  final void Function(ConversationProvider self)? onTextResponse;

  ConversationProvider({
    required this.context,
    required this.onDelete,
    required this.onCreate,
    this.originalConversation,
    this.onTextResponse,
    this.onJsonComplete,
    Assistant? assistant,
  }) : _assistant = assistant;

  final scrollController = ScrollController();

  /// Indicates the UI is at the bottom of the list view.
  bool isAtBottom = true;

  final controller = TextEditingController();

  late final voiceModeProvider = VoiceModeProvider(
    errorReporter: (context, message) {
      _showError(
        title: context,
        message: message,
      );
    },
    notifyListeners: () => notifyListeners(),
    isVoiceMode: () => isVoiceMode,
    setStatus: (status) => this.status = status,
    getStatus: () => status,
    send: ({
      required onChunk,
      required text,
    }) async {
      controller.text = text;
      await send(
        onChunk: onChunk,
        endStatus: null,
      );
    },
  );

  Conversation? conversation;

  Assistant? _assistant;
  Assistant? get assistant => _assistant;
  set assistant(Assistant? value) {
    _assistant = value;
    notifyListeners();
  }

  // MARK: status
  ChatStatus _status = ChatStatus.idle;
  ChatStatus get status => _status;
  set status(ChatStatus newStatus) {
    if (_status != newStatus) {
      logger.debug(
          'Changing chat status from ${_status.name} to ${newStatus.name}');
    }
    _status = newStatus;
  }

  bool get isResponding {
    return switch (status) {
      ChatStatus.speaking => true,
      ChatStatus.answeringAndSpeaking => true,
      ChatStatus.sendingPrompt => true,
      ChatStatus.answering => true,
      _ => false,
    };
  }

  bool get isVoiceMode {
    if (voiceModeProvider.isInVoiceMode) return true;
    return switch (status) {
      ChatStatus.answeringAndSpeaking => true,
      ChatStatus.listeningToUser => true,
      ChatStatus.transcribing => true,
      ChatStatus.speaking => true,
      _ => false,
    };
  }

  String get title {
    String? getTitle(Conversation? c) {
      if (c == null) return null;
      var title = c.title;
      if (title != null && title.isNotEmpty) return title;
      if (c.id != null) return c.id;
      return null;
    }

    var title = getTitle(conversation);
    if (title != null) return title;

    var originalTitle = getTitle(originalConversation);
    if (originalTitle != null) {
      return originalTitle;
    }
    return 'Nova conversa';
  }

  List<Message> get messages {
    return originalConversation?.messages ?? conversation?.messages ?? [];
  }

  // MARK: METHODS

  @override
  void dispose() {
    //voiceModeProvider.dispose();
    super.dispose();
  }

  // MARK: setup

  Future<void> setup() async {
    var c = originalConversation;
    if (c == null) {
      logger.warn('Aborting messages load: no original conversation');
      return;
    }
    if (c.messages.isNotEmpty) {
      logger.warn('Aborting load messages: messages already found');
      return;
    }
    var id = c.id;
    if (id == null) {
      logger.warn('Unable to load messages: no id');
      return;
    }
    var messages = await loadThreadMessages(id);
    logger.info('Found ${messages.length} messages');
    messages.sortByDate((x) => x.date);
    c.messages.addAll(messages);

    notifyListeners();
  }

  Future<void> updateConversation(Conversation? conversation) async {
    originalConversation = conversation;
    this.conversation = conversation;
    notifyListeners();
    await setup();
  }

  // MARK: send

  Future<void> send({
    BuildContext? context,
    void Function(String chunk)? onChunk,
    ChatStatus? endStatus = ChatStatus.idle,
  }) async {
    try {
      if (isResponding) {
        return;
      }
      status = ChatStatus.sendingPrompt;
      notifyListeners();

      // Ensuring conversation is not null.
      if (conversation == null) {
        if (originalConversation != null) {
          conversation = originalConversation;
        } else {
          var created = await createThread();
          conversation = created;
          onCreate(created);
        }
      }

      // Updating 'lastUpdate' date of conversation
      var updated = conversation!.recordUpdate();
      if (updated) {
        unawaited(saveThread(conversation!.id!, conversation!.metadata!));
      }

      // Preparing to fetch response
      var model = await getSavedGptModel();
      CompletionModel completion;
      if (assistant == null) {
        completion = CompletionRepository(
          dio: httpClient,
          model: model ?? GptModel.gpt4oMini,
          messages: conversation!.messages,
        );
      } else {
        completion = AssistantRepository(
          dio: httpClient,
          assistantId: assistant!.id,
          threadId: conversation!.id!,
        );
      }
      var rep = ConversationRepository(
        conversation: conversation!,
        threads: createThreadsRepository(),
        completion: completion,
        onError: (exception, remainingRetries) async {
          if (context == null) {
            return;
          }
          await _showError(
            title: exception.code ?? 'Falha',
            message: exception.message,
          );
        },
        onJsonComplete: onJsonComplete,
      );
      var text = controller.text;

      var scrollDebouncer = Debouncer(
        delay: const Duration(milliseconds: 250),
        action: () {
          _scrollToBottomIfNeeded();
          notifyListeners();
        },
      );

      // Streaming response
      controller.clear();
      await rep.prompt(
        text,
        onChunk: (msg, chunk) {
          if (status != ChatStatus.answeringAndSpeaking) {
            status = ChatStatus.answering;
          }
          if (onChunk != null) onChunk(chunk);

          scrollDebouncer.execute();
          // notifyListeners();
        },
      );
      logger.info('Finished reading response stream');

      if (onTextResponse != null) onTextResponse!(this);
    } catch (e) {
      var msg = getErrorMessage(e) ?? 'Failed to fetch response';
      logger.error(msg);
      if (context != null) {
        await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Failed to get response'),
              content: Text(msg),
            );
          },
        );
      }
    } finally {
      // Updating to the end state
      if (endStatus != null) {
        status = endStatus;
      }
      notifyListeners();
    }
  }

  // MARK: _showError

  Future<void> _showError({
    String? title,
    String? message,
  }) async {
    var controller = DefaultFlashController(
      context,
      duration: const Duration(seconds: 5),
      builder: (context, controller) {
        return FlashBar(
          controller: controller,
          indicatorColor: Colors.red,
          icon: const Icon(Icons.error),
          title: Text(title ?? 'Falha'),
          content: Text(message ?? ''),
          actions: [
            TextButton(
              onPressed: () => controller.dismiss(true),
              child: const Text('Ok'),
            )
          ],
        );
      },
    );
    await controller.show();
  }

  // MARK: delete

  Future<void> delete() async {
    Conversation? c = originalConversation ?? conversation;
    if (c == null) {
      return;
    }

    var id = c.id;
    if (id == null) {
      return;
    }

    await deleteThread(id);
    onDelete(id);
  }

  void _scrollToBottomIfNeeded() {
    // Só rola automaticamente para o final se o usuário estiver lá
    if (!isAtBottom) {
      return;
    }
    if (scrollController.hasClients) {
      unawaited(scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      ));
    }
  }

  void updateUI() {
    notifyListeners();
  }
}
