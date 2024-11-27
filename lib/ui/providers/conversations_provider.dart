import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vit_dart_extensions/vit_dart_extensions.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';

import '../../features/usecases/get_error_message.dart';

class ConversationsProvider extends ChangeNotifier {
  final BuildContext context;

  ConversationsProvider(this.context);

  List<Conversation> conversations = [];

  /// Loads conversations.
  ///
  /// Should be called in initState.
  Future<void> setup() async {
    // Reversing to show the latest threads first on the UI
    var ids = (await getSavedThreadIds()).reversed;
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
      for (var id in ids) {
        Conversation? conversation = await loadThread(id);
        if (conversation == null) {
          debugPrint('Conversation not found! Deleting...');
          await deleteSavedThread(id);
          delete(id);
          continue;
        }
        var originalConversation = conversations.firstWhereOrNull((x) {
          return x.id == id;
        });

        if (originalConversation == null) continue;

        originalConversation.metadata = conversation.metadata;
        originalConversation.createdAt = conversation.createdAt;

        notifyListeners();

        // Updating title saved locally if necessary
        var savedTitle = titles[id];
        var currentTitle = conversation.title;
        if (currentTitle != null && savedTitle != currentTitle) {
          await saveThreadTitle(id, currentTitle);
        }
      }
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
    }
    conversations.sortByDate((x) {
      return x.updatedAt ?? x.createdAt ?? DateTime.now();
    }, false);
  }

  void add(Conversation newConversation) {
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
  }

  void delete(String id) {
    conversations.removeWhere((x) => x.id == id);
    notifyListeners();
  }
}
