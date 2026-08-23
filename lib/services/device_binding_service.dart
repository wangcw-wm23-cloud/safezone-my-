import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceBindingService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _deviceIdKey = 'safezone_installation_device_id';

  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);

    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();

    final bytes = List<int>.generate(32, (_) => random.nextInt(256));

    final deviceId = base64UrlEncode(bytes).replaceAll('=', '');

    await _storage.write(key: _deviceIdKey, value: deviceId);

    return deviceId;
  }

  String getPlatformName() {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';

      case TargetPlatform.iOS:
        return 'ios';

      case TargetPlatform.windows:
        return 'windows';

      case TargetPlatform.macOS:
        return 'macos';

      case TargetPlatform.linux:
        return 'linux';

      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  String getDeviceName() {
    if (kIsWeb) {
      return 'Web Browser';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android Device';

      case TargetPlatform.iOS:
        return 'iPhone / iPad';

      case TargetPlatform.windows:
        return 'Windows Device';

      case TargetPlatform.macOS:
        return 'Mac Device';

      case TargetPlatform.linux:
        return 'Linux Device';

      case TargetPlatform.fuchsia:
        return 'Device';
    }
  }
}
