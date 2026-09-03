import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_binding_service.dart';

class SessionManager {
  SessionManager._();

  static final SessionManager instance =
  SessionManager._();

  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  static const String _lastActiveKey =
      'safezone_last_active_at';

  static const Duration inactivityLimit =
  Duration(days: 7);

  final SupabaseClient supabase =
      Supabase.instance.client;

  // ============================================================
  // MARK ACTIVE
  // ============================================================

  Future<void> markActive() async {
    final now = DateTime.now().toUtc();

    await _storage.write(
      key: _lastActiveKey,
      value: now.toIso8601String(),
    );
  }

  // ============================================================
  // LAST ACTIVE
  // ============================================================

  Future<DateTime?> getLastActive() async {
    final value = await _storage.read(
      key: _lastActiveKey,
    );

    if (value == null ||
        value.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  // ============================================================
  // INACTIVITY
  // ============================================================

  Future<bool> isInactiveTooLong() async {
    final lastActive = await getLastActive();

    if (lastActive == null) {
      return false;
    }

    final difference =
    DateTime.now().toUtc().difference(
      lastActive.toUtc(),
    );

    return difference > inactivityLimit;
  }

  // ============================================================
  // VALIDATE SESSION
  // ============================================================

  Future<bool> validateSession() async {
    Session? session =
        supabase.auth.currentSession;

    if (session == null) {
      await clearLocalSession();

      return false;
    }

    if (session.isExpired) {
      try {
        final response =
        await supabase.auth
            .refreshSession();

        session = response.session;

        if (session == null) {
          await logout();

          return false;
        }
      } catch (e) {
        debugPrint(
          'SESSION REFRESH ERROR: $e',
        );

        await logout();

        return false;
      }
    }

    if (await isInactiveTooLong()) {
      await logout();

      return false;
    }

    // No binding = allowed.
    // Same device = allowed.
    // Different device = rejected.
    final deviceAllowed =
    await DeviceBindingService.instance
        .checkDeviceBinding();

    if (!deviceAllowed) {
      await logout();

      return false;
    }

    await markActive();

    return true;
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      debugPrint(
        'LOGOUT ERROR: $e',
      );
    } finally {
      await clearLocalSession();
    }
  }

  Future<void> clearLocalSession() async {
    await _storage.delete(
      key: _lastActiveKey,
    );
  }
}