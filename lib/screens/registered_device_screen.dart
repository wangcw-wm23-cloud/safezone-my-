import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/device_binding_service.dart';

class RegisteredDeviceScreen extends StatefulWidget {
  const RegisteredDeviceScreen({super.key});

  @override
  State<RegisteredDeviceScreen> createState() => _RegisteredDeviceScreenState();
}

class _RegisteredDeviceScreenState extends State<RegisteredDeviceScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  final DeviceBindingService deviceService = DeviceBindingService();

  bool _isLoading = true;
  bool _isProcessing = false;

  String? _currentDeviceId;
  String _currentDeviceName = '';
  String _platform = '';

  Map<String, dynamic>? _registeredDevice;

  bool get _hasRegisteredDevice => _registeredDevice != null;

  bool get _isCurrentDeviceBound {
    if (_registeredDevice == null || _currentDeviceId == null) {
      return false;
    }

    return _registeredDevice!['device_id']?.toString() == _currentDeviceId;
  }

  @override
  void initState() {
    super.initState();
    _loadDevice();
  }

  Future<void> _loadDevice() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      return;
    }

    try {
      final deviceId = await deviceService.getOrCreateDeviceId();

      final deviceName = deviceService.getDeviceName();

      final platform = deviceService.getPlatformName();

      final device = await supabase
          .from('user_devices')
          .select(
            'id, user_id, device_id, device_name, '
            'platform, is_active, bound_at, last_seen_at',
          )
          .eq('user_id', user.id)
          .maybeSingle();

      if (device != null && device['device_id']?.toString() == deviceId) {
        await supabase
            .from('user_devices')
            .update({
              'last_seen_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', user.id)
            .eq('device_id', deviceId);
      }

      if (!mounted) return;

      setState(() {
        _currentDeviceId = deviceId;
        _currentDeviceName = deviceName;
        _platform = platform;
        _registeredDevice = device;
      });
    } catch (e) {
      debugPrint('LOAD DEVICE ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load device information.')),
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
    final user = supabase.auth.currentUser;

    if (user == null || _currentDeviceId == null) {
      return;
    }

    if (_hasRegisteredDevice && !_isCurrentDeviceBound) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This account is already bound to another device.'),
        ),
      );

      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await supabase.from('user_devices').insert({
        'user_id': user.id,
        'device_id': _currentDeviceId,
        'device_name': _currentDeviceName,
        'platform': _platform,
        'is_active': true,
        'last_seen_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This device has been registered successfully.'),
        ),
      );

      await _loadDevice();
    } on PostgrestException catch (e) {
      if (!mounted) return;

      if (e.code == '23505') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This device is already registered to another SafeZone account.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      debugPrint('BIND DEVICE ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to register this device.')),
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
    final user = supabase.auth.currentUser;

    if (user == null || _registeredDevice == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unbind Device?'),
          content: const Text(
            'This device will no longer be registered '
            'to your SafeZone account. Emergency features '
            'will require device binding again.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Unbind'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await supabase.from('user_devices').delete().eq('user_id', user.id);

      if (!mounted) return;

      setState(() {
        _registeredDevice = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Device has been unbound.')));
    } catch (e) {
      debugPrint('UNBIND DEVICE ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to unbind device.')));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _shortDeviceId(String? id) {
    if (id == null || id.isEmpty) {
      return '-';
    }

    if (id.length <= 16) {
      return id;
    }

    return '${id.substring(0, 7)}...'
        '${id.substring(id.length - 7)}';
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return '-';
    }

    final date = DateTime.tryParse(value.toString());

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registered Device')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      _isCurrentDeviceBound
                          ? Icons.verified_user_rounded
                          : Icons.devices_outlined,
                      size: 75,
                      color: _isCurrentDeviceBound
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary,
                    ),

                    const SizedBox(height: 18),

                    Text(
                      _isCurrentDeviceBound
                          ? 'Device Registered'
                          : _hasRegisteredDevice
                          ? 'Another Device Registered'
                          : 'No Registered Device',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _isCurrentDeviceBound
                          ? 'This device is securely linked to your SafeZone account.'
                          : _hasRegisteredDevice
                          ? 'Your SafeZone account is currently linked to another device.'
                          : 'Bind this device before using protected SafeZone emergency features.',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 28),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        children: [
                          _infoRow(
                            icon: Icons.smartphone_rounded,
                            title: 'Current Device',
                            value: _currentDeviceName,
                          ),

                          const Divider(),

                          _infoRow(
                            icon: Icons.computer_rounded,
                            title: 'Platform',
                            value: _platform.toUpperCase(),
                          ),

                          const Divider(),

                          _infoRow(
                            icon: Icons.fingerprint_rounded,
                            title: 'Device ID',
                            value: _shortDeviceId(_currentDeviceId),
                          ),
                        ],
                      ),
                    ),

                    if (_registeredDevice != null) ...[
                      const SizedBox(height: 20),

                      const Text(
                        'Registered Device Information',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                        child: Column(
                          children: [
                            _infoRow(
                              icon: Icons.devices_rounded,
                              title: 'Device',
                              value:
                                  _registeredDevice!['device_name']
                                      ?.toString() ??
                                  '-',
                            ),

                            const Divider(),

                            _infoRow(
                              icon: Icons.link_rounded,
                              title: 'Bound At',
                              value: _formatDate(
                                _registeredDevice!['bound_at'],
                              ),
                            ),

                            const Divider(),

                            _infoRow(
                              icon: Icons.schedule_rounded,
                              title: 'Last Seen',
                              value: _formatDate(
                                _registeredDevice!['last_seen_at'],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 25),

                    if (!_hasRegisteredDevice)
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _bindDevice,
                          icon: const Icon(Icons.add_link_rounded),
                          label: _isProcessing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Bind This Device'),
                        ),
                      ),

                    if (_isCurrentDeviceBound)
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing ? null : _unbindDevice,
                          icon: const Icon(Icons.link_off_rounded),
                          label: const Text('Unbind Device'),
                        ),
                      ),

                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: Theme.of(context).colorScheme.surfaceContainer,
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.security_rounded, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'SafeZone allows one active device per '
                              'account to reduce unauthorised use of '
                              'emergency features.',
                              style: TextStyle(fontSize: 11),
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
        Icon(icon, size: 22),

        const SizedBox(width: 13),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11)),

              const SizedBox(height: 3),

              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
