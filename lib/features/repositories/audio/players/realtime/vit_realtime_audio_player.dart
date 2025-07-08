import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:vit_gpt_flutter_api/data/contracts/realtime_audio_player.dart';
import 'package:vit_gpt_flutter_api/data/vit_gpt_configuration.dart';

class VitRealtimeAudioPlayer with RealtimeAudioPlayer {
  final _player = SoLoud.instance;
  final _stopStream = StreamController<void>();

  bool _isPlaying = false;

  AudioSource? _source;

  Completer? _setupCompleter;

  Timer? _bufferMonitor;
  DateTime? _lastDataReceived;

  @override
  Future<void> appendBytes(Uint8List audioData) async {
    await _setupCompleter?.future;
    _lastDataReceived = DateTime.now();
    _player.addAudioDataStream(_source!, audioData);
    if (!_isPlaying) {
      _isPlaying = true;
      await _player.play(_source!);

      // Start buffer monitoring for end detection
      _startBufferMonitoring();
    }
  }

  void _startBufferMonitoring() {
    _bufferMonitor?.cancel();

    _bufferMonitor = Timer.periodic(Duration(milliseconds: 50), (timer) {
      if (_source != null && _isPlaying) {
        final bufferSize = _player.getBufferSize(_source!);
        final now = DateTime.now();

        // If buffer is empty and no new data for a reasonable time
        if (bufferSize == 0 && _lastDataReceived != null) {
          final timeSinceLastData = now.difference(_lastDataReceived!);
          if (timeSinceLastData.inMilliseconds > 200) {
            // 200ms threshold
            _handleAudioFinished();
            timer.cancel();
          }
        }
      }
    });
  }

  void _handleAudioFinished() {
    VitGptFlutterConfiguration.logger
        .d('Realtime audio player has stopped playing');
    _isPlaying = false;
    _bufferMonitor?.cancel();
    _stopStream.add(null);
  }

  @override
  Future<void> createBufferStream() async {
    var c = _setupCompleter = Completer();
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
    _bufferMonitor?.cancel();
    _player.disposeAllSources();
    _stopStream.close();
  }

  @override
  Future<void> disposeBufferStream() async {
    _isPlaying = false;
    _bufferMonitor?.cancel();
  }

  @override
  Stream<void> get stopPlayStream => _stopStream.stream;
}
