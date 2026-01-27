import 'package:vit_gpt_dart_api/data/interfaces/realtime_model.dart';
import 'package:vit_gpt_flutter_api/data/enums/chat_status.dart';

mixin VoiceModeContract {
  /// Retuns the current audio volume.
  ///
  /// If the user is speaking, it returns the volume of the user's voice.
  ///
  /// If the AI is speaking, it returns the volume of the AI's voice.
  Stream<double>? get audioVolumeStream;

  /// Indicates the voice mode is active or not.
  bool get isInVoiceMode;

  /// Indicates the voice mode is being started or exited.
  bool get isLoadingVoiceMode;

  /// Stops the current voice interaction.
  ///
  /// If the user is speaking, it stops listening and sends it to the AI.
  ///
  /// If the AI is speaking, it stops speaking and starts listening to the user
  /// again.
  void stopVoiceInteraction();

  Future<void> stopVoiceMode();

  Future<RealtimeModel?> startVoiceMode({bool isPressToTalkMode = false});

  /// Pauses both AI speech playback and microphone recording
  Future<void> pauseVoiceMode();

  /// Resumes AI speech playback and microphone recording (if appropriate)
  Future<void> resumeVoiceMode();

  /// Envia o áudio do usuário para o modelo de IA.
  void commitUserAudio();

  /// Indicates whether voice mode is currently paused
  bool get isPaused;

  void dispose();

  void setStatus(ChatStatus status);
}
