import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionManager {
  SessionManager._();

  static final SessionManager instance =
  SessionManager._();

  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  static const String _lastActiveKey =
      'safezone_last_active_at';

  // ============================================================
  // 7 DAYS INACTIVITY
  // ============================================================

  static const Duration inactivityLimit =
  Duration(
    days: 7,
  );

  final SupabaseClient supabase =
      Supabase.instance.client;

  // ============================================================
  // MARK USER ACTIVE
  //
  // Call this:
  // - after successful login
  // - when app startup session is accepted
  // ============================================================

  Future<void> markActive() async {
    final now =
    DateTime.now().toUtc();

    await _storage.write(
      key: _lastActiveKey,
      value: now.toIso8601String(),
    );

    debugPrint(
      'SESSION ACTIVE: ${now.toIso8601String()}',
    );
  }

  // ============================================================
  // READ LAST ACTIVE
  // ============================================================

  Future<DateTime?> getLastActive() async {
    final value =
    await _storage.read(
      key: _lastActiveKey,
    );

    if (value == null ||
        value.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(
      value,
    );
  }

  // ============================================================
  // CHECK IF USER HAS BEEN INACTIVE > 7 DAYS
  // ============================================================

  Future<bool> isInactiveTooLong() async {
    final lastActive =
    await getLastActive();

    if (lastActive == null) {
      return false;
    }

    final now =
    DateTime.now().toUtc();

    final difference =
    now.difference(
      lastActive.toUtc(),
    );

    return difference >
        inactivityLimit;
  }

  // ============================================================
  // VALIDATE CURRENT SESSION
  //
  // true:
  // keep user logged in
  //
  // false:
  // login required
  // ============================================================

  Future<bool> validateSession() async {
    final session =
        supabase.auth.currentSession;

    if (session == null) {
      await clearLocalSession();

      return false;
    }

    final expiredByInactivity =
    await isInactiveTooLong();

    if (expiredByInactivity) {
      debugPrint(
        'SESSION EXPIRED: more than 7 days inactive.',
      );

      await supabase.auth.signOut();

      await clearLocalSession();

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
    } finally {
      await clearLocalSession();
    }
  }

  // ============================================================
  // CLEAR LOCAL SESSION INFO
  // ============================================================

  Future<void> clearLocalSession() async {
    await _storage.delete(
      key: _lastActiveKey,
    );
  }
}