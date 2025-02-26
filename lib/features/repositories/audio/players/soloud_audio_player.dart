import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart' as api;
import 'package:vit_gpt_flutter_api/factories/logger.dart';

class SoLoudAudioPlayer extends api.SimpleAudioPlayer {
  final String path;
  final player = SoLoud.instance;
  final bool isAsset;

  SoLoudAudioPlayer(
    this.path, {
    this.isAsset = false,
  });

  AudioSource? source;
  SoundHandle? soundHandle;

  @override
  Future<void> play() async {
    if (!player.isInitialized) {
      await player.init(
        automaticCleanup: true,
      );
    }

    if (isAsset) {
      source = await player.loadAsset(path);
    } else {
      source = await player.loadFile(path);
    }

    var duration = player.getLength(source!);

    soundHandle = await player.play(source!);

    var completer = Completer();

    Timer.periodic(Duration(milliseconds: 100), (t) {
      try {
        var position = player.getPosition(soundHandle!);
        if (position >= duration || position == Duration.zero) {
          t.cancel();
          completer.complete();
        }
      } on Exception catch (e) {
        logger.error('Error in play: $e');
        t.cancel();
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  @override
  Future<void> stop() async {
    await dispose();
  }

  @override
  Future<void> dispose() async {
    if (source != null) {
      await player.disposeSource(source!);
    }
    source = null;
    soundHandle = null;
  }

  @override
  Future<void> pause() async {
    var handle = soundHandle;
    if (handle == null) return;
    player.setPause(handle, true);
  }

  @override
  double get positionInSeconds {
    var handle = soundHandle;
    if (handle == null) return 0;
    return player.getPosition(handle).inMilliseconds / 1000;
  }

  @override
  api.PlayerState get state {
    var handle = soundHandle;
    if (handle == null) return api.PlayerState.stopped;

    var isPaused = player.getPause(handle);
    if (isPaused) return api.PlayerState.paused;

    return api.PlayerState.playing;
  }

  @override
  Stream<double>? getVolumeIntensity() {
    return null;
  }
}
