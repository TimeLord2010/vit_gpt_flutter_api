import 'dart:async';

import 'package:vit_gpt_flutter_api/data/vit_gpt_configuration.dart';

abstract class SetupContract {
  SetupContract() {
    _setup();
  }

  final _completer = Completer();

  bool get hasCompletedSetup => _completer.isCompleted;

  Future<void> get setupFuture => _completer.future;

  Future<void> prepare();

  Future<void> _setup() async {
    try {
      await prepare();
      _completer.complete();
    } on Exception catch (e) {
      VitGptFlutterConfiguration.logger.e(
        'Falha ao inicializar classe',
        error: e,
      );
      _completer.completeError(e);
    }
  }
}
