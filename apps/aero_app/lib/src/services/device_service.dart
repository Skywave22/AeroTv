import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native device queries. The Android side implements `tv.aero/device`.
class DeviceService {
  const DeviceService._();

  static const _channel = MethodChannel('tv.aero/device');

  /// True on Android TV / Fire TV, using UiModeManager rather than a guess.
  static Future<bool> isAndroidTv() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('isTelevision') ?? false;
    } catch (_) {
      // Missing plugin (e.g. unit tests) → assume phone.
      return false;
    }
  }

  /// Device model, used in the About screen and crash reports.
  static Future<String> model() async {
    try {
      return await _channel.invokeMethod<String>('model') ?? 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }
}
