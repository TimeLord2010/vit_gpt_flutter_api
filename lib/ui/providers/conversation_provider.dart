import 'dart:async';

import 'package:easy_debounce/easy_throttle.dart';
import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vit_dart_extensions/vit_dart_extensions.dart';
import 'package:vit_gpt_dart_api/factories/create_assistant_repository.dart';
import 'package:vit_gpt_dart_api/factories/http_client.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';
import 'package:vit_gpt_flutter_api/data/contracts/voice_mode_contract.dart';
import 'package:vit_gpt_flutter_api/data/vit_gpt_configuration.dart';
import 'package:vit_gpt_flutter_api/factories/create_grouped_logger.dart';
import 'package:vit_gpt_flutter_api/ui/providers/realtime_voice_mode_provider.dart';

import '../../data/enums/chat_status.dart';
import '../../features/usecases/get_error_message.dart';
import 'voice_mode_provider.dart';

var _logger = createGptFlutterLogger(['ConversationProvider']);

class ConversationProvider with ChangeNotifier {
  final BuildContext context;

  /// If provided, this will continue a previous conversation/thread.
  Conversation? conversation;

  /// Called when a conversation/thread is created.
  final void Function(Conversation) onCreate;

  /// Called when a conversation/thread is deleted.
  final void Function(String id) onDelete;

  /// Method to process the original json sent by OpenAI.
  final void Function(Map<String, dynamic>)? onJsonComplete;

  /// Called after the user sent a message and the model finished responding
  /// by text.
  final void Function(ConversationProvider self)? onTextResponse;

  /// [lazyConversationCreation]:
  /// Has no effect if [conversation] is not null.
  ///
  /// If true, creates a thread when the user sends the first message.
  /// Otherwise, it is created when the class is created.
  ConversationProvider({
    required this.context,
    required this.onDelete,
    required this.onCreate,
    this.conversation,
    this.onTextResponse,
    this.onJsonComplete,
    Assistant? assistant,
    bool lazyConversationCreation = false,
  }) : _assistant = assistant {
    if (!lazyConversationCreation) {
      _createConversationIfNecessary();
    }
  }

  DateTime? userSpeechEndTime;

  final scrollController = ScrollController();

  /// Indicates the UI is at the bottom of the list view.
  bool isAtBottom = true;

  final controller = TextEditingController();

  late VoiceModeContract voiceModeProvider = VoiceModeProvider(
    errorReporter: (context, message, {stackTrace}) {
      _showError(
        title: context,
        message: message,
        stackTrace: stackTrace,
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

  /// The assistant to use in the thread.
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
      VitGptFlutterConfiguration.logger.d('Changing chat status from ${_status.name} to ${newStatus.name}');
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

  /// Returns `true`, when the voice mode is ready and working.
  ///
  /// If you need to show to the user a progress indicator, see
  /// [voideModeProvider.isLoadingVoiceMode].
  bool get isVoiceMode {
    var p = voiceModeProvider;
    if (p.isInVoiceMode && !voiceModeProvider.isLoadingVoiceMode) {
      return true;
    }
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

    return 'Nova conversa';
  }

  List<Message> get messages {
    return conversation?.messages ?? [];
  }

  // MARK: METHODS

  @override
  void dispose() {
    voiceModeProvider.dispose();
    super.dispose();
  }

  // MARK: setup

  /// Loads messages from the conversation and sorts them by date.
  Future<void> setup() async {
    var c = conversation;
    if (c == null) {
      VitGptFlutterConfiguration.logger.w('Aborting messages load: no original conversation');
      return;
    }
    if (c.messages.isNotEmpty) {
      VitGptFlutterConfiguration.logger.w('Aborting load messages: messages already found');
      return;
    }
    var id = c.id;
    if (id == null) {
      VitGptFlutterConfiguration.logger.w('Unable to load messages: no id');
      return;
    }
    var messages = await loadThreadMessages(id);
    VitGptFlutterConfiguration.logger.i('Found ${messages.length} messages');
    messages.sortByDate((x) => x.date);
    c.messages.addAll(messages);

    notifyListeners();
  }

  Future<void> updateConversation(Conversation? conversation) async {
    this.conversation = conversation;
    notifyListeners();
    await setup();
  }

  Future<void> _createConversationIfNecessary() async {
    if (conversation != null) {
      return;
    }
    var created = await createThread();
    conversation = created;
    onCreate(created);
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

      await _createConversationIfNecessary();

      var text = controller.text;
      var selfMessage = Message.user(message: text);
      conversation?.messages.add(selfMessage);
      notifyListeners();

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
          model: model!,
        );
      } else {
        var rep = createAssistantRepository(assistant!.id, conversation!.id!);
        completion = rep;
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

      // Streaming response
      controller.clear();
      await rep.prompt(
        previousMessages: [
          if (assistant == null) ...conversation!.messages,
        ],
        onChunk: (msg, chunk) {
          if (status != ChatStatus.answeringAndSpeaking) {
            status = ChatStatus.answering;
          }
          if (onChunk != null) onChunk(chunk);

          EasyThrottle.throttle(
            'scroll',
            Duration(milliseconds: 200),
            () {
              notifyListeners();
              _scrollToBottomIfNeeded();
            },
          );
        },
      );
      VitGptFlutterConfiguration.logger.i('Finished reading response stream');

      if (onTextResponse != null) onTextResponse!(this);
    } catch (e, stackTrace) {
      var msg = getErrorMessage(e);
      VitGptFlutterConfiguration.logger.e(msg, error: e, stackTrace: stackTrace);
      if (context != null && context.mounted) {
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
    StackTrace? stackTrace,
  }) async {
    if (stackTrace != null) {
      VitGptFlutterConfiguration.logger.e(
        '${title ?? 'Erro'}: ${message ?? ''}',
        error: message,
        stackTrace: stackTrace,
      );
    }

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
    Conversation? c = conversation;

    var id = c?.id;
    if (id == null) {
      VitGptFlutterConfiguration.logger.w('Unabled to delete conversation without an id');
      return;
    }

    await deleteThread(id);
    onDelete(id);

    conversation = null;
    notifyListeners();
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

  void updateUI() => notifyListeners();

  void updateVoiceMode(bool useRealtimeApi) {
    voiceModeProvider.stopVoiceMode();
    voiceModeProvider.dispose();

    if (useRealtimeApi) {
      var p = RealtimeVoiceModeProvider(
        onStart: () async {
          notifyListeners();
          await _createConversationIfNecessary();
        },
        setStatus: (status) {
          this.status = status;
          notifyListeners();
        },
        onSpeechEnd: (speechEnd) {
          userSpeechEndTime = DateTime.now();
        },
        onTranscriptionEnd: (transcriptionEnd, audioBytes) async {
          var msg = Message(
            id: transcriptionEnd.id,
            date: userSpeechEndTime ?? DateTime.now(),
            role: transcriptionEnd.role,
            text: transcriptionEnd.content,
            audio: audioBytes,
            itemId: transcriptionEnd.id,
            previousItemId: transcriptionEnd.previousItemId,
          );
          messages.add(msg);

          var id = conversation?.id;
          if (id == null) {
            _logger.e('Unable to create message due to missing conversation id');
            return;
          }

          // We could also add assistant messages here. But we dont receive the
          // "usage" object here.
          if (transcriptionEnd.role == Role.user) {
            _logger.d('Adding message using transcription end: $transcriptionEnd');
            var rep = createThreadsRepository();
            await rep.createMessage(id, msg);
          }
        },
        onResponse: (response, audioBytes) async {
          var outputItem = response.output.firstWhereOrNull((x) {
            return x.role == Role.assistant;
          });
          var content = outputItem?.content.single;
          var text = content?.text ?? content?.transcript;
          if (text == null) {
            _logger.w('Aborting reading assistant message because no text was found.');
            return;
          }

          var msg = Message.assistant(
            message: text,
            usage: response.usage,
            audio: audioBytes,
            itemId: outputItem?.id,
            previousItemId: response.previousItemId,
          );
          var id = conversation?.id;
          if (id != null) {
            var rep = createThreadsRepository();
            await rep.createMessage(id, msg);
          }
        },
        onError: (errorMessage) {
          _showError(
            title: 'Erro',
            message: errorMessage,
          );
        },
      );

      voiceModeProvider = p;
    } else {
      voiceModeProvider = VoiceModeProvider(
        errorReporter: (context, message, {stackTrace}) {
          _showError(
            title: context,
            message: message,
            stackTrace: stackTrace,
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
    }
  }
}
