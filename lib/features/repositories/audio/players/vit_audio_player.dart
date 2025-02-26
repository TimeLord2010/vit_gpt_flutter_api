import 'package:flutter/widgets.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';
import 'package:vit_gpt_flutter_api/features/repositories/audio/players/just_audio_player.dart';

import 'mp3_audio_player.dart';
import 'ogg_audio_player.dart';

class VitAudioPlayer extends AudioPlayer with ChangeNotifier {
  final bool randomizeVolumeStream;
  final bool useLegacyAudioPlayer;
  VitAudioPlayer({
    required super.audioPath,
    this.randomizeVolumeStream = false,
    this.useLegacyAudioPlayer = false,
  });

  bool get isAsset => audioPath.startsWith('assets');

  @override
  SimpleAudioPlayer createPlayer(String name, String extension) {
    if (useLegacyAudioPlayer) {
      return JustAudioPlayer(
        name,
        isAsset: isAsset,
        randomizeVolumeStream: randomizeVolumeStream,
      );
    }
    if (extension == AudioFormat.opus.name) {
      return OggAudioPlayer(name);
    }

    if (extension == AudioFormat.mp3.name) {
      return Mp3AudioPlayer(
        name,
        isAsset: isAsset,
        //randomizeVolumeStream: randomizeVolumeStream,
      );
    }

    throw Exception('Unsupported file extension');
  }

  @override
  void updateUI() {
    notifyListeners();
  }
}
