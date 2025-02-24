import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:vit_gpt_dart_api/vit_gpt_dart_api.dart';
import 'package:vit_gpt_flutter_api/data/contracts/voice_mode_contract.dart';
import 'package:vit_gpt_flutter_api/data/enums/chat_status.dart';
import 'package:vit_gpt_flutter_api/features/repositories/audio/vit_audio_recorder.dart';
import 'package:vit_gpt_flutter_api/features/usecases/get_error_message.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class RealtimeVoiceModeProvider with VoiceModeContract {
  final void Function(ChatStatus) _setStatus;
  final void Function(String text) addUserText;
  final void Function(String text) addAiText;
  final void Function(String errorMessage) onError;

  RealtimeVoiceModeProvider({
    required void Function(ChatStatus status) setStatus,
    required this.addUserText,
    required this.addAiText,
    required this.onError,
  }) : _setStatus = setStatus;

  /// Audio player handler.
  final soloud = SoLoud.instance;

  /// Reference to the audio recorder used to record the user voice.
  final recorder = VitAudioRecorder();

  /// Class that handles the api calls to the real time api.
  RealtimeModel? _realtimeModel;

  /// Helper vairable for [isInVoiceMode].
  bool _isVoiceMode = false;

  /// Reference to AI speech player.
  ///
  /// Necessary to dispose of the underline player.
  AudioSource? currentSound;

  final _audioVolumeStreamController = StreamController<double>();

  /// Helper variable to prevent unecessary calls to [setStatus].
  ChatStatus? _oldStatus;

  @override
  Stream<double>? get audioVolumeStream => _audioVolumeStreamController.stream;

  @override
  bool get isInVoiceMode => _isVoiceMode;

  @override
  Future<void> startVoiceMode() async {
    _realtimeModel?.close();

    if (!soloud.isInitialized) {
      await soloud.init();
    }

    var rep = createRealtimeRepository();
    _realtimeModel = rep;
    rep.open();

    if (currentSound != null) {
      SoLoud.instance.setDataIsEnded(currentSound!);
    }

    var source = currentSound = SoLoud.instance.setBufferStream(
      maxBufferSizeDuration: const Duration(minutes: 10),
      bufferingTimeNeeds: 0.5,
      sampleRate: 24000,
      channels: Channels.mono,
      format: BufferType.s16le,
      bufferingType: BufferingType.released,
    );
    SoLoud.instance.play(source);

    rep.onUserText.listen((text) {
      setStatus(ChatStatus.transcribing);
      addUserText(text);
    });

    rep.onAiText.listen((text) {
      setStatus(ChatStatus.answering);
      addAiText(text);
    });

    rep.onAiAudio.listen((Uint8List bytes) {
      setStatus(ChatStatus.speaking);
      soloud.addAudioDataStream(source, bytes);
    });

    rep.onConnectionClose.listen((_) {
      setStatus(ChatStatus.idle);
    });

    rep.onError.listen((error) {
      String msg = getErrorMessage(error) ?? 'Falha desconhecida';
      onError(msg);
    });

    _isVoiceMode = true;
    _startRecording();

    // Preventing turning off the screen while the user is interacting using
    // voice.
    await WakelockPlus.enable();
  }

  double _calculatePcm16Volume(Uint8List bytes) {
    var samples = bytes.buffer.asInt16List();
    var sum = 0.0;
    for (var sample in samples) {
      sum += (sample * sample);
    }
    var rms = sqrt(sum / samples.length);
    // Convert to range 0-1, assuming 16-bit audio (-32768 to 32767)
    return rms / 32768;
  }

  Future<void> _startRecording() async {
    setStatus(ChatStatus.listeningToUser);
    Stream<Uint8List> userAudioStream = await recorder.startStream();

    userAudioStream.listen((bytes) {
      _realtimeModel?.sendUserAudio(bytes);
      var volume = _calculatePcm16Volume(bytes);
      _audioVolumeStreamController.add(volume);
    });
  }

  @override
  Future<void> stopVoiceMode() async {
    _realtimeModel?.close();
    _realtimeModel = null;

    _isVoiceMode = false;
    setStatus(ChatStatus.idle);

    // Allow the screen to turn off again.
    await WakelockPlus.disable();
  }

  @override
  void stopVoiceInteraction() {
    // Does nothing for now.
  }

  @override
  Future<void> dispose() async {
    if (currentSound != null) {
      SoLoud.instance.setDataIsEnded(currentSound!);
    }

    var isRecording = await recorder.isRecording();
    if (isRecording) recorder.stop();
  }

  @override
  void setStatus(ChatStatus status) {
    // Preventing unecessary calls.

    // Old status is the same as the new status.
    if (status == _oldStatus) {
      return;
    }

    // Preventing the status from going back to speaking from answering.
    if (_oldStatus == ChatStatus.speaking && status == ChatStatus.answering) {
      return;
    }

    _oldStatus = status;

    _setStatus(status);
  }
}
