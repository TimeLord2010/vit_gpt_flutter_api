import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vit_dart_extensions/vit_dart_extensions.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';
import 'package:vit_gpt_flutter_api/features/repositories/paginated_repository.dart';

import '../../features/usecases/get_error_message.dart';

class ConversationsProvider extends ChangeNotifier
    with PaginatedRepository<Conversation> {
  final BuildContext context;

  final bool ignoreUpdatedAtOnSort;

  ConversationsProvider(
    this.context, {
    this.ignoreUpdatedAtOnSort = false,
  });

  List<Conversation> conversations = [];

  List<String>? _conversationIds;

  /// Loads conversations.
  ///
  /// Should be called in initState.
  Future<void> setup() async {
    // Reversing to show the latest threads first on the UI
    var ids = (await getSavedThreadIds()).reversed;
    _conversationIds = ids.toList();
    if (ids.isEmpty) {
      debugPrint('No conversations save found.');
    }

    conversations.addAll(ids.map((x) => Conversation(id: x)));

    var titles = await getThreadsTitle(ids);

    for (var conversation in conversations) {
      var id = conversation.id!;
      var title = titles[id];
      if (title == null) continue;
      conversation.title = title;
    }
    notifyListeners();

    try {
      var stream = streamAll();
      stream.listen((conversation) {
        debugPrint('Loaded conversations ${conversation.map((x) => x.id)}');
      }, onDone: () {
        _sort();
      });
      // for (var id in ids) {
      //   _loadConversation(
      //     id,
      //     titles: titles,
      //   );
      // }
    } on Exception catch (e) {
      Widget adaptiveAction(
          {required BuildContext context,
          required VoidCallback onPressed,
          required Widget child}) {
        ThemeData theme = Theme.of(context);
        switch (theme.platform) {
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
          case TargetPlatform.linux:
          case TargetPlatform.windows:
            return TextButton(onPressed: onPressed, child: child);
          case TargetPlatform.iOS:
          case TargetPlatform.macOS:
            return CupertinoDialogAction(onPressed: onPressed, child: child);
        }
      }

      await showAdaptiveDialog(
        // ignore: use_build_context_synchronously
        context: context,
        builder: (context) {
          return AlertDialog.adaptive(
            title: const Text('Falha ao carregar conversas'),
            content: Column(
              children: [
                const Text(
                    'Verifique sua conexão com a internet e certifique-se que a token de API está válida.'),
                Text('Logs:${getErrorMessage(e) ?? '...'}'),
              ],
            ),
            actions: [
              adaptiveAction(
                context: context,
                onPressed: () => Navigator.pop(context, 'OK'),
                child: const Text('Ok'),
              ),
            ],
          );
        },
      );
    } finally {
      _sort();
    }
  }

  void _sort() {
    conversations.sortByDate((x) {
      if (ignoreUpdatedAtOnSort) {
        return x.createdAt ?? DateTime.now();
      }
      return x.updatedAt ?? x.createdAt ?? DateTime.now();
    }, false);
  }

  void add(Conversation newConversation) {
    try {
      var id = newConversation.id;
      if (id == null) {
        return;
      }

      var oldConversationIndex = conversations.indexWhere((x) => x.id == id);
      if (oldConversationIndex >= 0) {
        conversations.removeAt(oldConversationIndex);
        conversations.insert(oldConversationIndex, newConversation);
        return;
      }

      conversations.insert(0, newConversation);
      notifyListeners();
    } finally {
      _sort();
    }
  }

  void delete(String id) {
    conversations.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  Future<Conversation?> _loadConversation(
    String id, {
    Map<String, String>? titles,
  }) async {
    Conversation? conversation = await loadThread(id);
    if (conversation == null) {
      debugPrint('Conversation not found! Deleting...');
      await deleteSavedThread(id);
      delete(id);
      return null;
    }
    var originalConversation = conversations.firstWhereOrNull((x) {
      return x.id == id;
    });

    if (originalConversation == null) return conversation;

    originalConversation.metadata = conversation.metadata;
    originalConversation.createdAt = conversation.createdAt;

    notifyListeners();

    // Updating title saved locally if necessary
    if (titles != null) {
      var savedTitle = titles[id];
      var currentTitle = conversation.title;
      if (currentTitle != null && savedTitle != currentTitle) {
        await saveThreadTitle(id, currentTitle);
      }
    }

    return originalConversation;
  }

  @override
  int get chunkSize => 1;

  @override
  int get maxConcurrency => 3;

  @override
  Future<int?> count() async => _conversationIds!.length;

  @override
  Future<Iterable<Conversation>> fetch({
    int? limit,
    int? skip,
  }) async {
    if (skip == null || limit == null) return [];
    var ids = _conversationIds!.skip(skip).take(limit);

    var futures = <Future<Conversation?>>[];
    for (var id in ids) {
      var future = _loadConversation(id);
      futures.add(future);
    }

    List<Conversation?> conversations = await Future.wait(futures);

    return conversations.whereType<Conversation>();
  }
}
