import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/coordination_models.dart';
import '../services/device_binding_service.dart';
import '../services/emergency_coordination_service.dart';
import '../services/local_database_service.dart';
import '../services/location_service.dart';
import '../services/sos_service.dart';
import '../services/state_risk_service.dart';
import 'active_sos_screen.dart';
import 'help_support_screen.dart';
import 'insights_hub_screen.dart';
import 'login_screen.dart';
import 'nearby_sos_detail_screen.dart';
import 'personal_information_screen.dart';
import 'privacy_security_screen.dart';
import 'registered_device_screen.dart';
import 'sos_screen.dart';

part 'home_activity_section.dart';
part 'home_map_view.dart';
part 'home_models.dart';
part 'home_navigation_section.dart';
part 'home_nearby_section.dart';
part 'home_profile_section.dart';
part 'home_safety_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  final MapController _mapController = MapController();

  bool _mapReady = false;

  static const LatLng _defaultMapLocation = LatLng(3.1390, 101.6869);

  int _currentIndex = 0;

  bool _locationLoading = false;

  String _locationName = 'Detecting your location...';

  String _district = 'Getting your current safety area';

  double? _currentLatitude;

  double? _currentLongitude;

  SafeZoneLocationErrorType? _lastLocationErrorType;

  bool _riskAvailable = false;

  String _riskLevel = 'UNKNOWN';

  int _riskScore = 0;

  int _historicalCases = 0;

  double? _crimeRatePer100k;

  bool _setupLoading = true;

  String? _phoneNumber;

  bool _phoneVerified = false;

  bool _hasBoundDevice = false;

  List<_NearbyAlert> _nearbyAlerts = [];

  bool _activityLoading = true;

  List<Map<String, dynamic>> _activities = [];

  bool get _setupComplete {
    return _phoneVerified && _hasBoundDevice;
  }

  bool get _hasPhoneNumber {
    return _phoneNumber != null && _phoneNumber!.trim().isNotEmpty;
  }

  User? get _currentUser {
    return supabase.auth.currentUser;
  }

  String get _userName {
    final user = _currentUser;

    if (user == null) {
      return 'User';
    }

    final fullName = user.userMetadata?['full_name']?.toString().trim();

    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    final email = user.email;

    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'User';
  }

  String get _userEmail {
    return _currentUser?.email ?? 'No email available';
  }

  @override
  void initState() {
    super.initState();

    _initializeHome();
  }

  Future<void> _initializeHome() async {
    await _loadSetupStatus();

    if (!mounted) return;

    await _loadCurrentSafetyData();

    if (!mounted) return;

    await _loadNearbyAlerts();

    if (!mounted) return;

    await _loadActivities();
  }

  Future<void> _loadSetupStatus() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _phoneNumber = null;
        _phoneVerified = false;
        _hasBoundDevice = false;
        _setupLoading = false;
      });

      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('phone_number, phone_verified')
          .eq('id', user.id)
          .maybeSingle();

      final currentDeviceBound = await DeviceBindingService.instance
          .isCurrentDeviceBound();

      if (!mounted) return;

      setState(() {
        _phoneNumber = profile?['phone_number']?.toString();

        _phoneVerified = profile?['phone_verified'] == true;

        _hasBoundDevice = currentDeviceBound;

        _setupLoading = false;
      });
    } catch (e) {
      debugPrint('LOAD SAFETY SETUP ERROR: $e');

      if (!mounted) return;

      setState(() {
        _setupLoading = false;
      });
    }
  }

  Future<bool> _loadCurrentSafetyData({
    bool refreshRisk = false,
    bool showErrorSnackBar = false,
  }) async {
    if (_locationLoading) {
      return false;
    }

    setState(() {
      _locationLoading = true;
      _lastLocationErrorType = null;
    });

    try {
      final location = await LocationService.instance.getCurrentLocation();

      if (!mounted) {
        return false;
      }

      _currentLatitude = location.latitude;

      _currentLongitude = location.longitude;

      _moveMapToCurrentLocation();

      final stateName = location.state != null
          ? _shortStateName(location.state!)
          : null;

      final districtText =
          stateName != null &&
              location.district.toLowerCase() != stateName.toLowerCase()
          ? '${location.district} • '
                '$stateName'
          : location.district;

      if (location.state == null) {
        setState(() {
          _locationName = location.locationName;

          _district = districtText;

          _riskAvailable = false;

          _riskLevel = 'UNKNOWN';

          _riskScore = 0;

          _historicalCases = 0;

          _crimeRatePer100k = null;

          _locationLoading = false;
        });

        return false;
      }

      final risks = await StateRiskService.instance.loadStateRisks(
        refresh: refreshRisk,
      );

      if (!mounted) {
        return false;
      }

      final currentRisk = _findStateRisk(risks, location.state!);

      if (currentRisk == null) {
        setState(() {
          _locationName = location.locationName;

          _district = districtText;

          _riskAvailable = false;

          _riskLevel = 'UNKNOWN';

          _riskScore = 0;

          _historicalCases = 0;

          _crimeRatePer100k = null;

          _locationLoading = false;
        });

        return false;
      }

      setState(() {
        _locationName = location.locationName;

        _district = districtText;

        _riskAvailable = true;

        _riskLevel = currentRisk.riskLevel;

        _riskScore = currentRisk.riskScore;

        _historicalCases = currentRisk.totalCases;

        _crimeRatePer100k = currentRisk.crimeRatePer100k;

        _locationLoading = false;
      });

      return true;
    } on SafeZoneLocationException catch (e) {
      if (!mounted) {
        return false;
      }

      setState(() {
        _locationLoading = false;

        _lastLocationErrorType = e.type;

        _riskAvailable = false;

        _riskLevel = 'UNKNOWN';

        _riskScore = 0;

        _historicalCases = 0;

        _crimeRatePer100k = null;

        switch (e.type) {
          case SafeZoneLocationErrorType.serviceDisabled:
            _locationName = 'Location Disabled';

            _district =
                'Turn on GPS to view '
                'local safety information';

            break;

          case SafeZoneLocationErrorType.permissionDenied:
            _locationName = 'Location Permission Required';

            _district =
                'Allow location access '
                'to continue';

            break;

          case SafeZoneLocationErrorType.permissionDeniedForever:
            _locationName = 'Location Access Blocked';

            _district =
                'Enable permission from '
                'App Settings';

            break;

          case SafeZoneLocationErrorType.unableToGetLocation:
            _locationName = 'Location Unavailable';

            _district =
                'Unable to obtain '
                'GPS position';

            break;

          case SafeZoneLocationErrorType.unableToDetermineArea:
            _locationName = 'Area Unavailable';

            _district =
                'Unable to determine '
                'current area';

            break;
        }
      });

      if (showErrorSnackBar && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }

      return false;
    } catch (e) {
      debugPrint(
        'HOME LOCATION / '
        'RISK ERROR: $e',
      );

      if (!mounted) {
        return false;
      }

      setState(() {
        _locationLoading = false;
      });

      if (showErrorSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to update current '
              'safety information.',
            ),
          ),
        );
      }

      return false;
    }
  }

  Future<void> _loadNearbyAlerts({bool showErrorSnackBar = false}) async {
    try {
      final incidents = await EmergencyCoordinationService.instance
          .getNearbyIncidents();

      if (!mounted) return;

      setState(() {
        _nearbyAlerts = incidents
            .map((incident) => _NearbyAlert.fromIncident(incident))
            .toList();
      });
    } catch (e) {
      debugPrint('LOAD NEARBY ALERTS ERROR: $e');

      if (!mounted) return;

      setState(() {
        _nearbyAlerts = [];
      });

      if (showErrorSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to load nearby '
              'SOS alerts.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadActivities() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _activities = [];

        _activityLoading = false;
      });

      return;
    }

    if (mounted) {
      setState(() {
        _activityLoading = true;
      });
    }

    try {
      List<Map<String, dynamic>> localRows = <Map<String, dynamic>>[];

      List<Map<String, dynamic>> cloudRows = <Map<String, dynamic>>[];

      try {
        localRows = await LocalDatabaseService.instance.getActivities(user.id);
      } catch (e) {
        debugPrint(
          'LOAD LOCAL ACTIVITY '
          'ERROR: $e',
        );
      }

      try {
        final response = await supabase
            .from('sos_incidents')
            .select(
              'id, user_id, category, '
              'latitude, longitude, '
              'address, status, '
              'created_at, updated_at',
            )
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(50);

        cloudRows = response
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      } catch (e) {
        debugPrint(
          'LOAD CLOUD ACTIVITY '
          'ERROR: $e',
        );
      }

      final merged = <String, Map<String, dynamic>>{};

      for (final row in localRows.reversed) {
        final copy = Map<String, dynamic>.from(row);

        final key =
            '${copy['activity_type']}:'
            '${copy['incident_id'] ?? copy['id']}';

        merged[key] = copy;
      }

      for (final row in cloudRows) {
        final incidentId = row['id'].toString();

        final key = 'requested:$incidentId';

        merged[key] = {
          'id': 'cloud_$incidentId',
          'user_id': row['user_id'],
          'incident_id': incidentId,
          'activity_type': 'requested',
          'status': row['status'] ?? 'active',
          'title': _activityCategoryTitle(
            row['category']?.toString() ?? 'unsure',
          ),
          'location': row['address'],
          'latitude': row['latitude'],
          'longitude': row['longitude'],
          'created_at': row['created_at'],
          'updated_at': row['updated_at'],
          'synced': 1,
        };
      }

      final activities = merged.values.toList();

      activities.sort((first, second) {
        final firstDate =
            DateTime.tryParse(first['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);

        final secondDate =
            DateTime.tryParse(second['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);

        return secondDate.compareTo(firstDate);
      });

      if (!mounted) return;

      setState(() {
        _activities = activities;

        _activityLoading = false;
      });
    } catch (e) {
      debugPrint('LOAD ACTIVITY ERROR: $e');

      if (!mounted) return;

      setState(() {
        _activityLoading = false;
      });
    }
  }

  String _activityCategoryTitle(String category) {
    switch (category) {
      case 'medical':
        return 'Medical Emergency';

      case 'crime':
        return 'Crime / Personal Threat';

      case 'accident':
        return 'Accident';

      case 'fire_hazard':
        return 'Fire / Hazard';

      case 'other':
        return 'Other Emergency';

      case 'unsure':
      default:
        return 'Not Sure / Need Help';
    }
  }

  Future<void> _openActivity(Map<String, dynamic> activity) async {
    final activityType = activity['activity_type']?.toString();

    final status = activity['status']?.toString();

    final incidentId = activity['incident_id']?.toString();

    final active = status == 'active' || status == 'accepted';

    if (activityType != 'requested' ||
        !active ||
        incidentId == null ||
        incidentId.isEmpty) {
      return;
    }

    try {
      final incident = await SosService.instance.getIncident(incidentId);

      if (!mounted) return;

      if (incident == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This SOS could not '
              'be found.',
            ),
          ),
        );

        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ActiveSosScreen(incident: incident)),
      );

      if (!mounted) return;

      await _loadActivities();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  StateRiskData? _findStateRisk(List<StateRiskData> risks, String state) {
    for (final risk in risks) {
      if (risk.state == state) {
        return risk;
      }
    }

    return null;
  }

  LatLng get _currentMapLocation {
    if (_currentLatitude != null && _currentLongitude != null) {
      return LatLng(_currentLatitude!, _currentLongitude!);
    }

    return _defaultMapLocation;
  }

  void _moveMapToCurrentLocation() {
    if (!_mapReady || _currentLatitude == null || _currentLongitude == null) {
      return;
    }

    try {
      _mapController.move(LatLng(_currentLatitude!, _currentLongitude!), 16.5);
    } catch (e) {
      debugPrint('MOVE MAP ERROR: $e');
    }
  }

  Future<void> _refreshHome() async {
    await _loadSetupStatus();

    if (!mounted) return;

    final success = await _loadCurrentSafetyData(
      refreshRisk: true,
      showErrorSnackBar: true,
    );

    if (!mounted) return;

    await _loadNearbyAlerts(showErrorSnackBar: true);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location and safety '
            'information updated.',
          ),
        ),
      );
    }
  }

  Future<void> _onLocationAction() async {
    if (_lastLocationErrorType == SafeZoneLocationErrorType.serviceDisabled) {
      await LocationService.instance.openLocationSettings();

      return;
    }

    if (_lastLocationErrorType ==
        SafeZoneLocationErrorType.permissionDeniedForever) {
      await LocationService.instance.openAppSettings();

      return;
    }

    if (_currentLatitude != null && _currentLongitude != null) {
      _moveMapToCurrentLocation();

      return;
    }

    await _loadCurrentSafetyData(showErrorSnackBar: true);
  }

  Future<void> _openPersonalInformation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonalInformationScreen()),
    );

    if (!mounted) return;

    await _loadSetupStatus();
  }

  Future<void> _openRegisteredDevice() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisteredDeviceScreen()),
    );

    if (!mounted) return;

    await _loadSetupStatus();
  }

  void _openPrivacy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()),
    );
  }

  void _openHelp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
    );
  }

  Future<void> _startSOS() async {
    await _loadSetupStatus();

    if (!mounted) return;

    if (!_setupComplete) {
      await _showSetupRequiredDialog();

      return;
    }

    try {
      final existingIncident = await SosService.instance.getMyActiveSos();

      if (!mounted) return;

      if (existingIncident != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveSosScreen(incident: existingIncident),
          ),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SosScreen()),
        );
      }

      if (!mounted) return;

      await _loadActivities();

      if (!mounted) return;

      await _loadNearbyAlerts();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _showSetupRequiredDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.verified_user_outlined, size: 42),
          title: const Text('Complete Safety Setup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Complete the required '
                'safety checks before '
                'using SOS.',
              ),
              const SizedBox(height: 18),
              _setupDialogRow(
                title: 'Phone Verification',
                complete: _phoneVerified,
                subtitle: _phoneVerified
                    ? 'Phone number verified'
                    : !_hasPhoneNumber
                    ? 'Phone number has not been added'
                    : 'Phone number has not been verified',
              ),
              const SizedBox(height: 10),
              _setupDialogRow(
                title: 'Device Binding',
                complete: _hasBoundDevice,
                subtitle: _hasBoundDevice
                    ? 'Device binding completed'
                    : 'This account has no active bound device',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                if (!_phoneVerified) {
                  _openPersonalInformation();
                } else if (!_hasBoundDevice) {
                  _openRegisteredDevice();
                }
              },
              child: Text(!_phoneVerified ? 'Verify Phone' : 'Bind Device'),
            ),
          ],
        );
      },
    );
  }

  Widget _setupDialogRow({
    required String title,
    required String subtitle,
    required bool complete,
  }) {
    final color = complete ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _changeHomeTab(int index) {
    if (!mounted) {
      return;
    }

    if (_currentIndex == index) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeMapView(this)._buildMapHome(),
          const InsightsHubScreen(),
          _HomeActivitySection(this)._buildActivityPage(),
          _HomeProfileSection(this)._buildProfilePage(),
        ],
      ),
      floatingActionButton: _HomeNavigationSection(this)._buildSOSButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _HomeNavigationSection(
        this,
      )._buildBottomNavigationBar(),
    );
  }

  BoxDecoration _cardDecoration() {
    final scheme = Theme.of(context).colorScheme;

    return BoxDecoration(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: scheme.outlineVariant),
    );
  }

  Color _riskColor() {
    if (!_riskAvailable) {
      return Colors.grey;
    }

    switch (_riskLevel.toUpperCase()) {
      case 'VERY HIGH':
        return Colors.red.shade500;

      case 'HIGH':
        return Colors.orange.shade600;

      case 'MODERATE':
      case 'MEDIUM':
        return Colors.amber.shade600;

      case 'LOW':
        return Colors.green.shade500;

      default:
        return Colors.grey;
    }
  }

  String _riskDescription() {
    if (!_riskAvailable) {
      return 'Current risk information '
          'is unavailable until your '
          'Malaysian location can be '
          'identified.';
    }

    switch (_riskLevel.toUpperCase()) {
      case 'VERY HIGH':
        return 'Historical crime data '
            'indicates a significantly '
            'elevated population-adjusted '
            'risk compared with the '
            'Malaysia benchmark.';

      case 'HIGH':
        return 'Historical crime data '
            'indicates an elevated '
            'population-adjusted risk '
            'compared with the Malaysia '
            'benchmark.';

      case 'MODERATE':
      case 'MEDIUM':
        return 'Historical crime data '
            'indicates a moderate '
            'population-adjusted risk '
            'compared with the Malaysia '
            'benchmark.';

      case 'LOW':
      default:
        return 'Historical crime data '
            'indicates a comparatively '
            'lower population-adjusted '
            'risk compared with the '
            'Malaysia benchmark.';
    }
  }

  Color _alertColor(_NearbyAlertCategory category) {
    switch (category) {
      case _NearbyAlertCategory.sos:
        return Colors.red;

      case _NearbyAlertCategory.accident:
        return Colors.blue;

      case _NearbyAlertCategory.suspicious:
        return Colors.orange;

      case _NearbyAlertCategory.medical:
        return Colors.redAccent;

      case _NearbyAlertCategory.other:
        return Colors.deepPurple;
    }
  }

  IconData _alertIcon(_NearbyAlertCategory category) {
    switch (category) {
      case _NearbyAlertCategory.sos:
        return Icons.sos_rounded;

      case _NearbyAlertCategory.accident:
        return Icons.car_crash_outlined;

      case _NearbyAlertCategory.suspicious:
        return Icons.warning_amber_rounded;

      case _NearbyAlertCategory.medical:
        return Icons.medical_services_outlined;

      case _NearbyAlertCategory.other:
        return Icons.crisis_alert_rounded;
    }
  }

  String _shortStateName(String state) {
    switch (state) {
      case 'W.P. Kuala Lumpur':
        return 'Kuala Lumpur';

      case 'W.P. Putrajaya':
        return 'Putrajaya';

      case 'W.P. Labuan':
        return 'Labuan';

      default:
        return state;
    }
  }

  String _formatNumber(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }
}
