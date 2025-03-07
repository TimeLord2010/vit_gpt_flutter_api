import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/speech/speech_end.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/transcription/transcription_item.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/transcription/transcription_start.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';
import 'package:vit_gpt_flutter_api/data/contracts/realtime_audio_player.dart';
import 'package:vit_gpt_flutter_api/data/contracts/voice_mode_contract.dart';
import 'package:vit_gpt_flutter_api/data/enums/chat_status.dart';
import 'package:vit_gpt_flutter_api/factories/create_realtime_audio_player.dart';
import 'package:vit_gpt_flutter_api/features/repositories/audio/vit_audio_recorder.dart';
import 'package:vit_gpt_flutter_api/features/usecases/audio/get_audio_intensity.dart';
import 'package:vit_gpt_flutter_api/features/usecases/get_error_message.dart';
import 'package:vit_logger/vit_logger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

var _logger = TerminalLogger(
  event: 'RealtimeVoiceModeProvider',
);

class RealtimeVoiceModeProvider with VoiceModeContract {
  final void Function(ChatStatus) _setStatus;

  /// Called once the voice mode was started by the user.
  final Future<void> Function() onStart;

  /// Called when a transcription starts. Either from the user or the assistant.
  final void Function(TranscriptionStart transcriptionStart)?
      onTranscriptionStart;

  final void Function(SpeechEnd speechEnd)? onSpeechEnd;

  /// Called when a transcription data is received.
  final void Function(TranscriptionItem transcriptionItem) onTranscription;

  /// Called when any error happens. Useful to update the UI.
  final void Function(String errorMessage) onError;

  /// Whether the audio data should be processed in an isolate or not.
  final bool useIsolate;

  RealtimeVoiceModeProvider({
    required void Function(ChatStatus status) setStatus,
    required this.onTranscription,
    required this.onError,
    required this.onStart,
    this.onTranscriptionStart,
    this.onSpeechEnd,
    this.useIsolate = false,
  }) : _setStatus = setStatus;

  // Reference to the audio recorder used to record the user voice.
  final recorder = VitAudioRecorder();

  // Class that handles the api calls to the real time api.
  RealtimeModel? realtimeModel;

  // Helper variable for [isInVoiceMode].
  bool _isVoiceMode = false;

  final _audioVolumeStreamController = StreamController<double>.broadcast();

  // Helper variable to prevent unnecessary calls to [setStatus].
  ChatStatus? _oldStatus;

  // Isolate communication
  SendPort? _sendPort;
  Isolate? _isolate;

  @override
  Stream<double>? get audioVolumeStream => _audioVolumeStreamController.stream;

  @override
  bool get isInVoiceMode => _isVoiceMode;

  RealtimeAudioPlayer? realtimePlayer;

  Future<void> setupPlayer() async {
    if (useIsolate) {
      await _startIsolate();
    } else {
      realtimePlayer = createRealtimeAudioPlayer();
    }
  }

  Future<void> _startIsolate() async {
    var (isolate, send) = await computeIsolate();
    _isolate = isolate;
    _sendPort = send;
  }

  Future<void> _tearDownPlayer() async {
    try {
      realtimePlayer?.dispose();
      realtimePlayer = null;

      if (_sendPort != null) {
        _sendPort!.send(_DisposeRealtime());
      }
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
      _sendPort = null;
    } on Exception catch (e) {
      _logger.error('Error disposing player: $e');
    }
  }

  @override
  Future<RealtimeModel> startVoiceMode() async {
    _logger.info('Starting voice mode');
    realtimeModel?.close();

    var rep = createRealtimeRepository();
    realtimeModel = rep;
    rep.open();

    await Future.wait([
      onStart(),
      setupPlayer(),
    ]);

    _setNewStreamPlayer();

    rep.onTranscriptionStart.listen((transcriptionStart) {
      onTranscriptionStart?.call(transcriptionStart);
    });

    rep.onTranscriptionItem.listen((transcription) {
      // var role = transcription.role;
      // if (role == Role.user) {
      //   setStatus(ChatStatus.transcribing);
      // } else if (role == Role.assistant) {
      //   setStatus(ChatStatus.answering);
      // }
      onTranscription(transcription);
    });

    rep.onSpeech.listen((speech) {
      if (speech.role == Role.assistant) {
        setStatus(ChatStatus.speaking);
        _processAiBytes(speech.audioData);
      }
    });

    rep.onSpeechStart.listen((speechStart) {
      var role = speechStart.role;
      if (role == Role.assistant) {
        _setNewStreamPlayer();
      }
    });

    rep.onSpeechEnd.listen((speechEnd) {
      var role = speechEnd.role;
      if (role == Role.assistant) {
        // TODO: Just because the stream of audio ended, it doesn't mean that the assistant finished speaking.
        setStatus(ChatStatus.listeningToUser);
      }
    });

    rep.onConnectionOpen.listen((_) {
      _startRecording();
    });

    rep.onConnectionClose.listen((_) {
      setStatus(ChatStatus.idle);
    });

    rep.onError.listen((error) {
      String msg = getErrorMessage(error) ?? 'Falha desconhecida';
      onError(msg);
    });

    _isVoiceMode = true;
    // Preventing turning off the screen while the user is interacting using voice.
    WakelockPlus.enable();

    return rep;
  }

  Future<void> _startRecording() async {
    setStatus(ChatStatus.listeningToUser);
    Stream<Uint8List> userAudioStream = await recorder.startStream();

    userAudioStream.listen((bytes) {
      realtimeModel?.sendUserAudio(bytes);
      var volume = getAudioIntensityFromPcm16(bytes);
      _audioVolumeStreamController.add(volume);
    });
  }

  void _processAiBytes(data) {
    if (data is String) {
      if (useIsolate) {
        _sendPort?.send(_PlayBase64AudioData(data));
      } else {
        realtimePlayer?.appendData(data);
      }
    } else {
      Uint8List bytes = data;
      if (useIsolate) {
        _sendPort?.send(_PlayAudioData(bytes));
      } else {
        realtimePlayer?.appendBytes(bytes);
      }
    }
  }

  @override
  Future<void> stopVoiceMode() async {
    realtimeModel?.close();
    realtimeModel = null;

    _setNewStreamPlayer();

    _isVoiceMode = false;
    setStatus(ChatStatus.idle);

    // Allow the screen to turn off again.
    await WakelockPlus.disable();
    await _tearDownPlayer();
  }

  @override
  void stopVoiceInteraction() {
    var rep = realtimeModel;
    if (rep == null) {
      return;
    }
    if (rep.isAiSpeaking) {
      rep.stopAiSpeech();
    } else {
      rep.commitUserAudio();
    }
  }

  @override
  Future<void> dispose() async {
    await _tearDownPlayer();

    var isRecording = await recorder.isRecording();
    if (isRecording) recorder.stop();

    _audioVolumeStreamController.close();
  }

  @override
  void setStatus(ChatStatus status) {
    // Preventing unnecessary calls.
    // Old status is the same as the new status.
    if (status == _oldStatus) {
      return;
    }

    // Preventing the status from going back to speaking from answering.
    if (_oldStatus == ChatStatus.speaking && status == ChatStatus.answering) {
      return;
    }

    _oldStatus = status;
    _setStatus(status);
  }

  void _setNewStreamPlayer() {
    if (useIsolate) {
      if (_sendPort != null) {
        _sendPort!.send(_ResetStreamPlayer());
      }
    } else {
      realtimePlayer?.resetBuffer();
    }
  }
}

class _PlayAudioData {
  final Uint8List audioData;
  _PlayAudioData(this.audioData);
}

class _PlayBase64AudioData {
  final String base64Data;
  _PlayBase64AudioData(this.base64Data);
}

class _ResetStreamPlayer {}

class _DisposeRealtime {}

Future<(Isolate, SendPort)> computeIsolate() async {
  final receivePort = ReceivePort();
  var rootToken = RootIsolateToken.instance!;
  var isolate = await Isolate.spawn<_IsolateData>(
    _isolateEntry,
    _IsolateData(
      token: rootToken,
      answerPort: receivePort.sendPort,
    ),
  );
  return (isolate, (await receivePort.first) as SendPort);
}

void _isolateEntry(_IsolateData isolateData) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(isolateData.token);
  realtimeIsolate(isolateData.answerPort);
}

class _IsolateData {
  final RootIsolateToken token;
  final SendPort answerPort;

  _IsolateData({
    required this.token,
    required this.answerPort,
  });
}

// Isolate entry function
void realtimeIsolate(SendPort sendPort) async {
  // TODO: Fix static values are not transfered to isolate
  RealtimeAudioPlayer realtimePlayer = createRealtimeAudioPlayer();

  // Create a ReceivePort to receive messages from main isolate
  final receivePort = ReceivePort();

  // Send back the SendPort to the main isolate
  sendPort.send(receivePort.sendPort);

  // Listen for messages
  await for (var msg in receivePort) {
    if (msg is _PlayBase64AudioData) {
      var bytes = base64Decode(msg.base64Data);
      realtimePlayer.appendBytes(bytes);
    } else if (msg is _ResetStreamPlayer) {
      realtimePlayer.resetBuffer();
    } else if (msg is _DisposeRealtime) {
      realtimePlayer.dispose();
      break;
    }
  }
}
