enum ChatStatus {
  idle,
  sendingPrompt,
  listeningToUser,
  transcribing,
  thinking,
  answering,
  answeringAndSpeaking,
  speaking;

  bool get isSpeaking => [speaking, answeringAndSpeaking].contains(this);
}
