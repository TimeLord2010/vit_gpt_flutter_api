import 'dart:async';

import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';
import 'package:vit_gpt_flutter_api/data/vit_gpt_configuration.dart';

import '../../data/enums/chat_status.dart';
import '../../factories/logger.dart';
import '../../features/usecases/get_error_message.dart';

class VoiceModeProvider {
  final void Function() notifyListeners;
  final bool Function() isVoiceMode;
  final void Function(ChatStatus status) setStatus;
  final void Function(String context, String message) errorReporter;
  final ChatStatus Function() getStatus;
  final Future<void> Function({
    required String text,
    required void Function(String chunk) onChunk,
  }) send;

  VoiceModeProvider({
    required this.notifyListeners,
    required this.isVoiceMode,
    required this.setStatus,
    required this.getStatus,
    required this.send,
    required this.errorReporter,
  }) {
    unawaited(_setup());
  }

  MicSendMode? micSendMode;

  // final voiceRecorder = VoiceRecorderHandler();
  TranscribeModel? transcriber;

  /// Handler used in voice mode, to speake sentences generated by the AI model.
  SpeakerHandler? _speaker;

  /// A Stream of volumes either from the microphone or speaker, depending
  /// if the providder is listening from the user, or the AI is speaking.
  Stream<double>? audioVolumeStream;

  /// Necessary because `ChatStatus.sendingPrompt` and `ChatStatus.answering`
  /// does not tell if voice mode is on.
  ///
  /// This variable is not always true for voice mode process, it is just a
  /// helper variable. Use [isVoiceMode] for this check.
  bool isInVoiceMode = false;

  void dispose() {
    transcriber?.dispose();
    _speaker?.dispose();
  }

  Future<void> _setup() async {
    var micSendMode = await getMicSendMode();
    this.micSendMode = micSendMode;
  }

  Future<void> startVoiceMode() async {
    if (isVoiceMode()) {
      return;
    }
    await _listenToUser();
  }

  Future<void> _getVoiceResponse(String input) async {
    logger.info('Geting voice response');

    // For voice generation
    var speaker = await SpeakerHandler.fromLocalStorage();
    _speaker = speaker;
    audioVolumeStream = speaker.getVolumeStream();
    speaker.speakSentences();

    isInVoiceMode = true;
    notifyListeners();

    // Get response
    await send(
      text: input,
      onChunk: (chunk) async {
        var chatStatus = getStatus();
        if (chatStatus == ChatStatus.idle) {
          logger.warn('Disposing speaker on chunk receive');
          speaker.dispose();
          return;
        }
        await speaker.process(chunk);
        if (speaker.hasPendingSpeaches) {
          setStatus(ChatStatus.answeringAndSpeaking);
        }
      },
    );

    isInVoiceMode = false;

    // Checking if speaking was cancelled.
    var status = getStatus();

    if (status == ChatStatus.answeringAndSpeaking ||
        status == ChatStatus.answering) {
      setStatus(ChatStatus.speaking);
    }

    Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (speaker.hasPendingSpeaches) {
        logger.warn('Has pending speaches');
        return;
      }
      speaker.dispose();
      timer.cancel();
      logger.info('Finished speaking a response!');

      // Preventing recorder from working while the speaker is active.
      while (speaker.isSpeaking) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (isVoiceMode()) {
        await _listenToUser();
      }
    });
  }

  Future<void> _stopListening() async {
    try {
      if (getStatus() == ChatStatus.idle) {
        return;
      }
      logger.info('Stop user listening');

      await VitGptFlutterConfiguration.onListenEnd?.call();

      // Transcribe to create self message
      setStatus(ChatStatus.transcribing);
      notifyListeners();
      await transcriber?.endTranscription();
      String input = '';
      var transcriptionStream = transcriber?.transcribed;
      if (transcriptionStream != null) {
        await for (var chunk in transcriptionStream) {
          logger.info('Transcription result: $chunk');
          input = chunk;
        }
        logger.info('Transcription: $input');

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
      isInVoiceMode = false;
      setStatus(ChatStatus.idle);
    }
  }

  Future<bool> _listenToUser() async {
    logger.info('Listening to user');
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
      logger.info('Silence $silence');
      if (silence) {
        _stopListening();
      }
    });
    audioVolumeStream = transcriber.onMicVolumeChange;
    notifyListeners();
    return true;
  }

  Future<void> stopVoiceMode() async {
    if (!isVoiceMode()) {
      logger.warn('Stopping voice mode aborted since voice mode is not active');
      notifyListeners();
      return;
    }
    logger.info('Stopping voice mode');

    audioVolumeStream = null;
    isInVoiceMode = false;

    _speaker?.dispose();
    _speaker = null;

    try {
      transcriber?.dispose();
      transcriber = null;
      // I dont remember why we need this try catch block. Looks wrong.
    } finally {}

    setStatus(ChatStatus.idle);
  }

  /// If the provider is listening to the microphone, it stops recording.
  ///
  /// If the provider is speaking sentences from the AI, it stop speaking them.
  Future<void> stopVoiceInteraction() async {
    var status = getStatus();

    switch (status) {
      case ChatStatus.listeningToUser:
        await _stopListening();
      case ChatStatus.answeringAndSpeaking:
      case ChatStatus.speaking:
        logger.info('Stopped AI speaking');
        _speaker?.dispose();
        _speaker = null;
      default:
        break;
    }
  }
}
