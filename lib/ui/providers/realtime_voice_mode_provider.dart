import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';
import 'package:vit_gpt_flutter_api/data/contracts/voice_mode_contract.dart';
import 'package:vit_gpt_flutter_api/data/enums/chat_status.dart';
import 'package:vit_gpt_flutter_api/features/repositories/audio/vit_audio_recorder.dart';
import 'package:vit_gpt_flutter_api/features/usecases/audio/get_audio_intensity.dart';
import 'package:vit_gpt_flutter_api/features/usecases/get_error_message.dart';
import 'package:vit_logger/vit_logger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

var _logger = TerminalLogger(
  event: 'RealtimeVoiceModeProvider',
);

// Message classes for communication with the isolate
abstract class SoLoudMessage {}

class InitializeSoLoud extends SoLoudMessage {}

class PlayAudioData extends SoLoudMessage {
  final Uint8List audioData;
  PlayAudioData(this.audioData);
}

class PlayBase64AudioData extends SoLoudMessage {
  final String base64Data;
  PlayBase64AudioData(this.base64Data);
}

class ResetStreamPlayer extends SoLoudMessage {}

class DisposeSoLoud extends SoLoudMessage {}

class DisposeCurrentSound extends SoLoudMessage {}

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
  soLoudIsolate(isolateData.answerPort);
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
void soLoudIsolate(SendPort sendPort) async {
  // Initialize SoLoud
  await SoLoud.instance.init(automaticCleanup: true);

  AudioSource? currentSound;

  // Create a ReceivePort to receive messages from main isolate
  final receivePort = ReceivePort();

  // Send back the SendPort to the main isolate
  sendPort.send(receivePort.sendPort);

  // Listen for messages
  await for (var msg in receivePort) {
    if (msg is SoLoudMessage) {
      if (msg is PlayAudioData) {
        if (currentSound != null) {
          SoLoud.instance.addAudioDataStream(currentSound, msg.audioData);
        }
      } else if (msg is PlayBase64AudioData) {
        Uint8List bytes = base64Decode(msg.base64Data);
        if (currentSound != null) {
          SoLoud.instance.addAudioDataStream(currentSound, bytes);
        }
      } else if (msg is ResetStreamPlayer) {
        // Dispose of the current sound and create a new one
        if (currentSound != null) {
          SoLoud.instance.setDataIsEnded(currentSound);
          SoLoud.instance.disposeSource(currentSound);
        }
        currentSound = SoLoud.instance.setBufferStream(
          maxBufferSizeDuration: const Duration(minutes: 10),
          bufferingTimeNeeds: 1,
          sampleRate: 24000,
          channels: Channels.mono,
          format: BufferType.s16le,
          bufferingType: BufferingType.released,
        );
        SoLoud.instance.play(currentSound);
      } else if (msg is DisposeCurrentSound) {
        if (currentSound != null) {
          SoLoud.instance.setDataIsEnded(currentSound);
          SoLoud.instance.disposeSource(currentSound);
          currentSound = null;
        }
      } else if (msg is DisposeSoLoud) {
        SoLoud.instance.disposeAllSources();
        break;
      }
    }
  }
}

class RealtimeVoiceModeProvider with VoiceModeContract {
  final void Function(ChatStatus) _setStatus;
  final void Function(String text) addUserText;
  final void Function(String text) addAiText;
  final void Function(String errorMessage) onError;

  RealtimeVoiceModeProvider({
    required void Function(ChatStatus status) setStatus,
    required this.addUserText,
    required this.addAiText,
    required this.onError,
  }) : _setStatus = setStatus;

  // Reference to the audio recorder used to record the user voice.
  final recorder = VitAudioRecorder();

  // Class that handles the api calls to the real time api.
  RealtimeModel? realtimeModel;

  // Helper variable for [isInVoiceMode].
  bool _isVoiceMode = false;

  // Reference to AI speech player.
  AudioSource? currentSound;

  final _audioVolumeStreamController = StreamController<double>();

  // Helper variable to prevent unnecessary calls to [setStatus].
  ChatStatus? _oldStatus;

  // Isolate communication
  SendPort? _soLoudSendPort;
  Isolate? _soLoudIsolate;

  @override
  Stream<double>? get audioVolumeStream => _audioVolumeStreamController.stream;

  @override
  bool get isInVoiceMode => _isVoiceMode;

  Future<void> _startSoLoudIsolate() async {
    var (isolate, send) = await computeIsolate();
    _soLoudIsolate = isolate;
    _soLoudSendPort = send;
  }

  Future<void> _stopSoLoudIsolate() async {
    if (_soLoudSendPort != null) {
      _soLoudSendPort!.send(DisposeSoLoud());
    }
    _soLoudIsolate?.kill(priority: Isolate.immediate);
    _soLoudIsolate = null;
    _soLoudSendPort = null;
  }

  @override
  Future<RealtimeModel> startVoiceMode() async {
    _logger.info('Starting voice mode');
    realtimeModel?.close();
    await _startSoLoudIsolate();

    var rep = createRealtimeRepository();
    realtimeModel = rep;
    rep.open();

    _setNewStreamPlayer();

    rep.onUserText.listen((text) {
      _logger.debug('Received text from user');
      setStatus(ChatStatus.transcribing);
      addUserText(text);
    });

    rep.onAiText.listen((text) {
      _logger.debug('Received text from AI');
      setStatus(ChatStatus.answering);
      addAiText(text);
    });

    rep.onAiAudio.listen((Uint8List bytes) {
      setStatus(ChatStatus.speaking);
      if (_soLoudSendPort != null) {
        _soLoudSendPort!.send(PlayAudioData(bytes));
      }
    });

    rep.onRawAiAudio.listen((String base64Data) async {
      setStatus(ChatStatus.speaking);
      if (_soLoudSendPort != null) {
        _soLoudSendPort!.send(PlayBase64AudioData(base64Data));
      }
    });

    rep.onAiSpeechEnd.listen((_) {
      _setNewStreamPlayer();
      setStatus(ChatStatus.listeningToUser);
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

  @override
  Future<void> stopVoiceMode() async {
    realtimeModel?.close();
    realtimeModel = null;

    _setNewStreamPlayer();

    _isVoiceMode = false;
    setStatus(ChatStatus.idle);

    // Allow the screen to turn off again.
    await WakelockPlus.disable();
    await _stopSoLoudIsolate();
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
    try {
      await _stopSoLoudIsolate();
    } catch (e) {
      _logger.error('Error disposing SoLoud isolate: $e');
    }

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
    if (_soLoudSendPort != null) {
      _soLoudSendPort!.send(ResetStreamPlayer());
    }
  }
}
