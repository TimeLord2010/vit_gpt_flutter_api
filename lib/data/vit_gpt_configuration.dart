import 'dart:async';

import 'package:vit_gpt_flutter_api/data/contracts/realtime_audio_player.dart';

class VitGptFlutterConfiguration {
  /// Called when the user finishes speaking.
  static FutureOr<void> Function()? onListenEnd;

  static RealtimeAudioPlayer Function()? realtimeAudioPlayer;
}
