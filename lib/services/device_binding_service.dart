import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceBindingService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _deviceIdKey = 'safezone_installation_device_id';

  final SupabaseClient supabase = Supabase.instance.client;

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

  Future<bool> checkDeviceBinding() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return false;
    }

    final currentDeviceId = await getOrCreateDeviceId();

    final existing = await supabase
        .from('user_devices')
        .select()
        .eq('user_id', user.id)
        .eq('is_active', true)
        .maybeSingle();

    // First device
    if (existing == null) {
      await bindCurrentDevice();

      return true;
    }

    final registeredDeviceId = existing['device_id'];

    // Same device

    if (registeredDeviceId == currentDeviceId) {
      await updateLastSeen();

      return true;
    }

    // Different device

    return false;
  }

  Future<void> bindCurrentDevice() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    final deviceId = await getOrCreateDeviceId();

    final now = DateTime.now().toIso8601String();

    await supabase.from('user_devices').insert({
      'user_id': user.id,

      'device_id': deviceId,

      'device_name': getDeviceName(),

      'platform': getPlatformName(),

      'is_active': true,

      'bound_at': now,

      'last_seen_at': now,

      'updated_at': now,
    });
  }

  Future<void> updateLastSeen() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    final deviceId = await getOrCreateDeviceId();

    await supabase
        .from('user_devices')
        .update({
          'last_seen_at': DateTime.now().toIso8601String(),

          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', user.id)
        .eq('device_id', deviceId);
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
