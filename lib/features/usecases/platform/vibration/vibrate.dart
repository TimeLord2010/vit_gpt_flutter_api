import 'dart:io';

import 'package:vibration/vibration.dart';

import '../../../../factories/logger.dart';

Future<void> vibrate() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;

  // TODO: FIX; Not doing anything
  logger.debug('Vibrating...');
  await Vibration.vibrate(
    duration: 3000,
    pattern: [
      500,
      500,
      500,
      500,
      500,
      500,
    ],
  );
  logger.debug('Ended vibration');
}
