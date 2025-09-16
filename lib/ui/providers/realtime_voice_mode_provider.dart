import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/realtime_response.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/speech/speech_end.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/transcription/transcription_end.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/transcription/transcription_item.dart';
import 'package:vit_gpt_dart_api/data/models/realtime_events/transcription/transcription_start.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';
import 'package:vit_gpt_flutter_api/data/contracts/realtime_audio_player.dart';
import 'package:vit_gpt_flutter_api/data/contracts/voice_mode_contract.dart';
import 'package:vit_gpt_flutter_api/data/enums/chat_status.dart';
import 'package:vit_gpt_flutter_api/data/vit_gpt_configuration.dart';
import 'package:vit_gpt_flutter_api/factories/create_realtime_audio_player.dart';
import 'package:vit_gpt_flutter_api/features/repositories/audio/vit_audio_recorder.dart';
import 'package:vit_gpt_flutter_api/features/usecases/audio/get_audio_intensity_from_pcm_16.dart';
import 'package:vit_gpt_flutter_api/features/usecases/get_error_message.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class RealtimeVoiceModeProvider with VoiceModeContract {
  // MARK: Objects received from constructor

  final void Function(ChatStatus) _setStatus;

  /// Called once the voice mode was started by the user.
  final Future<void> Function() onStart;

  /// Called when a transcription starts. Either from the user or the assistant.
  final void Function(TranscriptionStart transcriptionStart)?
      onTranscriptionStart;

  final void Function(SpeechEnd speechEnd)? onSpeechEnd;

  /// Called when a transcription data is received.
  final void Function(TranscriptionItem transcriptionItem)? onTranscription;

  final void Function(TranscriptionEnd transcriptionEnd, List<int>? audioBytes)?
      onTranscriptionEnd;

  final void Function(RealtimeResponse response, List<int>? audioBytes)?
      onResponse;

  /// Called when any error happens. Useful to update the UI.
  final void Function(String errorMessage) onError;

  final List<int> aiAudioBytesBeingRecorded = [];
  final List<int> aiAudioBytesWaitingTranscription = [];

  final List<int> userAudioBytesBeingRecorded = [];
  final List<int> userAudioBytesWaitingTranscription = [];

  RealtimeVoiceModeProvider({
    required void Function(ChatStatus status) setStatus,
    required this.onError,
    required this.onStart,
    this.onTranscriptionStart,
    this.onTranscription,
    this.onTranscriptionEnd,
    this.onResponse,
    this.onSpeechEnd,
  }) : _setStatus = setStatus;

  // MARK: Variables

  final Logger _logger = VitGptFlutterConfiguration.groupedLogsFactory([
    'RealtimeVoiceModeProvider',
  ]);

  // Reference to the audio recorder used to record the user voice.
  final recorder = VitAudioRecorder();

  // Class that handles the api calls to the real time api.
  RealtimeModel? realtimeModel;
  RealtimeAudioPlayer? realtimePlayer;

  // Helper variable for [isInVoiceMode].
  bool _isVoiceMode = false;

  bool isMicEnabled = false;

  final _audioVolumeStreamController = StreamController<double>.broadcast();

  // Helper variable to prevent unnecessary calls to [setStatus].
  ChatStatus? _oldStatus;

  bool _isLoadingVoiceMode = false;

  // MARK: Properties

  @override
  bool get isLoadingVoiceMode => _isLoadingVoiceMode;

  @override
  Stream<double>? get audioVolumeStream => _audioVolumeStreamController.stream;

  @override
  bool get isInVoiceMode => _isVoiceMode;

  // MARK: Methods

  @override
  Future<void> dispose() async {
    await _tearDownPlayer();

    try {
      await recorder.stop();
      await recorder.dispose();
    } catch (_) {}

    _audioVolumeStreamController.close();
  }

  @override
  void setStatus(ChatStatus status) {
    // Preventing unnecessary calls.
    // Old status is the same as the new status.
    //
    // We allow "idle" because in certain cases, the UI might not update when
    // trying to exit voice mode.
    if (status == _oldStatus && ChatStatus.idle != status) {
      return;
    }

    // Preventing the status from going back to speaking from answering.
    if (_oldStatus == ChatStatus.speaking && status == ChatStatus.answering) {
      return;
    }

    _oldStatus = status;
    _setStatus(status);
  }

  @override
  Future<RealtimeModel> startVoiceMode() async {
    _logger.i('Starting voice mode');

    _isLoadingVoiceMode = true;
    _isVoiceMode = true;
    onStart();

    // Creating realtime model
    realtimeModel?.close();
    var rep = createRealtimeRepository();
    realtimeModel = rep;
    rep.open();

    rep.onResponse.listen((response) async {
      onResponse?.call(response, aiAudioBytesWaitingTranscription);
    });

    // Creating realtime audio player
    realtimePlayer = createRealtimeAudioPlayer();
    realtimePlayer?.resetBuffer();

    realtimePlayer?.stopPlayStream.listen((_) {
      _logger.d('AI finished speaking');
      setStatus(ChatStatus.listeningToUser);
      unmuteMic();
    });

    realtimePlayer?.volumeStream.listen((volume) {
      _audioVolumeStreamController.add(volume);
    });

    rep.onTranscriptionStart.listen((transcriptionStart) {
      onTranscriptionStart?.call(transcriptionStart);
    });

    var onTranscription = this.onTranscription;
    if (onTranscription != null) {
      rep.onTranscriptionItem.listen((transcription) {
        onTranscription(transcription);
      });
    }

    var onTranscriptionEnd = this.onTranscriptionEnd;
    if (onTranscriptionEnd != null) {
      rep.onTranscriptionEnd.listen((transcriptionEnd) {
        onTranscriptionEnd(
            transcriptionEnd, userAudioBytesWaitingTranscription);
      });
    }

    rep.onSpeech.listen((speech) {
      if (speech.role == Role.assistant) {
        setStatus(ChatStatus.speaking);
        _processAiBytes(speech.audioData);
        muteMic();
      }
    });

    rep.onSpeechStart.listen((speechStart) {
      var role = speechStart.role;
      if (role == Role.assistant) {
        realtimePlayer?.resetBuffer();
      }
    });

    rep.onSpeechEnd.listen((speechEnd) {
      if (speechEnd.done) {
        if (speechEnd.role == Role.user) {
          userAudioBytesWaitingTranscription.clear();
          userAudioBytesWaitingTranscription
              .addAll(userAudioBytesBeingRecorded);
          userAudioBytesBeingRecorded.clear();
          debugPrint(
              'AUDIO - onSpeechEnd ${userAudioBytesWaitingTranscription.length}');
        } else {
          aiAudioBytesWaitingTranscription.clear();
          aiAudioBytesWaitingTranscription.addAll(aiAudioBytesBeingRecorded);
          aiAudioBytesBeingRecorded.clear();
        }
      }

      var onSpeechEnd = this.onSpeechEnd;
      if (onSpeechEnd != null) {
        onSpeechEnd(speechEnd);
      }
    });

    rep.onConnectionOpen.listen((_) {
      _isLoadingVoiceMode = false;
      if (rep.isSendingInitialMessages) {
        _logger.i(
            'Connection is open but the system is receving initial messages. Wating until all messages are received');
        var sub = rep.onIsSendingInitialMessages.listen(null);
        sub.onData((isSending) async {
          _logger.i('Updated is sending initial message: $isSending');
          if (!isSending) {
            _startRecording();
            await sub.cancel();
          }
        });
      } else {
        _startRecording();
      }
    });

    rep.onConnectionClose.listen((_) {
      setStatus(ChatStatus.idle);
    });

    rep.onError.listen((error) {
      String msg = getErrorMessage(error) ?? 'Falha desconhecida';
      onError(msg);
    });

    // Preventing turning off the screen while the user is interacting using voice.
    WakelockPlus.enable();

    return rep;
  }

  @override
  Future<void> stopVoiceMode() async {
    _logger.i('Stoping voice mode');
    realtimeModel?.close();
    realtimeModel = null;

    _isLoadingVoiceMode = false;
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

  Future<void> _tearDownPlayer() async {
    try {
      realtimePlayer?.dispose();
      realtimePlayer = null;
    } on Exception catch (e) {
      _logger.e('Error disposing player', error: e);
    }
  }

  Future<void> _startRecording() async {
    _logger.d('Starting to record user');

    Stream<Uint8List> userAudioStream = await recorder.startStream();
    setStatus(ChatStatus.listeningToUser);

    userAudioStream.listen((bytes) {
      /// This exists because the library "record" does not mute the microphone
      /// when on web platform.
      if (!recorder.isRecording()) {
        return;
      }

      realtimeModel?.sendUserAudio(bytes);
      var volume = getAudioIntensityFromPcm16(bytes);
      _audioVolumeStreamController.add(volume);

      if (_oldStatus == ChatStatus.listeningToUser) {
        userAudioBytesBeingRecorded.addAll(bytes);
      }
    });
  }

  Future<void> muteMic() async {
    isMicEnabled = true;
    await recorder.pause();
    debugPrint('AUDIO MODE - MUTE');
  }

  Future<void> unmuteMic() async {
    if (!isMicEnabled) {
      debugPrint('Aborting unmute since it is not paused');
      return;
    }
    isMicEnabled = false;
    await recorder.resume();
    debugPrint('AUDIO MODE - UNMUTE');
  }

  void _processAiBytes(data) {
    if (data is String) {
      realtimePlayer?.appendData(data);
      Uint8List bytes = base64Decode(data);
      aiAudioBytesBeingRecorded.addAll(bytes);
    } else {
      Uint8List bytes = data;
      realtimePlayer?.appendBytes(bytes);
      aiAudioBytesBeingRecorded.addAll(bytes);
    }
  }
}
