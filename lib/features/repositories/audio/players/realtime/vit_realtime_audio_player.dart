import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logger/logger.dart';
import 'package:vit_gpt_flutter_api/data/contracts/realtime_audio_player.dart';
import 'package:vit_gpt_flutter_api/data/vit_gpt_configuration.dart';
import 'package:vit_gpt_flutter_api/features/repositories/audio/volume_smoother.dart';
import 'package:vit_gpt_flutter_api/features/usecases/audio/get_audio_intensity_from_pcm_16.dart';

class VitRealtimeAudioPlayer with RealtimeAudioPlayer {
  final _player = SoLoud.instance;
  final _stopStream = StreamController<void>();
  final _volumeStreamController = StreamController<double>.broadcast();

  // Volume granularity control
  static const Duration _volumeGranularity = Duration(milliseconds: 150);
  final volmeSmoother = VolumeSmoother(
    smoothingFactor: 0.2,
    maxHistorySize: 25,
  );

  bool _isPlaying = false;
  AudioSource? _source;
  SoundHandle? _soundHandle;
  Completer? _setupCompleter;
  Timer? _bufferMonitor;
  DateTime? _lastDataReceived;

  // Manual position tracking for streams
  DateTime? _playbackStartTime;
  Duration _manualPositionOffset = Duration.zero;

  // Audio chunk management
  final List<VolumeChunk> _volumeChunks = [];
  Duration _totalDuration = Duration.zero;
  double _lastEmittedVolume = 0.0;

  Logger get log => VitGptFlutterConfiguration.logger;

  /// Get current playback position using manual tracking instead of SoLoud's getPosition
  /// which doesn't work reliably with streams
  Duration get currentPosition {
    if (_playbackStartTime == null || !_isPlaying) {
      return Duration.zero;
    }
    return DateTime.now().difference(_playbackStartTime!) +
        _manualPositionOffset;
  }

  @override
  Stream<void> get stopPlayStream => _stopStream.stream;

  @override
  Stream<double> get volumeStream => _volumeStreamController.stream;

  @override
  Future<void> appendBytes(Uint8List audioData) async {
    await _setupCompleter?.future;
    _lastDataReceived = DateTime.now();

    // Calculate chunk duration (assuming 24kHz, mono, 16-bit)
    final sampleCount = audioData.length ~/ 2; // 16-bit = 2 bytes per sample
    final chunkDuration = Duration(
      microseconds: (sampleCount * 1000000 ~/ 24000), // 24kHz sample rate
    );

    // Create volume chunks based on granularity
    _createVolumeChunks(audioData, chunkDuration);

    _totalDuration += chunkDuration;

    // Clean up old chunks to prevent memory buildup (keep last 10 seconds)
    _cleanupOldChunks();

    _player.addAudioDataStream(_source!, audioData);

    if (!_isPlaying) {
      _isPlaying = true;
      _soundHandle = await _player.play(_source!);
      _startBufferMonitoring();
    }
  }

  void _createVolumeChunks(Uint8List audioData, Duration chunkDuration) {
    // If the chunk duration is less than or equal to granularity, create a single chunk
    if (chunkDuration <= _volumeGranularity) {
      final volumeIntensity = _getVolume(audioData);
      log.d('Generated volume: $volumeIntensity');
      final chunk = VolumeChunk(
        volumeIntensity: volumeIntensity,
        startTime: _totalDuration,
        endTime: _totalDuration + chunkDuration,
      );
      _volumeChunks.add(chunk);
      return;
    }

    // Split the chunk into smaller segments based on granularity
    final bytesPerSample = 2; // 16-bit = 2 bytes per sample
    final sampleRate = 24000; // 24kHz
    final samplesPerGranularity =
        (_volumeGranularity.inMicroseconds * sampleRate) ~/ 1000000;
    final bytesPerGranularity = samplesPerGranularity * bytesPerSample;

    Duration currentTime = _totalDuration;
    int currentOffset = 0;

    while (currentOffset < audioData.length) {
      // Calculate the end offset for this segment
      int endOffset = currentOffset + bytesPerGranularity;
      if (endOffset > audioData.length) {
        endOffset = audioData.length;
      }

      // Extract the segment data
      final segmentData = audioData.sublist(currentOffset, endOffset);

      // Calculate the actual duration of this segment
      final segmentSampleCount = segmentData.length ~/ bytesPerSample;
      final segmentDuration = Duration(
        microseconds: (segmentSampleCount * 1000000 ~/ sampleRate),
      );

      // Calculate volume intensity for this segment using logarithmic peak method
      final volumeIntensity = _getVolume(segmentData);

      // Create volume chunk for this segment
      final chunk = VolumeChunk(
        volumeIntensity: volumeIntensity,
        startTime: currentTime,
        endTime: currentTime + segmentDuration,
      );

      _volumeChunks.add(chunk);

      // Move to next segment
      currentOffset = endOffset;
      currentTime += segmentDuration;
    }
  }

  void _cleanupOldChunks() {
    if (!_isPlaying) return;

    final currentPos = currentPosition;
    final cutoffTime = currentPos - Duration(seconds: 60);

    var itemsToRemove =
        _volumeChunks.where((chunk) => chunk.endTime < cutoffTime);
    if (itemsToRemove.isNotEmpty) {
      log.w('Removing ${itemsToRemove.length} items from volume list');
    }
    for (var item in itemsToRemove) {
      _volumeChunks.remove(item);
    }
  }

  void _startBufferMonitoring() {
    _bufferMonitor?.cancel();

    // Initialize playback start time for manual position tracking
    _playbackStartTime = DateTime.now();

    _bufferMonitor = Timer.periodic(Duration(milliseconds: 50), (timer) {
      if (_source == null || !_isPlaying || _soundHandle == null) {
        log.w('Invalid configuration for timer');
        return;
      }

      final bufferSize = _player.getBufferSize(_source!);
      final currentPos = currentPosition;
      final now = DateTime.now();

      // Emit volume for current position using manual tracking
      _emitVolumeForPosition(currentPos);

      // Check for end of playback
      if (bufferSize == 0 && _lastDataReceived != null) {
        final timeSinceLastData = now.difference(_lastDataReceived!);
        if (timeSinceLastData.inMilliseconds > 200) {
          _handleAudioFinished();
          timer.cancel();
        }
      }
    });
  }

  void _emitVolumeForPosition(Duration position) {
    log.d('Checking volume at position $position');
    // Find the audio chunk that corresponds to the current playback position
    VolumeChunk? currentChunk;
    try {
      currentChunk = _volumeChunks.firstWhere(
        (chunk) => position >= chunk.startTime && position < chunk.endTime,
      );
    } catch (e) {
      log.w('Volume chunk at position not found. Defaulting to last value');
      // If no exact match found, use the last chunk if available
      currentChunk = _volumeChunks.isNotEmpty ? _volumeChunks.last : null;
    }

    if (currentChunk != null) {
      // Only emit if volume has changed significantly or enough time has passed
      var currentVol = currentChunk.volumeIntensity;
      if ((_lastEmittedVolume - currentVol).abs() > 0.01) {
        log.i('Emitting volume chunk ${currentChunk.volumeIntensity}');
        _volumeStreamController.add(currentChunk.volumeIntensity);
        _lastEmittedVolume = currentChunk.volumeIntensity;
      }
    }
  }

  void _handleAudioFinished() {
    log.d('Realtime audio player has stopped playing');
    _bufferMonitor?.cancel();
    _soundHandle = null;
    _stopStream.add(null);

    // Reset manual position tracking
    _playbackStartTime = null;
    _manualPositionOffset = Duration.zero;

    // Emit zero volume when playback stops
    _volumeStreamController.add(0.0);
    _lastEmittedVolume = 0.0;
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

    // Reset state for new stream
    _volumeChunks.clear();
    _totalDuration = Duration.zero;
    _lastEmittedVolume = 0.0;

    // Reset manual position tracking
    _playbackStartTime = null;
    _manualPositionOffset = Duration.zero;

    c.complete();
  }

  @override
  void dispose() {
    _bufferMonitor?.cancel();
    _player.disposeAllSources();
    _stopStream.close();
    _volumeStreamController.close();
    _volumeChunks.clear();
  }

  @override
  Future<void> disposeBufferStream() async {
    _isPlaying = false;
    _bufferMonitor?.cancel();
    _soundHandle = null;
    _volumeChunks.clear();
    _totalDuration = Duration.zero;

    // Reset manual position tracking
    _playbackStartTime = null;
    _manualPositionOffset = Duration.zero;

    _volumeStreamController.add(0.0);
  }

  double _getVolume(Uint8List data) {
    var rawVolume = getAudioIntensityFromPcm16(
      data,
      method: AudioIntensityMethod.rms,
      sensitivity: 5,
      // smoothing: 0.8,
    );
    return rawVolume;
    // var smoothed = volmeSmoother.smooth(rawVolume);
    // return smoothed;
  }
}

class VolumeChunk {
  final double volumeIntensity;
  final Duration startTime;
  final Duration endTime;

  VolumeChunk({
    required this.volumeIntensity,
    required this.startTime,
    required this.endTime,
  });
}
