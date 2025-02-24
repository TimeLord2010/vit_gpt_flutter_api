import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart' as api;

class SoLoudAudioPlayer extends api.SimpleAudioPlayer {
  final String path;
  final player = SoLoud.instance;
  final bool isAsset;

  SoLoudAudioPlayer(
    this.path, {
    this.isAsset = false,
  });

  SoundHandle? soundHandle;

  @override
  Future<void> play() async {
    if (!player.isInitialized) {
      await player.init();
    }

    AudioSource source;
    if (isAsset) {
      source = await player.loadAsset(path);
    } else {
      source = await player.loadFile(path);
    }

    soundHandle = await player.play(source);
  }

  @override
  Future<void> stop() async {
    soundHandle = null;
    await dispose();
  }

  @override
  Future<void> dispose() async {
    await player.disposeAllSources();
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
