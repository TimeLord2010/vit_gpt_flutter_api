import 'package:chatgpt_chat/data/enums/chat_status.dart';

enum VoiceModeStatus {
  listening,
  thinking,
  speaking;

  factory VoiceModeStatus.fromChatStatus(ChatStatus status) {
    return switch (status) {
      ChatStatus.speaking => VoiceModeStatus.speaking,
      ChatStatus.answeringAndSpeaking => VoiceModeStatus.speaking,
      ChatStatus.sendingPrompt => VoiceModeStatus.thinking,
      ChatStatus.transcribing => VoiceModeStatus.thinking,
      ChatStatus.thinking => VoiceModeStatus.thinking,
      ChatStatus.answering => VoiceModeStatus.thinking,
      ChatStatus.listeningToUser => VoiceModeStatus.listening,
      ChatStatus.idle => VoiceModeStatus.listening,
    };
  }
}
