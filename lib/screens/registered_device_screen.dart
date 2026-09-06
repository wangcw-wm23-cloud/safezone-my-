import 'package:flutter/material.dart';

import '../services/device_binding_service.dart';

class RegisteredDeviceScreen extends StatefulWidget {
  const RegisteredDeviceScreen({
    super.key,
  });

  @override
  State<RegisteredDeviceScreen> createState() =>
      _RegisteredDeviceScreenState();
}

class _RegisteredDeviceScreenState
    extends State<RegisteredDeviceScreen> {
  final DeviceBindingService deviceService =
      DeviceBindingService.instance;

  bool _isLoading = true;

  bool _isProcessing = false;

  String? _currentDeviceId;

  String _currentDeviceName = '';

  String _platform = '';

  Map<String, dynamic>? _registeredDevice;

  DeviceBindingStatus _bindingStatus =
      DeviceBindingStatus.notBound;

  bool get _hasRegisteredDevice {
    return _bindingStatus !=
        DeviceBindingStatus.notBound;
  }

  bool get _isCurrentDeviceBound {
    return _bindingStatus ==
        DeviceBindingStatus.currentDevice;
  }

  bool get _anotherDeviceBound {
    return _bindingStatus ==
        DeviceBindingStatus.anotherDevice;
  }

  bool get _invalidDeviceRecords {
    return _bindingStatus ==
        DeviceBindingStatus.invalidMultipleDevices;
  }

  @override
  void initState() {
    super.initState();

    _loadDevice();
  }


  Future<void> _loadDevice({
    bool showLoading = true,
  }) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final deviceId =
      await deviceService.getOrCreateDeviceId();

      final deviceName =
      deviceService.getDeviceName();

      final platform =
      deviceService.getPlatformName();

      final status =
      await deviceService.getBindingStatus();

      if (status ==
          DeviceBindingStatus.currentDevice) {
        await deviceService.updateLastSeen();
      }

      final registeredDevice =
      await deviceService.getActiveDevice();

      if (!mounted) return;

      setState(() {
        _currentDeviceId = deviceId;
        _currentDeviceName = deviceName;
        _platform = platform;
        _bindingStatus = status;
        _registeredDevice = registeredDevice;
      });
    } catch (e, stackTrace) {
      debugPrint(
        'LOAD DEVICE ERROR: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to load device information.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  Future<void> _bindDevice() async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await deviceService.bindCurrentDevice();

      await _loadDevice(
        showLoading: false,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This device has been registered successfully.',
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint(
        'BIND DEVICE ERROR: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }


  Future<void> _unbindDevice() async {
    if (!_isCurrentDeviceBound ||
        _isProcessing) {
      return;
    }

    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Unbind Device?',
          ),
          content: const Text(
            'This device will no longer be registered '
                'to your SafeZone account. Emergency '
                'features will require device binding again.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Unbind',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await deviceService.unbindCurrentDevice();

      await _loadDevice(
        showLoading: false,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This device has been unbound.',
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint(
        'UNBIND DEVICE ERROR: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }


  String get _statusTitle {
    switch (_bindingStatus) {
      case DeviceBindingStatus.notBound:
        return 'No Registered Device';

      case DeviceBindingStatus.currentDevice:
        return 'Device Registered';

      case DeviceBindingStatus.anotherDevice:
        return 'Another Device Registered';

      case DeviceBindingStatus.invalidMultipleDevices:
        return 'Device Record Error';
    }
  }

  String get _statusDescription {
    switch (_bindingStatus) {
      case DeviceBindingStatus.notBound:
        return 'You may continue using SafeZone. '
            'Bind this device when you want to enable '
            'protected emergency features.';

      case DeviceBindingStatus.currentDevice:
        return 'This device is linked to your '
            'SafeZone account.';

      case DeviceBindingStatus.anotherDevice:
        return 'Your SafeZone account is currently '
            'linked to another device.';

      case DeviceBindingStatus.invalidMultipleDevices:
        return 'Multiple active device records were '
            'found. Please check the database.';
    }
  }

  IconData get _statusIcon {
    switch (_bindingStatus) {
      case DeviceBindingStatus.notBound:
        return Icons.devices_outlined;

      case DeviceBindingStatus.currentDevice:
        return Icons.verified_user_rounded;

      case DeviceBindingStatus.anotherDevice:
        return Icons.phonelink_lock_rounded;

      case DeviceBindingStatus.invalidMultipleDevices:
        return Icons.error_outline_rounded;
    }
  }

  Color _statusColor(
      BuildContext context,
      ) {
    switch (_bindingStatus) {
      case DeviceBindingStatus.notBound:
        return Theme.of(context)
            .colorScheme
            .primary;

      case DeviceBindingStatus.currentDevice:
        return Colors.green;

      case DeviceBindingStatus.anotherDevice:
        return Colors.orange;

      case DeviceBindingStatus.invalidMultipleDevices:
        return Colors.red;
    }
  }


  String _shortDeviceId(
      String? id,
      ) {
    if (id == null || id.isEmpty) {
      return '-';
    }

    if (id.length <= 16) {
      return id;
    }

    return '${id.substring(0, 7)}...'
        '${id.substring(id.length - 7)}';
  }

  String _formatDate(
      dynamic value,
      ) {
    if (value == null) {
      return '-';
    }

    final date =
    DateTime.tryParse(value.toString());

    if (date == null) {
      return '-';
    }

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }


  @override
  Widget build(
      BuildContext context,
      ) {
    final statusColor =
    _statusColor(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Registered Device',
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ||
                _isProcessing
                ? null
                : () {
              _loadDevice();
            },
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : SafeArea(
        child:
        SingleChildScrollView(
          padding:
          const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.stretch,
            children: [
              Icon(
                _statusIcon,
                size: 75,
                color: statusColor,
              ),

              const SizedBox(
                height: 18,
              ),

              Text(
                _statusTitle,
                textAlign:
                TextAlign.center,
                style:
                const TextStyle(
                  fontSize: 23,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                _statusDescription,
                textAlign:
                TextAlign.center,
              ),

              const SizedBox(
                height: 28,
              ),

              Container(
                padding:
                const EdgeInsets.all(
                  20,
                ),
                decoration:
                BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(
                    20,
                  ),
                  color:
                  Theme.of(context)
                      .colorScheme
                      .surfaceContainer,
                  border:
                  Border.all(
                    color:
                    Theme.of(context)
                        .colorScheme
                        .outlineVariant,
                  ),
                ),
                child: Column(
                  children: [
                    _infoRow(
                      icon: Icons
                          .smartphone_rounded,
                      title:
                      'Current Device',
                      value:
                      _currentDeviceName,
                    ),

                    const Divider(),

                    _infoRow(
                      icon: Icons
                          .computer_rounded,
                      title: 'Platform',
                      value: _platform
                          .toUpperCase(),
                    ),

                    const Divider(),

                    _infoRow(
                      icon: Icons
                          .fingerprint_rounded,
                      title: 'Device ID',
                      value:
                      _shortDeviceId(
                        _currentDeviceId,
                      ),
                    ),
                  ],
                ),
              ),

              if (_registeredDevice !=
                  null) ...[
                const SizedBox(
                  height: 20,
                ),

                const Text(
                  'Registered Device Information',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                Container(
                  padding:
                  const EdgeInsets.all(
                    20,
                  ),
                  decoration:
                  BoxDecoration(
                    borderRadius:
                    BorderRadius.circular(
                      20,
                    ),
                    color:
                    Theme.of(context)
                        .colorScheme
                        .surfaceContainer,
                  ),
                  child: Column(
                    children: [
                      _infoRow(
                        icon: Icons
                            .devices_rounded,
                        title: 'Device',
                        value:
                        _registeredDevice![
                        'device_name']
                            ?.toString() ??
                            '-',
                      ),

                      const Divider(),

                      _infoRow(
                        icon: Icons
                            .link_rounded,
                        title: 'Bound At',
                        value:
                        _formatDate(
                          _registeredDevice![
                          'bound_at'],
                        ),
                      ),

                      const Divider(),

                      _infoRow(
                        icon: Icons
                            .schedule_rounded,
                        title: 'Last Seen',
                        value:
                        _formatDate(
                          _registeredDevice![
                          'last_seen_at'],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(
                height: 25,
              ),

              if (!_hasRegisteredDevice)
                SizedBox(
                  height: 52,
                  child:
                  ElevatedButton.icon(
                    onPressed:
                    _isProcessing
                        ? null
                        : _bindDevice,
                    icon: const Icon(
                      Icons.add_link_rounded,
                    ),
                    label: _isProcessing
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      'Bind This Device',
                    ),
                  ),
                ),

              if (_isCurrentDeviceBound)
                SizedBox(
                  height: 52,
                  child:
                  OutlinedButton.icon(
                    onPressed:
                    _isProcessing
                        ? null
                        : _unbindDevice,
                    icon: const Icon(
                      Icons
                          .link_off_rounded,
                    ),
                    label: const Text(
                      'Unbind Device',
                    ),
                  ),
                ),

              if (_anotherDeviceBound)
                Container(
                  padding:
                  const EdgeInsets.all(
                    14,
                  ),
                  decoration:
                  BoxDecoration(
                    color: Colors.orange
                        .withOpacity(0.08),
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                    border: Border.all(
                      color: Colors.orange
                          .withOpacity(0.25),
                    ),
                  ),
                  child: const Text(
                    'This account is already '
                        'bound to another device.',
                    textAlign:
                    TextAlign.center,
                  ),
                ),

              if (_invalidDeviceRecords)
                Container(
                  padding:
                  const EdgeInsets.all(
                    14,
                  ),
                  decoration:
                  BoxDecoration(
                    color: Colors.red
                        .withOpacity(0.08),
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: const Text(
                    'More than one active device '
                        'record was found.',
                    textAlign:
                    TextAlign.center,
                  ),
                ),

              const SizedBox(
                height: 20,
              ),

              Container(
                padding:
                const EdgeInsets.all(
                  15,
                ),
                decoration:
                BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(
                    15,
                  ),
                  color:
                  Theme.of(context)
                      .colorScheme
                      .surfaceContainer,
                ),
                child: const Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.security_rounded,
                      size: 20,
                    ),

                    SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child: Text(
                        'SafeZone allows one active '
                            'device per account. Device '
                            'binding is optional until '
                            'the user enables protected '
                            'emergency features.',
                        style: TextStyle(
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 22,
        ),

        const SizedBox(
          width: 13,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                value,
                style: const TextStyle(
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}