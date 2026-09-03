import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum DeviceBindingStatus {
  notBound,
  currentDevice,
  anotherDevice,
  invalidMultipleDevices,
}

class DeviceBindingService {
  DeviceBindingService._();

  static final DeviceBindingService instance =
  DeviceBindingService._();

  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  static const String _deviceIdKey =
      'safezone_installation_device_id';

  final SupabaseClient supabase =
      Supabase.instance.client;

  // ============================================================
  // DEVICE ID
  // ============================================================

  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(
      key: _deviceIdKey,
    );

    if (existing != null &&
        existing.trim().isNotEmpty) {
      return existing;
    }

    final random = Random.secure();

    final bytes = List<int>.generate(
      32,
          (_) => random.nextInt(256),
    );

    final deviceId = base64UrlEncode(bytes)
        .replaceAll('=', '');

    await _storage.write(
      key: _deviceIdKey,
      value: deviceId,
    );

    return deviceId;
  }

  // ============================================================
  // ACTIVE DEVICE ROWS
  // ============================================================

  Future<List<Map<String, dynamic>>>
  _getActiveDevices() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return [];
    }

    final List<Map<String, dynamic>> result =
    await supabase
        .from('user_devices')
        .select(
      'id, user_id, device_id, device_name, '
          'platform, is_active, bound_at, '
          'last_seen_at, updated_at',
    )
        .eq('user_id', user.id)
        .eq('is_active', true)
        .limit(2);

    return result;
  }

  // ============================================================
  // BINDING STATUS
  // ============================================================

  Future<DeviceBindingStatus>
  getBindingStatus() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return DeviceBindingStatus.notBound;
    }

    final currentDeviceId =
    await getOrCreateDeviceId();

    final activeDevices =
    await _getActiveDevices();

    // User has not chosen to bind any device.
    if (activeDevices.isEmpty) {
      return DeviceBindingStatus.notBound;
    }

    // Database should not contain more than one active device.
    if (activeDevices.length > 1) {
      return DeviceBindingStatus
          .invalidMultipleDevices;
    }

    final registeredDeviceId =
    activeDevices.first['device_id']
        ?.toString();

    if (registeredDeviceId ==
        currentDeviceId) {
      return DeviceBindingStatus.currentDevice;
    }

    return DeviceBindingStatus.anotherDevice;
  }

  // ============================================================
  // APP ACCESS CHECK
  //
  // Not bound:
  // allow access.
  //
  // Same device:
  // allow access.
  //
  // Another device:
  // reject access.
  // ============================================================

  Future<bool> checkDeviceBinding() async {
    final status =
    await getBindingStatus();

    if (status ==
        DeviceBindingStatus.notBound) {
      return true;
    }

    if (status ==
        DeviceBindingStatus.currentDevice) {
      await updateLastSeen();

      return true;
    }

    return false;
  }

  // ============================================================
  // SOS CHECK
  //
  // Unlike normal App access, SOS requires the current
  // device to be formally bound.
  // ============================================================

  Future<bool> isCurrentDeviceBound() async {
    final status =
    await getBindingStatus();

    return status ==
        DeviceBindingStatus.currentDevice;
  }

  // ============================================================
  // GET ACTIVE DEVICE
  // ============================================================

  Future<Map<String, dynamic>?>
  getActiveDevice() async {
    final devices =
    await _getActiveDevices();

    if (devices.length != 1) {
      return null;
    }

    return devices.first;
  }

  // ============================================================
  // USER PRESSES "BIND THIS DEVICE"
  // ============================================================

  Future<void> bindCurrentDevice() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in before binding a device.',
      );
    }

    final currentStatus =
    await getBindingStatus();

    if (currentStatus ==
        DeviceBindingStatus.currentDevice) {
      await updateLastSeen();

      return;
    }

    if (currentStatus ==
        DeviceBindingStatus.anotherDevice) {
      throw Exception(
        'This account is already bound to another device.',
      );
    }

    if (currentStatus ==
        DeviceBindingStatus
            .invalidMultipleDevices) {
      throw Exception(
        'Multiple active device records were found.',
      );
    }

    final deviceId =
    await getOrCreateDeviceId();

    final now = DateTime.now()
        .toUtc()
        .toIso8601String();

    try {
      await supabase
          .from('user_devices')
          .insert({
        'user_id': user.id,
        'device_id': deviceId,
        'device_name': getDeviceName(),
        'platform': getPlatformName(),
        'is_active': true,
        'bound_at': now,
        'last_seen_at': now,
        'updated_at': now,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        final newStatus =
        await getBindingStatus();

        if (newStatus ==
            DeviceBindingStatus
                .currentDevice) {
          return;
        }

        throw Exception(
          'This account was bound to another device.',
        );
      }

      rethrow;
    }
  }

  // ============================================================
  // UPDATE LAST SEEN
  // ============================================================

  Future<void> updateLastSeen() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    final deviceId =
    await getOrCreateDeviceId();

    final now = DateTime.now()
        .toUtc()
        .toIso8601String();

    await supabase
        .from('user_devices')
        .update({
      'last_seen_at': now,
      'updated_at': now,
    })
        .eq('user_id', user.id)
        .eq('device_id', deviceId)
        .eq('is_active', true);
  }

  // ============================================================
  // REMOVE CURRENT DEVICE BINDING
  // ============================================================

  Future<void> unbindCurrentDevice() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'User session is unavailable.',
      );
    }

    final status =
    await getBindingStatus();

    if (status !=
        DeviceBindingStatus.currentDevice) {
      throw Exception(
        'This device is not the registered device.',
      );
    }

    final deviceId =
    await getOrCreateDeviceId();

    await supabase
        .from('user_devices')
        .update({
      'is_active': false,
      'updated_at': DateTime.now()
          .toUtc()
          .toIso8601String(),
    })
        .eq('user_id', user.id)
        .eq('device_id', deviceId)
        .eq('is_active', true);
  }

  // ============================================================
  // DEVICE DETAILS
  // ============================================================

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