import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart' show Level;
import 'package:vit_gpt_flutter_api/data/contracts/realtime_audio_player.dart';
import 'package:vit_gpt_flutter_api/features/repositories/buffered_data_handler.dart';

// class VitSoLoudRealtimePlayer with RealtimeAudioPlayer {
//   VitSoLoudRealtimePlayer() {
//     SoLoud.instance
//         .init(
//       automaticCleanup: true,
//     )
//         .then((_) {
//       _ready = true;
//     });
//   }

//   bool _ready = false;
//   AudioSource? _audioSource;

//   @override
//   void appendBytes(Uint8List audioData) {
//     var ref = _audioSource;
//     if (ref == null) return;
//     SoLoud.instance.addAudioDataStream(ref, audioData);
//   }

//   @override
//   Future<void> createBufferStream() async {
//     disposeBufferStream();

//     while (!_ready) {
//       await Future.delayed(const Duration(milliseconds: 50));
//     }

//     var ref = _audioSource = SoLoud.instance.setBufferStream(
//       maxBufferSizeDuration: const Duration(minutes: 10),
//       bufferingTimeNeeds: 2,
//       sampleRate: 24000,
//       channels: Channels.mono,
//       format: BufferType.s16le,
//       bufferingType: BufferingType.released,
//     );
//     await SoLoud.instance.play(ref);
//   }

//   @override
//   void dispose() {
//     SoLoud.instance.disposeAllSources();
//     _audioSource = null;
//   }

//   @override
//   void disposeBufferStream() {
//     var ref = _audioSource;
//     if (ref != null) {
//       SoLoud.instance.setDataIsEnded(ref);
//       SoLoud.instance.disposeSource(ref);
//     }
//   }
// }

class VitRealtimeAudioPlayer with RealtimeAudioPlayer {
  final _player = FlutterSoundPlayer(
    logLevel: Level.off,
  );

  VitRealtimeAudioPlayer() {
    unawaited(_setup());
  }

  late final _bufferHandler = BufferedDataHandler((base64) {
    var bytes = base64Decode(base64);
    appendBytes(bytes);
  });

  Future<void> _setup() async {
    await _player.openPlayer();
  }

  @override
  Future<void> appendBytes(Uint8List audioData) async {
    await _player.feedUint8FromStream(audioData);
  }

  @override
  void appendData(String base64Data) {
    _bufferHandler.addData(base64Data);
  }

  @override
  Future<void> createBufferStream() async {
    while (!_player.isOpen()) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 24000,
      bufferSize: 1024 * 20,
    );
  }

  @override
  Future<void> disposeBufferStream() async {
    var isOpen = _player.isOpen();
    if (!isOpen) return;
    await _player.stopPlayer();
  }

  @override
  Future<void> dispose() async {
    await _player.stopPlayer();
    await _player.closePlayer();
  }
}
