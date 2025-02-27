import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:vit_gpt_flutter_api/data/contracts/realtime_audio_player.dart';

class VitRealtimePlayer with RealtimeAudioPlayer {
  VitRealtimePlayer() {
    SoLoud.instance
        .init(
      automaticCleanup: true,
    )
        .then((_) {
      _ready = true;
    });
  }

  bool _ready = false;
  AudioSource? _audioSource;

  @override
  void appendBytes(Uint8List audioData) {
    var ref = _audioSource;
    if (ref == null) return;
    SoLoud.instance.addAudioDataStream(ref, audioData);
  }

  @override
  Future<void> createBufferStream() async {
    disposeBufferStream();

    while (!_ready) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    var ref = _audioSource = SoLoud.instance.setBufferStream(
      maxBufferSizeDuration: const Duration(minutes: 10),
      bufferingTimeNeeds: 2,
      sampleRate: 24000,
      channels: Channels.mono,
      format: BufferType.s16le,
      bufferingType: BufferingType.released,
    );
    await SoLoud.instance.play(ref);
  }

  @override
  void dispose() {
    SoLoud.instance.disposeAllSources();
    _audioSource = null;
  }

  @override
  void disposeBufferStream() {
    var ref = _audioSource;
    if (ref != null) {
      SoLoud.instance.setDataIsEnded(ref);
      SoLoud.instance.disposeSource(ref);
    }
  }
}
