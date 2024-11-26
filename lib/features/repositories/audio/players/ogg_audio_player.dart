import 'package:ogg_opus_player/ogg_opus_player.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart' as api;

class OggAudioPlayer extends api.SimpleAudioPlayer {
  final String path;
  OggOpusPlayer _player;

  OggAudioPlayer(this.path) : _player = OggOpusPlayer(path);

  @override
  Future<void> play() async {
    _player.play();
  }

  @override
  Future<void> stop() async {
    await dispose();
    _player = OggOpusPlayer(path);
  }

  @override
  Future<void> dispose() async {
    _player.pause();
    _player.dispose();
  }

  @override
  Future<void> pause() async {
    _player.pause();
  }

  @override
  double get positionInSeconds => _player.currentPosition;

  @override
  api.PlayerState get state {
    return switch (_player.state.value) {
      PlayerState.playing => api.PlayerState.playing,
      PlayerState.paused => api.PlayerState.paused,
      PlayerState.ended => api.PlayerState.stopped,
      PlayerState.error => api.PlayerState.stopped,
      PlayerState.idle => api.PlayerState.paused,
    };
  }

  @override
  Stream<double>? getVolumeIntensity() {
    return null;
  }
}
