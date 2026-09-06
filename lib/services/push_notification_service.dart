import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_binding_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance =
  PushNotificationService._();

  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  final StreamController<void> _signals =
  StreamController<void>.broadcast();

  Future<void> _storageQueue = Future<void>.value();

  Future<void>? _initialization;

  String? _token;
  Map<String, String>? _pendingTap;

  bool get supported =>
      !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android;

  Stream<void> get signals => _signals.stream;

  Map<String, String>? get pendingTap {
    final value = _pendingTap;
    return value == null ? null : Map.unmodifiable(value);
  }

  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _storageQueue.then((_) => action());

    _storageQueue = result.then<void>(
          (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return result;
  }

  Future<void> initialize() {
    if (!supported) {
      return Future<void>.value();
    }

    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    FirebaseMessaging.onMessage.listen(
          (_) => _signals.add(null),
      onError: (Object error) {
        debugPrint('FCM MESSAGE ERROR: $error');
      },
    );

    FirebaseMessaging.onMessageOpenedApp.listen(
          (message) {
        unawaited(_saveTap(message));
      },
      onError: (Object error) {
        debugPrint('FCM OPEN ERROR: $error');
      },
    );

    FirebaseMessaging.instance.onTokenRefresh.listen(
          (token) {
        _token = token;
        _signals.add(null);
      },
      onError: (Object error) {
        debugPrint('FCM TOKEN ERROR: $error');
      },
    );

    try {
      final saved = await _storage.read(
        key: 'safezone_pending_notification',
      );

      if (saved != null) {
        _pendingTap = Map<String, String>.from(
          jsonDecode(saved) as Map,
        );
      }

      final initial =
      await FirebaseMessaging.instance.getInitialMessage();

      if (initial != null) {
        await _saveTap(initial);
      }
    } catch (error) {
      debugPrint('FCM STARTUP ERROR: $error');
    }
  }

  Future<void> _saveTap(RemoteMessage message) async {
    if (message.data['type'] != 'sos_alert') {
      return;
    }

    final alertId = message.data['alert_id']?.toString();
    final userId = message.data['user_id']?.toString();

    if (alertId == null || userId == null) {
      return;
    }

    try {
      await _locked(() async {
        _pendingTap = {
          'alert_id': alertId,
          'user_id': userId,
        };

        await _storage.write(
          key: 'safezone_pending_notification',
          value: jsonEncode(_pendingTap),
        );
      });

      _signals.add(null);
    } catch (error) {
      debugPrint('FCM SAVE TAP ERROR: $error');
    }
  }

  Future<void> acknowledgeTap(String alertId) {
    return _locked(() async {
      if (_pendingTap?['alert_id'] != alertId) {
        return;
      }

      _pendingTap = null;

      await _storage.delete(
        key: 'safezone_pending_notification',
      );
    });
  }

  Future<String?> prepareToken() async {
    if (!supported) {
      return null;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      final requested = await _storage.read(
        key: 'safezone_notification_permission_requested_v1',
      );

      NotificationSettings settings;

      if (requested == 'true') {
        settings = await messaging.getNotificationSettings();
      } else {
        settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        await _storage.write(
          key: 'safezone_notification_permission_requested_v1',
          value: 'true',
        );
      }

      if (settings.authorizationStatus !=
          AuthorizationStatus.authorized &&
          settings.authorizationStatus !=
              AuthorizationStatus.provisional) {
        return null;
      }

      _token ??= await messaging.getToken();

      return _token;
    } catch (error) {
      debugPrint('FCM PREPARE ERROR: $error');
      return null;
    }
  }

  Future<Map<String, String>> _readActions(String userId) async {
    final raw = await _storage.read(
      key: 'safezone_notification_actions_$userId',
    );

    if (raw == null) {
      return {};
    }

    return Map<String, String>.from(
      jsonDecode(raw) as Map,
    );
  }

  Future<Map<String, String>> actions(String userId) {
    return _locked(() => _readActions(userId));
  }

  Future<void> recordAction(
      String userId,
      String alertId,
      String action,
      ) {
    return _locked(() async {
      final values = await _readActions(userId);
      values[alertId] = action;

      await _storage.write(
        key: 'safezone_notification_actions_$userId',
        value: jsonEncode(values),
      );
    });
  }

  Future<void> acknowledgeActions(
      String userId,
      Map<String, String> sent,
      ) {
    return _locked(() async {
      final values = await _readActions(userId);

      for (final entry in sent.entries) {
        if (values[entry.key] == entry.value) {
          values.remove(entry.key);
        }
      }

      await _storage.write(
        key: 'safezone_notification_actions_$userId',
        value: jsonEncode(values),
      );
    });
  }

  Future<void> detachCurrentDevice() async {
    try {
      final deviceId =
      await DeviceBindingService.instance.getOrCreateDeviceId();

      await Supabase.instance.client.rpc(
        'sz_unregister_device',
        params: {'p_device_id': deviceId},
      );
    } catch (error) {
      debugPrint('UNREGISTER NOTIFICATION DEVICE ERROR: $error');
    }

    await invalidateToken();
  }

  Future<void> invalidateToken() async {
    _token = null;

    if (!supported) {
      return;
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      debugPrint('DELETE FCM TOKEN ERROR: $error');
    }
  }
}