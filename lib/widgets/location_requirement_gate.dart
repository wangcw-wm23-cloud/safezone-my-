import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_requirement_service.dart';

class LocationRequirementGate
    extends StatefulWidget {
  final Widget child;

  const LocationRequirementGate({
    super.key,
    required this.child,
  });

  @override
  State<LocationRequirementGate> createState() =>
      _LocationRequirementGateState();
}

class _LocationRequirementGateState
    extends State<LocationRequirementGate>
    with WidgetsBindingObserver {
  final LocationRequirementService _service =
      LocationRequirementService.instance;

  StreamSubscription<ServiceStatus>?
  _serviceSubscription;

  Timer? _recheckTimer;

  LocationRequirementStatus _status =
      LocationRequirementStatus.checking;

  bool _checking = false;
  bool _openingSettings = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _checkLocation(
      requestPermission: true,
    );

    _startMonitoring();
  }

  void _startMonitoring() {
    // Geolocator Web 不支持 service status stream。
    if (!kIsWeb) {
      try {
        _serviceSubscription =
            _service.serviceStatusStream.listen(
                  (serviceStatus) {
                if (serviceStatus ==
                    ServiceStatus.disabled) {
                  if (!mounted) return;

                  setState(() {
                    _status =
                        LocationRequirementStatus
                            .serviceDisabled;
                  });
                } else {
                  _checkLocation();
                }
              },
              onError: (_) {
                // Timer 仍然会继续检查。
              },
            );
      } catch (_) {
        // 部分 Desktop 平台可能不支持。
      }
    }

    // 每两秒检查一次。
    _recheckTimer = Timer.periodic(
      const Duration(seconds: 2),
          (_) {
        _checkLocation();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (state == AppLifecycleState.resumed) {
      _openingSettings = false;

      _checkLocation();
    }
  }

  Future<void> _checkLocation({
    bool requestPermission = false,
  }) async {
    if (_checking) {
      return;
    }

    _checking = true;

    try {
      final result = await _service.check(
        requestPermission: requestPermission,
      );

      if (!mounted) return;

      if (_status != result) {
        setState(() {
          _status = result;
        });
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _handlePrimaryAction() async {
    if (_openingSettings) {
      return;
    }

    switch (_status) {
      case LocationRequirementStatus
          .serviceDisabled:
        setState(() {
          _openingSettings = true;
        });

        final opened =
        await _service.openLocationSettings();

        if (!opened && mounted) {
          await _service.openAppSettings();
        }

        if (mounted) {
          setState(() {
            _openingSettings = false;
          });
        }

        await _checkLocation();

        break;

      case LocationRequirementStatus
          .permissionDenied:
        await _checkLocation(
          requestPermission: true,
        );

        break;

      case LocationRequirementStatus
          .permissionDeniedForever:
        setState(() {
          _openingSettings = true;
        });

        await _service.openAppSettings();

        if (mounted) {
          setState(() {
            _openingSettings = false;
          });
        }

        await _checkLocation();

        break;

      case LocationRequirementStatus.error:
      case LocationRequirementStatus.checking:
        await _checkLocation();

        break;

      case LocationRequirementStatus.ready:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _serviceSubscription?.cancel();

    _recheckTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_status ==
        LocationRequirementStatus.ready) {
      return widget.child;
    }

    if (_status ==
        LocationRequirementStatus.checking) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final content =
    _contentForStatus(_status);

    final scheme =
        Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
              const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints:
                const BoxConstraints(
                  maxWidth: 430,
                ),
                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                        scheme.errorContainer,
                      ),
                      child: Icon(
                        content.icon,
                        size: 46,
                        color:
                        scheme.onErrorContainer,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      content.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      content.message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        color: scheme
                            .onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed:
                        _openingSettings
                            ? null
                            : _handlePrimaryAction,
                        icon: _openingSettings
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : Icon(
                          content.actionIcon,
                        ),
                        label: Text(
                          content.actionLabel,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      'SafeZone will continue automatically after location is enabled.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: scheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _LocationGateContent _contentForStatus(
      LocationRequirementStatus status,
      ) {
    switch (status) {
      case LocationRequirementStatus
          .serviceDisabled:
        return const _LocationGateContent(
          icon: Icons.location_off_rounded,
          title: 'Location Is Required',
          message:
          'SafeZone depends on your location to send SOS alerts, show nearby emergencies and share live positions with helpers. Please turn on device location to continue.',
          actionLabel:
          'Open Location Settings',
          actionIcon: Icons.settings_rounded,
        );

      case LocationRequirementStatus
          .permissionDenied:
        return const _LocationGateContent(
          icon: Icons.gps_off_rounded,
          title: 'Allow Location Access',
          message:
          'Location permission is required for emergency features. Tap below and allow precise location while using SafeZone.',
          actionLabel: 'Allow Location',
          actionIcon:
          Icons.my_location_rounded,
        );

      case LocationRequirementStatus
          .permissionDeniedForever:
        return const _LocationGateContent(
          icon: Icons.wrong_location_rounded,
          title:
          'Location Permission Blocked',
          message:
          'Location access has been permanently denied. Open SafeZone settings and enable precise location permission to continue.',
          actionLabel: 'Open App Settings',
          actionIcon:
          Icons.app_settings_alt_rounded,
        );

      case LocationRequirementStatus.error:
        return const _LocationGateContent(
          icon:
          Icons.location_searching_rounded,
          title:
          'Unable to Check Location',
          message:
          'SafeZone could not confirm your location settings. Check your device location service and try again.',
          actionLabel: 'Try Again',
          actionIcon: Icons.refresh_rounded,
        );

      case LocationRequirementStatus.checking:
      case LocationRequirementStatus.ready:
        return const _LocationGateContent(
          icon:
          Icons.location_searching_rounded,
          title: 'Checking Location',
          message:
          'Please wait while SafeZone checks location access.',
          actionLabel: 'Try Again',
          actionIcon: Icons.refresh_rounded,
        );
    }
  }
}

class _LocationGateContent {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final IconData actionIcon;

  const _LocationGateContent({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.actionIcon,
  });
}