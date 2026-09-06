import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_binding_service.dart';
import 'push_notification_service.dart';

class SessionManager {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  static const Duration inactivityLimit = Duration(days: 7);

  final SupabaseClient supabase = Supabase.instance.client;

  final ValueNotifier<String?> authorizedUserId =
  ValueNotifier<String?>(null);

  Future<bool>? _validation;

  bool _signingOut = false;
  bool recovering = false;

  int _revision = 0;

  String _activityKey(String userId) {
    return 'safezone_last_active_at_$userId';
  }

  void clearAccess() {
    _revision++;
    authorizedUserId.value = null;
  }

  void enterRecovery() {
    recovering = true;
    clearAccess();
  }

  Future<void> markActive() async {
    final user = supabase.auth.currentUser;
    final revision = _revision;

    if (user == null || _signingOut || recovering) {
      return;
    }

    await _storage.write(
      key: _activityKey(user.id),
      value: DateTime.now().toUtc().toIso8601String(),
    );

    if (revision == _revision &&
        !_signingOut &&
        !recovering &&
        supabase.auth.currentUser?.id == user.id) {
      authorizedUserId.value = user.id;
    }
  }

  Future<DateTime?> getLastActive() async {
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      return null;
    }

    final value = await _storage.read(
      key: _activityKey(userId),
    );

    return value == null ? null : DateTime.tryParse(value);
  }

  Future<bool> isInactiveTooLong() async {
    final lastActive = await getLastActive();

    if (lastActive == null) {
      return false;
    }

    return DateTime.now().toUtc().difference(
      lastActive.toUtc(),
    ) >=
        inactivityLimit;
  }

  Future<bool> validateSession() {
    return _validation ??= _validateSession().whenComplete(() {
      _validation = null;
    });
  }

  Future<bool> _validateSession() async {
    if (_signingOut || recovering) {
      return false;
    }

    var session = supabase.auth.currentSession;

    if (session == null) {
      clearAccess();
      return false;
    }

    final userId = session.user.id;
    final revision = _revision;

    if (await isInactiveTooLong()) {
      await logout();
      return false;
    }

    if (session.isExpired) {
      try {
        final response = await supabase.auth.refreshSession();
        session = response.session;
      } on AuthException catch (error) {
        const invalidSessionCodes = {
          'refresh_token_not_found',
          'refresh_token_already_used',
          'session_not_found',
          'session_expired',
        };

        if (invalidSessionCodes.contains(error.code)) {
          await logout();
          return false;
        }

        rethrow;
      }

      if (session == null) {
        await logout();
        return false;
      }
    }

    if (revision != _revision ||
        supabase.auth.currentUser?.id != userId ||
        recovering ||
        _signingOut) {
      return false;
    }

    if (session.user.emailConfirmedAt == null) {
      await logout();
      return false;
    }

    final deviceAllowed =
    await DeviceBindingService.instance.checkDeviceBinding();

    if (revision != _revision ||
        supabase.auth.currentUser?.id != userId ||
        recovering ||
        _signingOut) {
      return false;
    }

    if (!deviceAllowed) {
      await logout();
      return false;
    }

    await markActive();

    return authorizedUserId.value == userId;
  }

  Future<void> logout() async {
    if (_signingOut) {
      return;
    }

    final userId = supabase.auth.currentUser?.id;

    _signingOut = true;
    clearAccess();

    try {
      await PushNotificationService.instance.detachCurrentDevice();

      await supabase.auth.signOut(
        scope: SignOutScope.local,
      );

      await clearLocalSession(userId: userId);
    } finally {
      _signingOut = false;
    }
  }

  Future<void> clearLocalSession({String? userId}) async {
    final id = userId ?? supabase.auth.currentUser?.id;

    if (id != null) {
      await _storage.delete(key: _activityKey(id));
    }

    await _storage.delete(key: 'safezone_last_active_at');
  }
}