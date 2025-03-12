import 'dart:async';

import 'package:logger/logger.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';
import 'package:vit_gpt_flutter_api/data/contracts/voice_mode_contract.dart';
import 'package:vit_gpt_flutter_api/data/vit_gpt_configuration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/enums/chat_status.dart';
import '../../features/usecases/get_error_message.dart';

class VoiceModeProvider with VoiceModeContract {
  final Logger _logger =
      VitGptFlutterConfiguration.groupedLogsFactory(['VoiceModeProvider']);

  final void Function() notifyListeners;
  final bool Function() isVoiceMode;
  final void Function(ChatStatus status) _setStatus;
  final void Function(String context, String message) errorReporter;
  final ChatStatus Function() getStatus;
  final Future<void> Function({
    required String text,
    required void Function(String chunk) onChunk,
  }) send;

  VoiceModeProvider({
    required this.notifyListeners,
    required this.isVoiceMode,
    required void Function(ChatStatus status) setStatus,
    required this.getStatus,
    required this.send,
    required this.errorReporter,
  }) : _setStatus = setStatus {
    unawaited(_setup());
  }

  MicSendMode? micSendMode;

  // final voiceRecorder = VoiceRecorderHandler();
  TranscribeModel? transcriber;

  /// Handler used in voice mode, to speake sentences generated by the AI model.
  SpeakerHandler? _speaker;

  @override
  Stream<double>? audioVolumeStream;

  /// Necessary because `ChatStatus.sendingPrompt` and `ChatStatus.answering`
  /// does not tell if voice mode is on.
  ///
  /// This variable is not always true for voice mode process, it is just a
  /// helper variable. Use [isVoiceMode] for this check.
  bool _isInVoiceMode = false;

  @override
  bool get isInVoiceMode => _isInVoiceMode;

  @override
  void dispose() {
    transcriber?.dispose();
    _speaker?.dispose();
  }

  Future<void> _setup() async {
    var micSendMode = await getMicSendMode();
    this.micSendMode = micSendMode;
  }

  @override
  Future<RealtimeModel?> startVoiceMode() async {
    if (isVoiceMode()) {
      return null;
    }

    // Preventing turning off the screen while the user is interacting using
    // voice.
    WakelockPlus.enable();

    await _listenToUser();
    return null;
  }

  /// Sends message to model, and speaks the model response as it gets streamed.
  Future<void> _getVoiceResponse(String input) async {
    _logger.i('Geting voice response');

    // For voice generation
    var speaker = await SpeakerHandler.fromLocalStorage();
    _speaker = speaker;
    audioVolumeStream = speaker.getVolumeStream();
    speaker.speakSentences();

    _isInVoiceMode = true;
    notifyListeners();

    // Get response
    await send(
      text: input,
      onChunk: (chunk) async {
        var chatStatus = getStatus();
        if (chatStatus == ChatStatus.idle) {
          _logger.w('Disposing speaker on chunk receive');
          speaker.dispose();
          return;
        }
        await speaker.process(chunk);
        if (speaker.hasPendingSpeaches) {
          setStatus(ChatStatus.answeringAndSpeaking);
        }
      },
    );

    _isInVoiceMode = false;

    // Checking if speaking was cancelled.
    var status = getStatus();

    if (status == ChatStatus.answeringAndSpeaking ||
        status == ChatStatus.answering) {
      setStatus(ChatStatus.speaking);
    }

    Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (speaker.hasPendingSpeaches) {
        _logger.w('Has pending speaches');
        return;
      }
      speaker.dispose();
      timer.cancel();
      _logger.i('Finished speaking a response!');

      // Preventing recorder from working while the speaker is active.
      while (speaker.isSpeaking) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (isVoiceMode()) {
        await _listenToUser();
      }
    });
  }

  /// Stops listening to the user, transcribes the audio to text, and gets
  /// voice response.
  Future<void> _stopListening() async {
    try {
      if (getStatus() == ChatStatus.idle) {
        return;
      }
      _logger.i('Stop user listening');

      await VitGptFlutterConfiguration.onListenEnd?.call();

      // Transcribe to create self message
      setStatus(ChatStatus.transcribing);
      notifyListeners();
      var transcriptionStream = transcriber?.transcribed;
      await transcriber?.endTranscription();
      String input = '';
      if (transcriptionStream != null) {
        _logger.d('Looping transcriptions');
        await for (var chunk in transcriptionStream) {
          _logger.i('Transcription result: $chunk');
          input = chunk;
        }
        _logger.i('Transcription: $input');

        // Sending to model
        if (getStatus() == ChatStatus.idle) {
          return;
        }
        setStatus(ChatStatus.thinking);
        audioVolumeStream = null;
        notifyListeners();
        await _getVoiceResponse(input);
      }
    } on Exception catch (e) {
      var error = getErrorMessage(e);
      errorReporter('Transcrição', error ?? '');
      _isInVoiceMode = false;
      setStatus(ChatStatus.idle);
    }
  }

  Future<bool> _listenToUser() async {
    _logger.i('Listening to user');
    setStatus(ChatStatus.listeningToUser);
    var transcriber = createTranscriberRepository();
    if (transcriber is TranscriberRepository) {
      transcriber.voiceRecorder.enableSilenceDetection =
          micSendMode == MicSendMode.intensitySilenceDetection;
    }
    this.transcriber = transcriber;
    await transcriber.startTranscribe();
    notifyListeners();
    transcriber.onSilenceChange.listen((silence) {
      _logger.i('Silence $silence');
      if (silence) {
        _stopListening();
      }
    });
    audioVolumeStream = transcriber.onMicVolumeChange;
    notifyListeners();
    return true;
  }

  @override
  Future<void> stopVoiceMode() async {
    if (!isVoiceMode()) {
      _logger.w('Stopping voice mode aborted since voice mode is not active');
      notifyListeners();
      return;
    }
    _logger.i('Stopping voice mode');

    audioVolumeStream = null;
    _isInVoiceMode = false;

    _speaker?.dispose();
    _speaker = null;

    try {
      transcriber?.dispose();
      transcriber = null;
      // I dont remember why we need this try catch block. Looks wrong.
    } finally {}

    setStatus(ChatStatus.idle);
    notifyListeners();

    // Allow the screen to turn off again.
    await WakelockPlus.disable();
  }

  /// If the provider is listening to the microphone, it stops recording.
  ///
  /// If the provider is speaking sentences from the AI, it stop speaking them.
  @override
  Future<void> stopVoiceInteraction() async {
    var status = getStatus();

    switch (status) {
      case ChatStatus.listeningToUser:
        await _stopListening();
      case ChatStatus.answeringAndSpeaking:
      case ChatStatus.speaking:
        _logger.i('Stopped AI speaking');
        _speaker?.dispose();
        _speaker = null;
      default:
        break;
    }
  }

  @override
  void setStatus(ChatStatus status) => _setStatus(status);
}
