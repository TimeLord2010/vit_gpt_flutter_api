import 'package:vit_gpt_flutter_api/data/contracts/realtime_audio_player.dart';
import 'package:vit_gpt_flutter_api/data/vit_gpt_configuration.dart';
import 'package:vit_gpt_flutter_api/features/repositories/audio/vit_realtime_audio_player.dart';

RealtimeAudioPlayer createRealtimeAudioPlayer() {
  var fn = VitGptFlutterConfiguration.realtimeAudioPlayer;
  if (fn != null) {
    return fn();
  }
  return VitRealtimeAudioPlayer();
}
