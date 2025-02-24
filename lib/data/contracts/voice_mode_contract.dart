import 'package:vit_gpt_flutter_api/data/enums/chat_status.dart';

mixin VoiceModeContract {
  /// Retuns the current audio volume.
  ///
  /// If the user is speaking, it returns the volume of the user's voice.
  ///
  /// If the AI is speaking, it returns the volume of the AI's voice.
  Stream<double>? get audioVolumeStream;

  bool get isInVoiceMode;

  /// Stops the current voice interaction.
  ///
  /// If the user is speaking, it stops listening and sends it to the AI.
  ///
  /// If the AI is speaking, it stops speaking and starts listening to the user
  /// again.
  void stopVoiceInteraction();

  Future<void> stopVoiceMode();

  Future<void> startVoiceMode();

  void dispose();

  void setStatus(ChatStatus status);
}
