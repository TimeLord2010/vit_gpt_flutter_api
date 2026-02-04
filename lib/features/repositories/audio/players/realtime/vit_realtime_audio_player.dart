import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:vit_gpt_flutter_api/data/contracts/realtime_audio_player.dart';
import 'package:vit_gpt_flutter_api/factories/create_grouped_logger.dart';
import 'package:vit_gpt_flutter_api/features/repositories/audio/volume_smoother.dart';
import 'package:vit_gpt_flutter_api/features/usecases/audio/get_audio_intensity_from_pcm_16.dart';
import 'package:vit_gpt_flutter_api/features/usecases/get_error_message.dart';

import 'audio_routing.dart';

var _logger = createGptFlutterLogger(['VitRealtimeAudioPlayer']);

class VitRealtimeAudioPlayer with RealtimeAudioPlayer {
  /// Controls whether audio should automatically play when data is received
  final bool autoPlay;

  /// Controls whether to monitor buffer for volume and playback completion
  final bool monitorBuffer;

  /// Indicates data is deleted as soon as its played.
  final bool createReleasedBuffers;

  /// Constructor with optional autoPlay and monitorBuffer parameters
  VitRealtimeAudioPlayer({
    this.autoPlay = true,
    this.monitorBuffer = true,
    this.createReleasedBuffers = true,
  });

  final _player = SoLoud.instance;
  final _stopStream = StreamController<void>();
  final _volumeStreamController = StreamController<double>.broadcast();
  final _positionStreamController = StreamController<Duration>.broadcast();

  // Volume granularity control
  static const Duration _volumeGranularity = Duration(milliseconds: 150);
  final volmeSmoother = VolumeSmoother(
    smoothingFactor: 0.2,
    maxHistorySize: 25,
  );

  bool _isPlaying = false;
  bool _isPaused = false;
  AudioSource? _source;

  /// Used for the "play" method.
  SoundHandle? _soundHandle;
  Completer? _setupCompleter;
  Timer? _bufferMonitor;
  bool _streamCompleted = false;
  int _bufferMonitorTicks = 0; // Counter for periodic volume restoration

  // Manual position tracking for streams
  DateTime? _playbackStartTime;
  Duration _manualPositionOffset = Duration.zero;

  // Audio chunk management
  final List<VolumeChunk> _volumeChunks = [];
  Duration _totalDuration = Duration.zero;
  double _lastEmittedVolume = 0.0;

  /// Get current playback position using manual tracking instead of SoLoud's getPosition
  /// which doesn't work reliably with streams
  Duration get currentPosition {
    if (!_isPlaying) {
      return Duration.zero;
    }

    if (_isPaused || _playbackStartTime == null) {
      return _manualPositionOffset; // Return saved position while paused
    }

    return DateTime.now().difference(_playbackStartTime!) +
        _manualPositionOffset;
  }

  @override
  Stream<void> get stopPlayStream => _stopStream.stream;

  @override
  Stream<double> get volumeStream => _volumeStreamController.stream;

  /// Stream that emits the current playback position with total duration
  Stream<Duration> get positionStream => _positionStreamController.stream;

  @override
  Future<void> appendBytes(Uint8List audioData) async {
    await _setupCompleter?.future;
    var now = DateTime.now();
    _logger.d('Received audio data on $now');

    // Calculate chunk duration (assuming 24kHz, mono, 16-bit)
    final sampleCount = audioData.length ~/ 2; // 16-bit = 2 bytes per sample
    final chunkDuration = Duration(
      microseconds: (sampleCount * 1000000 ~/ 24000), // 24kHz sample rate
    );

    // Create volume chunks based on granularity
    _createVolumeChunks(audioData, chunkDuration);

    _totalDuration += chunkDuration;

    _cleanupOldVolumeChunks();

    _player.addAudioDataStream(_source!, audioData);

    if (!_isPlaying && !_isPaused && autoPlay) {
      await play();
    }
  }

  /// Manually start playback
  @override
  Future<void> play() async {
    if (_isPlaying && !_isPaused) return; // Already playing and not paused

    if (_isPaused) {
      // Resuming from pause
      _isPaused = false;
      _playbackStartTime = DateTime.now(); // Restart position tracking

      var handle = _soundHandle;
      if (handle != null) {
        _player.setPause(handle, false);
      }
    } else {
      // Initial play
      _isPlaying = true;
      _playbackStartTime = DateTime.now();
      _soundHandle = await _player.play(_source!);

      // Explicitly set volume to maximum to override browser volume ducking
      var handle = _soundHandle;
      if (handle != null) {
        _player.setVolume(handle, 1.0);
        _logger.d('Started playback and set volume to 1.0');
      }
    }

    _startBufferMonitoring();
  }

  @override
  Future<void> pause() async {
    if (!_isPlaying || _isPaused) return;

    _isPaused = true;

    // Save current position before pausing
    if (_playbackStartTime != null) {
      _manualPositionOffset += DateTime.now().difference(_playbackStartTime!);
      _playbackStartTime = null; // Stop position tracking
    }

    // Pause the audio
    var handle = _soundHandle;
    if (handle != null) {
      _player.setPause(handle, true);
    } else {
      _logger.w('Unable to pause sound: missing sound handle');
    }

    // Stop buffer monitoring
    _bufferMonitor?.cancel();
    _bufferMonitor = null;

    // Emit zero volume while paused
    _volumeStreamController.add(0.0);

    // DO NOT emit stopPlayStream - we're paused, not stopped!
  }

  void seek(Duration time) {
    var handle = _soundHandle;
    if (handle != null) {
      _player.seek(handle, time);
    } else {
      _logger.w('Unable to seek: missing sound handle');
    }
  }

  void _createVolumeChunks(Uint8List audioData, Duration chunkDuration) {
    // If the chunk duration is less than or equal to granularity, create a single chunk
    if (chunkDuration <= _volumeGranularity) {
      final volumeIntensity = _getVolume(audioData);
      // _logger.d('Generated volume: $volumeIntensity');
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

  void _cleanupOldVolumeChunks() {
    if (!_isPlaying || _isPaused) return;

    final currentPos = currentPosition;
    final cutoffTime = currentPos - Duration(seconds: 60);

    var itemsToRemove =
        _volumeChunks.where((chunk) => chunk.endTime < cutoffTime);
    if (itemsToRemove.isNotEmpty) {
      _logger.w('Removing ${itemsToRemove.length} items from volume list');
    }
    for (var item in itemsToRemove) {
      _volumeChunks.remove(item);
    }
  }

  void _startBufferMonitoring() {
    _bufferMonitor?.cancel();

    // Initialize playback start time for manual position tracking
    _playbackStartTime = DateTime.now();
    _bufferMonitorTicks = 0; // Reset tick counter

    if (!monitorBuffer) return;

    _bufferMonitor = Timer.periodic(Duration(milliseconds: 50), (timer) async {
      _bufferMonitorTicks++;

      _emitVolume();

      _emitPosition();

      // Periodically restore volume to counter browser ducking (every 500ms)
      // This prevents volume from staying low after phone calls or other interruptions
      if (_bufferMonitorTicks % 100 == 0) {
        // Every 100 ticks = 5000ms
        var handle = _soundHandle;
        if (handle != null && !_isPaused) {
          _player.setVolume(handle, 1.0);
        }
      }

      // Check for end of playback when stream is completed
      var source = _source;
      if (source != null) {
        final bufferSize = _player.getBufferSize(source);
        // _logger.d('Buffer size: $bufferSize');
        if (bufferSize == 0 && _streamCompleted) {
          _logger.d('Buffer empty and stream completed - finishing playback');
          timer.cancel();
          await Future.delayed(Duration(milliseconds: 500), () {
            handleAudioFinished();
          });
        }
      }
    });
  }

  void _emitPosition() {
    try {
      Duration? duration;
      if (createReleasedBuffers) {
        var source = _source;
        if (source != null) duration = _player.getStreamTimeConsumed(source);
      } else {
        var handle = _soundHandle;
        if (handle != null) duration = _player.getPosition(handle);
      }
      if (duration != null) _positionStreamController.add(duration);
    } catch (e) {
      _logger.e(getErrorMessage(e));
    }
  }

  void _emitVolume() {
    if (!monitorBuffer) return;

    var position = currentPosition;

    //_logger.d('Checking volume at position $position');
    // Find the audio chunk that corresponds to the current playback position
    VolumeChunk? currentChunk;
    try {
      currentChunk = _volumeChunks.firstWhere(
        (chunk) => position >= chunk.startTime && position < chunk.endTime,
      );
    } catch (e) {
      // _logger.w('Volume chunk at position not found. Defaulting to last value');
      // If no exact match found, use the last chunk if available
      currentChunk = _volumeChunks.isNotEmpty ? _volumeChunks.last : null;
    }

    if (currentChunk != null) {
      // Only emit if volume has changed significantly or enough time has passed
      var currentVol = currentChunk.volumeIntensity;
      if ((_lastEmittedVolume - currentVol).abs() > 0.01) {
        // log.i('Emitting volume chunk ${currentChunk.volumeIntensity}');
        _volumeStreamController.add(currentChunk.volumeIntensity);
        _lastEmittedVolume = currentChunk.volumeIntensity;
      }
    }
  }

  Future<void> handleAudioFinished() async {
    _logger.d('Realtime audio player has stopped playing');
    try {
      _bufferMonitor?.cancel();
    } catch (_) {}
    _bufferMonitor = null;

    // Reset manual position tracking
    _playbackStartTime = null;
    _manualPositionOffset = Duration.zero;

    // Emit zero volume when playback stops
    try {
      _volumeStreamController.add(0.0);
    } catch (_) {}
    _lastEmittedVolume = 0.0;

    // /// For some reason, this even triggers too early on some platforms.
    // if (kIsWeb || Platform.isAndroid) {
    //   await Future.delayed(Duration(seconds: 1, milliseconds: 500));
    // }
    _stopStream.add(null);
  }

  @override
  void completeStream() {
    _logger.i('Stream completed - no more audio data will be received');
    _player.setDataIsEnded(_source!);
    _streamCompleted = true;
  }

  /// Force reinitialization of the audio player to reset browser audio context
  /// Call this when you suspect the browser has reduced audio gain (e.g., after phone calls)
  Future<void> reinitializeAudioContext() async {
    _logger.i('Reinitializing audio context to reset browser audio gain');

    try {
      // Deinitialize to destroy the current AudioContext
      _player.deinit();
      _logger.d('Audio player deinitialized');

      // Wait a bit for cleanup
      await Future.delayed(Duration(milliseconds: 100));

      // Reinitialize with fresh AudioContext
      await _player.init(
        automaticCleanup: true,
        channels: Channels.mono,
        sampleRate: 24000,
      );
      _logger.d('Audio player reinitialized with fresh AudioContext');
    } catch (e) {
      _logger.e('Failed to reinitialize audio context: ${getErrorMessage(e)}');
      rethrow;
    }
  }

  @override
  Future<void> createBufferStream() async {
    _logger.i('Create buffer stream');
    var c = _setupCompleter = Completer();

    // Configure audio routing for speaker output (web only)
    AudioRouting.configureForSpeakerOutput();

    try {
      if (!_player.isInitialized) {
        await _player.init(
          automaticCleanup: true,
          channels: Channels.mono,
          sampleRate: 24000,
        );
      }
    } catch (e) {
      var msg = getErrorMessage(e);
      _logger.e('Failed to initialize player: $msg');
      rethrow;
    }

    await _player.disposeAllSources();

    _source = _player.setBufferStream(
      channels: Channels.mono,
      sampleRate: 24000,
      format: BufferType.s16le,
      bufferingType: createReleasedBuffers
          ? BufferingType.released
          : BufferingType.preserved,
    );

    // Reset state for new stream
    _volumeChunks.clear();
    _totalDuration = Duration.zero;
    _lastEmittedVolume = 0.0;
    _streamCompleted = false;

    // Reset manual position tracking
    _playbackStartTime = null;
    _manualPositionOffset = Duration.zero;

    c.complete();
  }

  @override
  void dispose() {
    _bufferMonitor?.cancel();
    var source = _source;
    if (source != null) _player.disposeSource(source);
    _stopStream.close();
    _soundHandle = null;
    _volumeStreamController.close();
    _positionStreamController.close();
    _volumeChunks.clear();
    AudioRouting.cleanup();
  }

  @override
  Future<void> disposeBufferStream() async {
    _isPlaying = false;
    _isPaused = false; // Reset pause state
    _bufferMonitor?.cancel();
    if (_source != null) await _player.disposeSource(_source!);
    _soundHandle = null;
    _volumeChunks.clear();
    _totalDuration = Duration.zero;

    // Reset manual position tracking
    _playbackStartTime = null;
    _manualPositionOffset = Duration.zero;

    _volumeStreamController.add(0.0);

    // // Reinitialize audio context to clear any browser audio ducking
    // // This ensures the next AI turn starts with fresh, normal volume
    // try {
    //   await reinitializeAudioContext();
    // } catch (e) {
    //   _logger.w('Failed to reinitialize audio context during dispose: ${getErrorMessage(e)}');
    //   // Don't rethrow - this is cleanup, continue anyway
    // }
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

  void changePlaySpeed(double speed) {
    var soundHandle = _soundHandle;
    if (soundHandle != null) {
      _player.setRelativePlaySpeed(soundHandle, speed);
    } else {
      _logger.e('Unable to change play speed: No sound handle');
    }
  }

  @override
  bool get isPaused => _isPaused;
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
