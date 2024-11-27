import 'dart:io';

import 'package:vibration/vibration.dart';

Future<bool> hasVibrator() async {
  if (!Platform.isAndroid && !Platform.isIOS) return false;
  var has = await Vibration.hasVibrator();
  return has ?? false;
}
