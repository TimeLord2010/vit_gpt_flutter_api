import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:vit_gpt_flutter_api/data/contracts/realtime_audio_player.dart';

class VitRealtimeAudioPlayer with RealtimeAudioPlayer {
  final _player = SoLoud.instance;
  AudioSource? _source;

  bool _isPlaying = false;

  Completer? _completer;

  @override
  Future<void> appendBytes(Uint8List audioData) async {
    await _completer?.future;
    _player.addAudioDataStream(_source!, audioData);
    if (!_isPlaying) {
      _isPlaying = true;
      await _player.play(_source!);
    }
  }

  @override
  Future<void> createBufferStream() async {
    var c = _completer = Completer();
    if (!_player.isInitialized) {
      await _player.init(
        automaticCleanup: true,
        channels: Channels.mono,
        sampleRate: 24000,
      );
    }

    await _player.disposeAllSources();

    _source = _player.setBufferStream(
      channels: Channels.mono,
      sampleRate: 24000,
      format: BufferType.s16le,
      bufferingType: BufferingType.released,
    );
    c.complete();
  }

  @override
  void dispose() {
    _player.disposeAllSources();
  }

  @override
  Future<void> disposeBufferStream() async {
    _isPlaying = false;
  }
}
