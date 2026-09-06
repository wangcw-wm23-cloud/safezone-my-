import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/incident_room_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/session_gate.dart';
import '../services/auth_recovery_handler.dart';
import '../services/device_binding_service.dart';
import '../services/emergency_coordination_service.dart';
import '../services/push_notification_service.dart';
import '../services/session_manager.dart';
import '../services/sos_service.dart';
import 'location_requirement_gate.dart';

class SosNotificationHost extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  const SosNotificationHost({
    super.key,
    required this.child,
    required this.navigatorKey,
    required this.messengerKey,
  });

  @override
  State<SosNotificationHost> createState() =>
      _SosNotificationHostState();
}

class _SosNotificationHostState extends State<SosNotificationHost>
    with WidgetsBindingObserver {
  final _supabase = Supabase.instance.client;
  final _session = SessionManager.instance;
  final _push = PushNotificationService.instance;
  final _recoveryHandler = AuthRecoveryHandler();

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<void>? _pushSubscription;

  Timer? _timer;

  final Set<String> _seen = {};

  Map<String, dynamic>? _alert;

  String? _userId;
  String? _syncError;

  DateTime? _lastSync;
  DateTime? _lastValidation;

  bool _active = true;
  bool _gpsReady = false;
  bool _polling = false;
  bool _syncing = false;
  bool _acting = false;
  bool _roomOpen = false;

  int _generation = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _active =
        WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed;

    _userId = _session.authorizedUserId.value;

    _session.authorizedUserId.addListener(_accessChanged);

    _recoveryHandler.start(
      onPasswordRecovery: _openPasswordRecovery,
    );

    _authSubscription =
        _supabase.auth.onAuthStateChange.listen((state) {
          if (state.event == AuthChangeEvent.passwordRecovery) {
            _openPasswordRecovery();
          } else if (state.event == AuthChangeEvent.signedOut) {
            _session.recovering = false;
            _session.clearAccess();
            unawaited(_push.invalidateToken());
          } else if (state.event == AuthChangeEvent.signedIn) {
            _session.recovering = false;
          }
        }, onError: (Object error) {
          debugPrint('GLOBAL AUTH ERROR: $error');
        });

    _pushSubscription = _push.signals.listen((_) {
      _lastSync = null;
      unawaited(_poll());
    });

    _timer = Timer.periodic(
      const Duration(seconds: 2),
          (_) => unawaited(_poll()),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_poll());
    });
  }

  void _accessChanged() {
    if (!mounted) {
      return;
    }

    final previous = _userId;
    final next = _session.authorizedUserId.value;

    if (previous == next) {
      return;
    }

    _generation++;
    _userId = next;
    _seen.clear();
    _lastSync = null;
    _lastValidation = null;

    setState(() {
      _alert = null;
      _syncError = null;
    });

    if (previous != null &&
        next == null &&
        !_session.recovering) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _session.recovering ||
            _session.authorizedUserId.value != null) {
          return;
        }

        widget.navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const SessionGate(),
          ),
              (route) => false,
        );
      });
    }

    unawaited(_poll());
  }

  void _openPasswordRecovery() {
    if (!mounted || _session.recovering) {
      return;
    }

    _session.enterRecovery();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      widget.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const ResetPasswordScreen(),
        ),
            (route) => false,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }

    setState(() {
      _active = state == AppLifecycleState.resumed;

      if (!_active) {
        _alert = null;
      }
    });

    if (_active) {
      _lastSync = null;
      _lastValidation = null;
      unawaited(_poll());
    }
  }

  Future<void> _poll() async {
    if (!mounted || !_active || _polling) {
      return;
    }

    _polling = true;

    try {
      final enabled =
      await Geolocator.isLocationServiceEnabled();

      final permission = await Geolocator.checkPermission();

      final ready = enabled &&
          (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse);

      if (!mounted) {
        return;
      }

      if (_gpsReady != ready) {
        setState(() {
          _gpsReady = ready;

          if (!ready) {
            _alert = null;
          }
        });
      }

      if (!ready ||
          _session.recovering ||
          _userId == null) {
        return;
      }

      final now = DateTime.now();

      if (_lastSync == null ||
          now.difference(_lastSync!) >=
              const Duration(seconds: 10)) {
        unawaited(_sync());
      }
    } catch (error) {
      debugPrint('GLOBAL LOCATION CHECK ERROR: $error');

      if (mounted) {
        setState(() {
          _gpsReady = false;
          _alert = null;
        });
      }
    } finally {
      _polling = false;
    }
  }

  bool _isCurrent(String userId, int generation) {
    return mounted &&
        _active &&
        _gpsReady &&
        !_session.recovering &&
        _generation == generation &&
        _userId == userId &&
        _supabase.auth.currentUser?.id == userId;
  }

  Future<void> _sync() async {
    final userId = _userId;

    if (_syncing || userId == null) {
      return;
    }

    _syncing = true;
    _lastSync = DateTime.now();

    final generation = _generation;

    try {
      if (_lastValidation == null ||
          DateTime.now().difference(_lastValidation!) >=
              const Duration(minutes: 1)) {
        final valid = await _session.validateSession();

        if (!valid || !_isCurrent(userId, generation)) {
          return;
        }

        _lastValidation = DateTime.now();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (!_isCurrent(userId, generation)) {
        return;
      }

      if (!position.accuracy.isFinite ||
          position.accuracy < 0 ||
          position.accuracy > 100) {
        throw StateError('Waiting for a more accurate location.');
      }

      final token = await _push.prepareToken();

      if (!_isCurrent(userId, generation)) {
        return;
      }

      final deviceId =
      await DeviceBindingService.instance.getOrCreateDeviceId();

      final actions = await _push.actions(userId);

      if (!_isCurrent(userId, generation)) {
        return;
      }

      final response = await _supabase.rpc(
        'sz_sync_notifications',
        params: {
          'p_user_id': userId,
          'p_device_id': deviceId,
          'p_token': token,
          'p_latitude': position.latitude,
          'p_longitude': position.longitude,
          'p_accuracy': position.accuracy,
          'p_located_at':
          position.timestamp.toUtc().toIso8601String(),
          'p_actions': actions,
        },
      );

      await _push.acknowledgeActions(userId, actions);

      if (!_isCurrent(userId, generation)) {
        return;
      }

      final rows = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      setState(() {
        _syncError = null;

        if (_alert != null &&
            !rows.any(
                  (row) => row['alert_id'] == _alert!['alert_id'],
            )) {
          _alert = null;
        }
      });

      final tap = _push.pendingTap;

      if (tap != null && !_acting && !_roomOpen) {
        if (tap['user_id'] != userId) {
          await _push.acknowledgeTap(tap['alert_id']!);
          _showMessage(
            'This notification belongs to another account.',
          );
        } else {
          await _openAlert(
            tap['alert_id']!,
            join: false,
            fromNotification: true,
          );

          return;
        }
      }

      if (!_isCurrent(userId, generation) ||
          _acting ||
          _roomOpen ||
          _alert != null) {
        return;
      }

      final localActions = await _push.actions(userId);

      if (!_isCurrent(userId, generation)) {
        return;
      }

      for (final row in rows) {
        final id = row['alert_id'].toString();

        if (!_seen.contains(id) &&
            !localActions.containsKey(id) &&
            !actions.containsKey(id)) {
          setState(() {
            _alert = row;
          });

          break;
        }
      }
    } catch (error, stackTrace) {
      debugPrint('SOS NOTIFICATION SYNC ERROR: $error');
      debugPrint(stackTrace.toString());

      if (_isCurrent(userId, generation)) {
        setState(() {
          _alert = null;
          _syncError =
          'Nearby alerts could not refresh. Retrying…';
        });
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _saveAction(
      String userId,
      String alertId,
      String action,
      ) async {
    await _push.recordAction(userId, alertId, action);

    try {
      if (_supabase.auth.currentUser?.id != userId) {
        return;
      }

      await _supabase.rpc(
        'sz_ack_alert',
        params: {
          'p_user_id': userId,
          'p_alert_id': alertId,
          'p_action': action,
        },
      );

      await _push.acknowledgeActions(
        userId,
        {alertId: action},
      );
    } catch (error) {
      debugPrint('SAVE NOTIFICATION ACTION ERROR: $error');
    }
  }

  Future<void> _dismissAlert() async {
    final alert = _alert;
    final userId = _userId;

    if (alert == null || userId == null || _acting) {
      return;
    }

    final id = alert['alert_id'].toString();

    setState(() {
      _acting = true;
    });

    try {
      await _saveAction(userId, id, 'dismissed');

      if (mounted && _userId == userId) {
        _seen.add(id);

        setState(() {
          _alert = null;
        });
      }
    } catch (error) {
      _showMessage('Unable to save your choice. Please retry.');
    } finally {
      if (mounted) {
        setState(() {
          _acting = false;
        });
      }

      _lastSync = null;
    }
  }

  Future<void> _openAlert(
      String alertId, {
        required bool join,
        bool fromNotification = false,
      }) async {
    final userId = _userId;
    final generation = _generation;

    if (userId == null ||
        _acting ||
        _roomOpen ||
        !_isCurrent(userId, generation)) {
      return;
    }

    setState(() {
      _acting = true;
    });

    try {
      final raw = await _supabase.rpc(
        'sz_get_alert_incident',
        params: {
          'p_user_id': userId,
          'p_alert_id': alertId,
        },
      );

      if (!_isCurrent(userId, generation)) {
        return;
      }

      if (raw == null) {
        _seen.add(alertId);

        await _saveAction(userId, alertId, 'opened');
        await _push.acknowledgeTap(alertId);

        if (mounted) {
          setState(() {
            _alert = null;
          });
        }

        _showMessage('This SOS has already ended.');
        return;
      }

      final incident = SosIncident.fromMap(
        Map<String, dynamic>.from(raw as Map),
      );

      if (join) {
        final existing =
        await EmergencyCoordinationService.instance
            .getMyResponse(incident.id);

        if (!_isCurrent(userId, generation)) {
          return;
        }

        if (existing?.status != 'accepted') {
          await EmergencyCoordinationService.instance.joinIncident(
            incidentId: incident.id,
            category: incident.category,
            latitude: incident.latitude,
            longitude: incident.longitude,
            address: incident.address,
          );
        }
      }

      if (!_isCurrent(userId, generation)) {
        return;
      }

      _seen.add(alertId);

      try {
        await _saveAction(userId, alertId, 'opened');

        if (fromNotification) {
          await _push.acknowledgeTap(alertId);
        }
      } catch (error) {
        debugPrint('SAVE OPENED NOTIFICATION ERROR: $error');
      }

      if (!_isCurrent(userId, generation)) {
        return;
      }

      final navigator = widget.navigatorKey.currentState;

      if (navigator == null) {
        return;
      }

      setState(() {
        _alert = null;
        _roomOpen = true;
      });

      try {
        await navigator.push<void>(
          MaterialPageRoute<void>(
            settings: RouteSettings(
              name: '/sos-notification/${incident.id}',
            ),
            builder: (_) => IncidentRoomScreen(
              initialIncident: incident,
              isOwner: incident.userId == userId,
            ),
          ),
        );
      } finally {
        _roomOpen = false;
      }
    } catch (error) {
      final message = error is PostgrestException
          ? error.message
          : error.toString().replaceFirst('Exception: ', '');

      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _acting = false;
        });
      }

      _lastSync = null;
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    widget.messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _category(String value) {
    return switch (value) {
      'medical' => 'Medical Emergency',
      'crime' => 'Crime / Personal Threat',
      'accident' => 'Accident',
      'fire_hazard' => 'Fire / Hazard',
      'other' => 'Other Emergency',
      _ => 'Someone Needs Help',
    };
  }

  Widget _buildAlert(Map<String, dynamic> alert) {
    final incident =
    Map<String, dynamic>.from(alert['incident'] as Map);

    final id = alert['alert_id'].toString();

    final distance =
    (alert['distance_m'] as num).toDouble().round();

    final started =
    DateTime.parse(incident['created_at'].toString()).toLocal();

    final time =
        '${started.hour.toString().padLeft(2, '0')}:'
        '${started.minute.toString().padLeft(2, '0')}';

    return Stack(
      children: [
        const ModalBarrier(
          dismissible: false,
          color: Colors.black54,
        ),
        SafeArea(
          child: Center(
            child: AlertDialog(
              icon: const Icon(
                Icons.sos_rounded,
                color: Colors.red,
                size: 40,
              ),
              title: const Text('Someone nearby needs help'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _category(incident['category'].toString()),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(alert['requester_name'].toString()),
                  const SizedBox(height: 6),
                  Text('Approximately $distance m away'),
                  const SizedBox(height: 6),
                  Text(
                    'Started ${started.day}/${started.month} $time',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Joining shares your location with this SOS team.',
                  ),
                  if (_acting) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _acting ? null : _dismissAlert,
                  child: const Text('Not now'),
                ),
                TextButton(
                  onPressed: _acting
                      ? null
                      : () => _openAlert(id, join: false),
                  child: const Text('View details'),
                ),
                FilledButton(
                  onPressed: _acting
                      ? null
                      : () => _openAlert(id, join: true),
                  child: const Text('I can help'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_active &&
            _gpsReady &&
            _userId != null &&
            _syncError != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Text(
                    _syncError!,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onErrorContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_active &&
            _gpsReady &&
            _userId != null &&
            !_session.recovering &&
            _alert != null)
          _buildAlert(_alert!),
        if (!_gpsReady)
          const Positioned.fill(
            child: LocationRequirementGate(
              child: SizedBox.expand(),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _generation++;

    WidgetsBinding.instance.removeObserver(this);

    _session.authorizedUserId.removeListener(_accessChanged);

    _timer?.cancel();
    _authSubscription?.cancel();
    _pushSubscription?.cancel();
    _recoveryHandler.dispose();

    super.dispose();
  }
}