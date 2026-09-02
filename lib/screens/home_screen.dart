import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/location_service.dart';
import '../services/state_risk_service.dart';

import 'help_support_screen.dart';
import 'insights_hub_screen.dart';
import 'login_screen.dart';
import 'personal_information_screen.dart';
import 'privacy_security_screen.dart';
import 'registered_device_screen.dart';
import 'sos_screen.dart';

// ============================================================
// HOME SCREEN
//
// NEW HOME DESIGN:
//
// Full-screen live map
// +
// floating header
// +
// draggable safety information panel
// +
// center SOS button
// +
// persistent bottom navigation
//
// Existing LocationService / StateRiskService are reused.
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient supabase =
      Supabase.instance.client;

  // ============================================================
  // MAP
  // ============================================================

  final MapController _mapController =
  MapController();

  bool _mapReady = false;

  // Default map location before GPS is available.
  static const LatLng _defaultMapLocation =
  LatLng(
    3.1390,
    101.6869,
  );

  // ============================================================
  // BOTTOM NAVIGATION
  //
  // 0 Home
  // 1 Insights
  // 2 Activity
  // 3 Profile
  // ============================================================

  int _currentIndex = 0;

  // ============================================================
  // CURRENT LOCATION
  // ============================================================

  bool _locationLoading = false;

  String _locationName =
      'Detecting your location...';

  String _district =
      'Getting your current safety area';

  String? _currentState;

  double? _currentLatitude;
  double? _currentLongitude;

  SafeZoneLocationErrorType?
  _lastLocationErrorType;

  // ============================================================
  // CURRENT RISK
  // ============================================================

  bool _riskAvailable = false;

  String _riskLevel =
      'UNKNOWN';

  int _riskScore = 0;

  int _historicalCases = 0;

  double? _crimeRatePer100k;

  // ============================================================
  // SAFETY SETUP
  //
  // IMPORTANT:
  //
  // SOS requires:
  //
  // 1. Phone verified
  // 2. Device binding completed
  // ============================================================

  bool _setupLoading = true;

  String? _phoneNumber;

  bool _phoneVerified = false;

  bool _hasBoundDevice = false;

  bool get _setupComplete =>
      _phoneVerified &&
          _hasBoundDevice;

  bool get _hasPhoneNumber =>
      _phoneNumber != null &&
          _phoneNumber!
              .trim()
              .isNotEmpty;

  // ============================================================
  // NEARBY ALERTS
  //
  // Backend will be connected later.
  //
  // Keep this empty now so the app does NOT display fake
  // emergencies.
  //
  // Once Supabase nearby incident query is ready, populate
  // this list.
  // ============================================================

  List<_NearbyAlert> _nearbyAlerts = [];

  // ============================================================
  // USER
  // ============================================================

  User? get _currentUser =>
      supabase.auth.currentUser;

  String get _userName {
    final user =
        _currentUser;

    if (user == null) {
      return 'User';
    }

    final fullName =
    user.userMetadata?['full_name']
        ?.toString()
        .trim();

    if (fullName != null &&
        fullName.isNotEmpty) {
      return fullName;
    }

    final email =
        user.email;

    if (email != null &&
        email.isNotEmpty) {
      return email
          .split('@')
          .first;
    }

    return 'User';
  }

  String get _userEmail =>
      _currentUser?.email ??
          'No email available';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _initializeHome();
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> _initializeHome() async {
    await _loadSetupStatus();

    if (!mounted) return;

    await _loadCurrentSafetyData();
  }

  // ============================================================
  // LOAD SAFETY SETUP STATUS
  // ============================================================

  Future<void> _loadSetupStatus() async {
    final user =
        supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _setupLoading = false;
      });

      return;
    }

    try {
      // ========================================================
      // PROFILE
      //
      // We intentionally check phone_verified,
      // not just phone_number.
      // ========================================================

      final profile =
      await supabase
          .from('profiles')
          .select(
        'phone_number, phone_verified',
      )
          .eq(
        'id',
        user.id,
      )
          .maybeSingle();

      // ========================================================
      // DEVICE
      // ========================================================

      final device =
      await supabase
          .from('user_devices')
          .select(
        'id',
      )
          .eq(
        'user_id',
        user.id,
      )
          .eq(
        'is_active',
        true,
      )
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _phoneNumber =
            profile?['phone_number']
                ?.toString();

        _phoneVerified =
            profile?['phone_verified'] ==
                true;

        _hasBoundDevice =
            device != null;

        _setupLoading =
        false;
      });
    } catch (e) {
      debugPrint(
        'LOAD SAFETY SETUP ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _setupLoading =
        false;
      });
    }
  }

  // ============================================================
  // LOAD CURRENT GPS + RISK
  // ============================================================

  Future<bool> _loadCurrentSafetyData({
    bool refreshRisk = false,
    bool showErrorSnackBar = false,
  }) async {
    if (_locationLoading) {
      return false;
    }

    setState(() {
      _locationLoading =
      true;

      _lastLocationErrorType =
      null;
    });

    try {
      // ========================================================
      // LOCATION
      // ========================================================

      final location =
      await LocationService.instance
          .getCurrentLocation();

      if (!mounted) {
        return false;
      }

      _currentLatitude =
          location.latitude;

      _currentLongitude =
          location.longitude;

      _currentState =
          location.state;

      // ========================================================
      // MOVE MAP
      // ========================================================

      _moveMapToCurrentLocation();

      final stateName =
      location.state != null
          ? _shortStateName(
        location.state!,
      )
          : null;

      final districtText =
      stateName != null &&
          location.district
              .toLowerCase() !=
              stateName
                  .toLowerCase()
          ? '${location.district} • $stateName'
          : location.district;

      // ========================================================
      // GPS WORKS BUT MALAYSIA STATE NOT IDENTIFIED
      // ========================================================

      if (location.state == null) {
        setState(() {
          _locationName =
              location.locationName;

          _district =
              districtText;

          _riskAvailable =
          false;

          _riskLevel =
          'UNKNOWN';

          _riskScore =
          0;

          _historicalCases =
          0;

          _crimeRatePer100k =
          null;

          _locationLoading =
          false;
        });

        return false;
      }

      // ========================================================
      // LOAD STATE RISK
      // ========================================================

      final risks =
      await StateRiskService.instance
          .loadStateRisks(
        refresh:
        refreshRisk,
      );

      if (!mounted) {
        return false;
      }

      final currentRisk =
      _findStateRisk(
        risks,
        location.state!,
      );

      // ========================================================
      // RISK NOT FOUND
      // ========================================================

      if (currentRisk == null) {
        setState(() {
          _locationName =
              location.locationName;

          _district =
              districtText;

          _riskAvailable =
          false;

          _riskLevel =
          'UNKNOWN';

          _riskScore =
          0;

          _historicalCases =
          0;

          _crimeRatePer100k =
          null;

          _locationLoading =
          false;
        });

        return false;
      }

      // ========================================================
      // SUCCESS
      // ========================================================

      setState(() {
        _locationName =
            location.locationName;

        _district =
            districtText;

        _currentState =
            location.state;

        _riskAvailable =
        true;

        _riskLevel =
            currentRisk.riskLevel;

        _riskScore =
            currentRisk.riskScore;

        _historicalCases =
            currentRisk.totalCases;

        _crimeRatePer100k =
            currentRisk.crimeRatePer100k;

        _locationLoading =
        false;
      });

      return true;
    }

    // ==========================================================
    // LOCATION ERROR
    // ==========================================================

    on SafeZoneLocationException catch (e) {
      if (!mounted) {
        return false;
      }

      setState(() {
        _locationLoading =
        false;

        _lastLocationErrorType =
            e.type;

        _riskAvailable =
        false;

        _riskLevel =
        'UNKNOWN';

        _riskScore =
        0;

        _historicalCases =
        0;

        _crimeRatePer100k =
        null;

        switch (e.type) {
          case SafeZoneLocationErrorType
              .serviceDisabled:
            _locationName =
            'Location Disabled';

            _district =
            'Turn on GPS to view local safety information';

            break;

          case SafeZoneLocationErrorType
              .permissionDenied:
            _locationName =
            'Location Permission Required';

            _district =
            'Allow location access to continue';

            break;

          case SafeZoneLocationErrorType
              .permissionDeniedForever:
            _locationName =
            'Location Access Blocked';

            _district =
            'Enable permission from App Settings';

            break;

          case SafeZoneLocationErrorType
              .unableToGetLocation:
            _locationName =
            'Location Unavailable';

            _district =
            'Unable to obtain GPS position';

            break;

          case SafeZoneLocationErrorType
              .unableToDetermineArea:
            _locationName =
            'Area Unavailable';

            _district =
            'Unable to determine current area';

            break;
        }
      });

      if (showErrorSnackBar &&
          mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content:
            Text(
              e.message,
            ),
          ),
        );
      }

      return false;
    } catch (e) {
      debugPrint(
        'HOME LOCATION / RISK ERROR: $e',
      );

      if (!mounted) {
        return false;
      }

      setState(() {
        _locationLoading =
        false;
      });

      if (showErrorSnackBar) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to update current safety information.',
            ),
          ),
        );
      }

      return false;
    }
  }

  // ============================================================
  // FIND RISK
  // ============================================================

  StateRiskData? _findStateRisk(
      List<StateRiskData> risks,
      String state,
      ) {
    for (final risk in risks) {
      if (risk.state == state) {
        return risk;
      }
    }

    return null;
  }

  // ============================================================
  // MAP LOCATION
  // ============================================================

  LatLng get _currentMapLocation {
    if (_currentLatitude != null &&
        _currentLongitude != null) {
      return LatLng(
        _currentLatitude!,
        _currentLongitude!,
      );
    }

    return _defaultMapLocation;
  }

  // ============================================================
  // MOVE MAP TO CURRENT LOCATION
  // ============================================================

  void _moveMapToCurrentLocation() {
    if (!_mapReady ||
        _currentLatitude == null ||
        _currentLongitude == null) {
      return;
    }

    try {
      _mapController.move(
        LatLng(
          _currentLatitude!,
          _currentLongitude!,
        ),
        16.5,
      );
    } catch (e) {
      debugPrint(
        'MOVE MAP ERROR: $e',
      );
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refreshHome() async {
    await _loadSetupStatus();

    if (!mounted) return;

    final success =
    await _loadCurrentSafetyData(
      refreshRisk:
      true,
      showErrorSnackBar:
      true,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Location and safety information updated.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // LOCATION ACTION
  // ============================================================

  Future<void> _onLocationAction() async {
    if (_lastLocationErrorType ==
        SafeZoneLocationErrorType
            .serviceDisabled) {
      await LocationService.instance
          .openLocationSettings();

      return;
    }

    if (_lastLocationErrorType ==
        SafeZoneLocationErrorType
            .permissionDeniedForever) {
      await LocationService.instance
          .openAppSettings();

      return;
    }

    if (_currentLatitude != null &&
        _currentLongitude != null) {
      _moveMapToCurrentLocation();

      return;
    }

    await _loadCurrentSafetyData(
      showErrorSnackBar:
      true,
    );
  }

  // ============================================================
  // PERSONAL INFORMATION
  // ============================================================

  Future<void>
  _openPersonalInformation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const PersonalInformationScreen(),
      ),
    );

    if (!mounted) return;

    await _loadSetupStatus();
  }

  // ============================================================
  // REGISTERED DEVICE
  // ============================================================

  Future<void>
  _openRegisteredDevice() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const RegisteredDeviceScreen(),
      ),
    );

    if (!mounted) return;

    await _loadSetupStatus();
  }

  // ============================================================
  // PRIVACY
  // ============================================================

  void _openPrivacy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const PrivacySecurityScreen(),
      ),
    );
  }

  // ============================================================
  // HELP
  // ============================================================

  void _openHelp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const HelpSupportScreen(),
      ),
    );
  }

  // ============================================================
  // SOS
  //
  // IMPORTANT:
  //
  // Re-check phone verification + device binding before
  // allowing the SOS screen.
  // ============================================================

  Future<void> _startSOS() async {
    await _loadSetupStatus();

    if (!mounted) return;

    // ==========================================================
    // SETUP INCOMPLETE
    // ==========================================================

    if (!_setupComplete) {
      await _showSetupRequiredDialog();

      return;
    }

    // ==========================================================
    // SETUP COMPLETE
    // ==========================================================

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const SosScreen(),
      ),
    );
  }

  // ============================================================
  // SETUP REQUIRED DIALOG
  // ============================================================

  Future<void>
  _showSetupRequiredDialog() async {
    await showDialog(
      context:
      context,
      builder: (
          dialogContext,
          ) {
        return AlertDialog(
          icon:
          const Icon(
            Icons
                .verified_user_outlined,
            size: 42,
          ),

          title:
          const Text(
            'Complete Safety Setup',
          ),

          content:
          Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              const Text(
                'Complete the required safety checks before using SOS.',
              ),

              const SizedBox(
                height: 18,
              ),

              _setupDialogRow(
                title:
                'Phone Verification',
                complete:
                _phoneVerified,
                subtitle:
                _phoneVerified
                    ? 'Phone number verified'
                    : !_hasPhoneNumber
                    ? 'Phone number has not been added'
                    : 'Phone number has not been verified',
              ),

              const SizedBox(
                height: 10,
              ),

              _setupDialogRow(
                title:
                'Device Binding',
                complete:
                _hasBoundDevice,
                subtitle:
                _hasBoundDevice
                    ? 'Device binding completed'
                    : 'This account has no active bound device',
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
              const Text(
                'Later',
              ),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );

                if (!_phoneVerified) {
                  _openPersonalInformation();
                } else if (!_hasBoundDevice) {
                  _openRegisteredDevice();
                }
              },
              child:
              Text(
                !_phoneVerified
                    ? 'Verify Phone'
                    : 'Bind Device',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SETUP DIALOG ROW
  // ============================================================

  Widget _setupDialogRow({
    required String title,
    required String subtitle,
    required bool complete,
  }) {
    final color =
    complete
        ? Colors.green
        : Colors.orange;

    return Container(
      padding:
      const EdgeInsets.all(
        12,
      ),
      decoration:
      BoxDecoration(
        borderRadius:
        BorderRadius.circular(
          14,
        ),
        color:
        color.withOpacity(
          0.08,
        ),
        border:
        Border.all(
          color:
          color.withOpacity(
            0.20,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            complete
                ? Icons
                .check_circle_rounded
                : Icons
                .error_outline_rounded,
            color:
            color,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  subtitle,
                  style:
                  const TextStyle(
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const LoginScreen(),
      ),
          (
          route,
          ) =>
      false,
    );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      // ========================================================
      // BODY
      // ========================================================

      body:
      IndexedStack(
        index:
        _currentIndex,
        children: [
          // ====================================================
          // HOME
          // ====================================================

          _buildMapHome(),

          // ====================================================
          // INSIGHTS
          // ====================================================

          const InsightsHubScreen(),

          // ====================================================
          // ACTIVITY
          // ====================================================

          _buildActivityPage(),

          // ====================================================
          // PROFILE
          // ====================================================

          _buildProfilePage(),
        ],
      ),

      // ========================================================
      // CENTER SOS
      // ========================================================

      floatingActionButton:
      _buildSOSButton(),

      floatingActionButtonLocation:
      FloatingActionButtonLocation
          .centerDocked,

      // ========================================================
      // BOTTOM BAR
      // ========================================================

      bottomNavigationBar:
      _buildBottomNavigationBar(),
    );
  }

  // ============================================================
  // HOME MAP
  // ============================================================

  Widget _buildMapHome() {
    return Stack(
      children: [
        // ======================================================
        // REAL MAP
        // ======================================================

        Positioned.fill(
          child:
          FlutterMap(
            mapController:
            _mapController,

            options:
            MapOptions(
              initialCenter:
              _currentMapLocation,

              initialZoom:
              16,

              onMapReady: () {
                _mapReady =
                true;

                _moveMapToCurrentLocation();
              },
            ),

            children: [
              // =================================================
              // OPENSTREETMAP
              // =================================================

              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

                userAgentPackageName:
                'com.example.safezone_my',
              ),

              // =================================================
              // MARKERS
              // =================================================

              MarkerLayer(
                markers:
                _buildMapMarkers(),
              ),
            ],
          ),
        ),

        // ======================================================
        // DARK MAP TOP FADE
        // ======================================================

        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 125,
          child:
          IgnorePointer(
            child:
            Container(
              decoration:
              BoxDecoration(
                gradient:
                LinearGradient(
                  begin:
                  Alignment.topCenter,
                  end:
                  Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(
                      0.48,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // ======================================================
        // HEADER
        // ======================================================

        _buildFloatingHeader(),

        // ======================================================
        // MAP CONTROLS
        // ======================================================

        Positioned(
          right: 16,
          top:
          MediaQuery.of(context)
              .padding
              .top +
              88,
          child:
          _buildMapControls(),
        ),

        // ======================================================
        // OSM ATTRIBUTION
        // ======================================================

        Positioned(
          left: 12,
          top:
          MediaQuery.of(context)
              .padding
              .top +
              98,
          child:
          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 4,
            ),
            decoration:
            BoxDecoration(
              color:
              Colors.black.withOpacity(
                0.50,
              ),
              borderRadius:
              BorderRadius.circular(
                6,
              ),
            ),
            child:
            const Text(
              '© OpenStreetMap contributors',
              style:
              TextStyle(
                color:
                Colors.white,
                fontSize: 7,
              ),
            ),
          ),
        ),

        // ======================================================
        // DRAGGABLE SAFETY PANEL
        // ======================================================

        _buildSafetySheet(),
      ],
    );
  }

  // ============================================================
  // FLOATING HEADER
  // ============================================================

  Widget _buildFloatingHeader() {
    final scheme =
        Theme.of(context)
            .colorScheme;

    return Positioned(
      top:
      MediaQuery.of(context)
          .padding
          .top +
          10,
      left: 14,
      right: 14,
      child:
      Container(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration:
        BoxDecoration(
          color:
          scheme.surface.withOpacity(
            0.92,
          ),
          borderRadius:
          BorderRadius.circular(
            18,
          ),
          border:
          Border.all(
            color:
            scheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color:
              Colors.black.withOpacity(
                0.12,
              ),
              blurRadius:
              16,
              offset:
              const Offset(
                0,
                5,
              ),
            ),
          ],
        ),
        child:
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration:
              BoxDecoration(
                borderRadius:
                BorderRadius.circular(
                  13,
                ),
                color:
                scheme.primary.withOpacity(
                  0.15,
                ),
              ),
              child:
              Icon(
                Icons
                    .shield_rounded,
                color:
                scheme.primary,
                size:
                22,
              ),
            ),

            const SizedBox(
              width: 11,
            ),

            Expanded(
              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $_userName',
                    maxLines:
                    1,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    const TextStyle(
                      fontSize:
                      17,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 1,
                  ),

                  const Text(
                    'Stay aware. Stay safe.',
                    style:
                    TextStyle(
                      fontSize:
                      10,
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // REFRESH
            // ==================================================

            IconButton(
              tooltip:
              'Refresh location',
              onPressed:
              _locationLoading
                  ? null
                  : _refreshHome,
              icon:
              _locationLoading
                  ? const SizedBox(
                width:
                18,
                height:
                18,
                child:
                CircularProgressIndicator(
                  strokeWidth:
                  2,
                ),
              )
                  : const Icon(
                Icons
                    .refresh_rounded,
              ),
            ),

            // ==================================================
            // NOTIFICATION
            // ==================================================

            IconButton(
              tooltip:
              'Nearby alerts',
              onPressed:
              _showNearbyAlerts,
              icon:
              Badge(
                isLabelVisible:
                _nearbyAlerts
                    .isNotEmpty,
                label:
                _nearbyAlerts.isNotEmpty
                    ? Text(
                  '${_nearbyAlerts.length}',
                )
                    : null,
                child:
                const Icon(
                  Icons
                      .notifications_none_rounded,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MAP CONTROLS
  // ============================================================

  Widget _buildMapControls() {
    final scheme =
        Theme.of(context)
            .colorScheme;

    return Column(
      children: [
        // ======================================================
        // RECENTER
        // ======================================================

        _mapControlButton(
          icon:
          Icons
              .my_location_rounded,
          tooltip:
          'My location',
          onTap:
          _onLocationAction,
        ),

        const SizedBox(
          height: 10,
        ),

        // ======================================================
        // ALERTS
        // ======================================================

        Material(
          color:
          scheme.surface.withOpacity(
            0.94,
          ),
          borderRadius:
          BorderRadius.circular(
            15,
          ),
          child:
          InkWell(
            borderRadius:
            BorderRadius.circular(
              15,
            ),
            onTap:
            _showNearbyAlerts,
            child:
            Container(
              width: 46,
              height: 46,
              alignment:
              Alignment.center,
              decoration:
              BoxDecoration(
                border:
                Border.all(
                  color:
                  scheme.outlineVariant,
                ),
                borderRadius:
                BorderRadius.circular(
                  15,
                ),
              ),
              child:
              Badge(
                isLabelVisible:
                _nearbyAlerts
                    .isNotEmpty,
                label:
                _nearbyAlerts.isNotEmpty
                    ? Text(
                  '${_nearbyAlerts.length}',
                )
                    : null,
                child:
                const Icon(
                  Icons
                      .crisis_alert_outlined,
                  size:
                  21,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MAP CONTROL BUTTON
  // ============================================================

  Widget _mapControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final scheme =
        Theme.of(context)
            .colorScheme;

    return Tooltip(
      message:
      tooltip,
      child:
      Material(
        color:
        scheme.surface.withOpacity(
          0.94,
        ),
        borderRadius:
        BorderRadius.circular(
          15,
        ),
        child:
        InkWell(
          borderRadius:
          BorderRadius.circular(
            15,
          ),
          onTap:
          onTap,
          child:
          Container(
            width: 46,
            height: 46,
            decoration:
            BoxDecoration(
              border:
              Border.all(
                color:
                scheme.outlineVariant,
              ),
              borderRadius:
              BorderRadius.circular(
                15,
              ),
            ),
            child:
            Icon(
              icon,
              size:
              21,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MAP MARKERS
  // ============================================================

  List<Marker> _buildMapMarkers() {
    final markers =
    <Marker>[];

    // ==========================================================
    // USER MARKER
    // ==========================================================

    if (_currentLatitude != null &&
        _currentLongitude != null) {
      markers.add(
        Marker(
          point:
          LatLng(
            _currentLatitude!,
            _currentLongitude!,
          ),
          width:
          54,
          height:
          54,
          child:
          _buildUserMarker(),
        ),
      );
    }

    // ==========================================================
    // NEARBY ALERT MARKERS
    // ==========================================================

    for (final alert
    in _nearbyAlerts) {
      markers.add(
        Marker(
          point:
          LatLng(
            alert.latitude,
            alert.longitude,
          ),
          width:
          48,
          height:
          48,
          child:
          GestureDetector(
            onTap: () =>
                _showAlertDetails(
                  alert,
                ),
            child:
            _buildAlertMarker(
              alert,
            ),
          ),
        ),
      );
    }

    return markers;
  }

  // ============================================================
  // USER MARKER
  // ============================================================

  Widget _buildUserMarker() {
    return Container(
      decoration:
      BoxDecoration(
        shape:
        BoxShape.circle,
        color:
        Colors.blue.withOpacity(
          0.18,
        ),
      ),
      alignment:
      Alignment.center,
      child:
      Container(
        width: 29,
        height: 29,
        decoration:
        BoxDecoration(
          shape:
          BoxShape.circle,
          color:
          Colors.blue,
          border:
          Border.all(
            color:
            Colors.white,
            width:
            3,
          ),
          boxShadow: [
            BoxShadow(
              color:
              Colors.blue.withOpacity(
                0.5,
              ),
              blurRadius:
              12,
              spreadRadius:
              2,
            ),
          ],
        ),
        child:
        const Icon(
          Icons
              .navigation_rounded,
          color:
          Colors.white,
          size:
          15,
        ),
      ),
    );
  }

  // ============================================================
  // ALERT MARKER
  // ============================================================

  Widget _buildAlertMarker(
      _NearbyAlert alert,
      ) {
    final color =
    _alertColor(
      alert.category,
    );

    return Container(
      decoration:
      BoxDecoration(
        shape:
        BoxShape.circle,
        color:
        color.withOpacity(
          0.18,
        ),
      ),
      alignment:
      Alignment.center,
      child:
      Container(
        width: 31,
        height: 31,
        decoration:
        BoxDecoration(
          shape:
          BoxShape.circle,
          color:
          color,
          border:
          Border.all(
            color:
            Colors.white,
            width:
            2,
          ),
        ),
        child:
        Icon(
          _alertIcon(
            alert.category,
          ),
          color:
          Colors.white,
          size:
          16,
        ),
      ),
    );
  }

  // ============================================================
  // DRAGGABLE SAFETY SHEET
  // ============================================================

  Widget _buildSafetySheet() {
    final scheme =
        Theme.of(context)
            .colorScheme;

    return DraggableScrollableSheet(
      initialChildSize:
      0.30,

      minChildSize:
      0.20,

      maxChildSize:
      0.78,

      snap:
      true,

      snapSizes:
      const [
        0.20,
        0.30,
        0.78,
      ],

      builder: (
          context,
          scrollController,
          ) {
        return Container(
          decoration:
          BoxDecoration(
            color:
            scheme.surface,
            borderRadius:
            const BorderRadius.vertical(
              top:
              Radius.circular(
                26,
              ),
            ),
            border:
            Border(
              top:
              BorderSide(
                color:
                scheme.outlineVariant,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color:
                Colors.black.withOpacity(
                  0.20,
                ),
                blurRadius:
                24,
                offset:
                const Offset(
                  0,
                  -6,
                ),
              ),
            ],
          ),
          child:
          ListView(
            controller:
            scrollController,
            padding:
            const EdgeInsets.fromLTRB(
              18,
              8,
              18,
              24,
            ),
            children: [
              // =================================================
              // HANDLE
              // =================================================

              Center(
                child:
                Container(
                  width: 42,
                  height: 4,
                  decoration:
                  BoxDecoration(
                    color:
                    scheme.onSurfaceVariant
                        .withOpacity(
                      0.32,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      20,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              // =================================================
              // LOCATION
              // =================================================

              _buildSheetLocationHeader(),

              const SizedBox(
                height: 15,
              ),

              // =================================================
              // RISK
              // =================================================

              _buildCompactRiskCard(),

              // =================================================
              // SETUP STATUS
              // =================================================

              if (!_setupLoading &&
                  !_setupComplete) ...[
                const SizedBox(
                  height: 12,
                ),

                _buildSetupStatusCard(),
              ],

              const SizedBox(
                height: 12,
              ),

              // =================================================
              // NEARBY ALERTS
              // =================================================

              _buildNearbyAlertButton(),

              const SizedBox(
                height: 20,
              ),

              // =================================================
              // EXPANDED INFORMATION
              // =================================================

              _sheetSectionTitle(
                'Safety Details',
              ),

              const SizedBox(
                height: 10,
              ),

              _buildDetailedRiskStats(),

              const SizedBox(
                height: 14,
              ),

              _buildRiskDescriptionCard(),

              const SizedBox(
                height: 22,
              ),

              _sheetSectionTitle(
                'Nearby Alerts',
              ),

              const SizedBox(
                height: 10,
              ),

              _buildNearbyAlertsPreview(),

              const SizedBox(
                height: 24,
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // SHEET LOCATION HEADER
  // ============================================================

  Widget _buildSheetLocationHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration:
          BoxDecoration(
            shape:
            BoxShape.circle,
            color:
            Colors.blue.withOpacity(
              0.12,
            ),
          ),
          child:
          _locationLoading
              ? const Padding(
            padding:
            EdgeInsets.all(
              12,
            ),
            child:
            CircularProgressIndicator(
              strokeWidth:
              2,
            ),
          )
              : const Icon(
            Icons
                .my_location_rounded,
            color:
            Colors.blue,
            size:
            21,
          ),
        ),

        const SizedBox(
          width: 11,
        ),

        Expanded(
          child:
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                _locationName,
                maxLines:
                1,
                overflow:
                TextOverflow.ellipsis,
                style:
                const TextStyle(
                  fontSize:
                  15,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: 2,
              ),

              Text(
                _district,
                maxLines:
                1,
                overflow:
                TextOverflow.ellipsis,
                style:
                const TextStyle(
                  fontSize:
                  9.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          width: 8,
        ),

        IconButton(
          tooltip:
          'Locate me',
          onPressed:
          _onLocationAction,
          icon:
          const Icon(
            Icons.gps_fixed_rounded,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // COMPACT RISK CARD
  // ============================================================

  Widget _buildCompactRiskCard() {
    final riskColor =
    _riskColor();

    return Container(
      padding:
      const EdgeInsets.all(
        14,
      ),
      decoration:
      _cardDecoration(),
      child:
      Column(
        children: [
          Row(
            children: [
              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Risk',
                      style:
                      TextStyle(
                        fontSize:
                        9,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration:
                          BoxDecoration(
                            shape:
                            BoxShape.circle,
                            color:
                            riskColor,
                          ),
                        ),

                        const SizedBox(
                          width: 7,
                        ),

                        Text(
                          _riskLevel,
                          style:
                          TextStyle(
                            fontSize:
                            19,
                            fontWeight:
                            FontWeight.bold,
                            color:
                            riskColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment:
                CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Risk Score',
                    style:
                    TextStyle(
                      fontSize:
                      9,
                    ),
                  ),

                  const SizedBox(
                    height: 3,
                  ),

                  Text(
                    _riskAvailable
                        ? '$_riskScore / 100'
                        : '-- / 100',
                    style:
                    const TextStyle(
                      fontSize:
                      18,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(
            height: 11,
          ),

          ClipRRect(
            borderRadius:
            BorderRadius.circular(
              20,
            ),
            child:
            LinearProgressIndicator(
              value:
              _riskAvailable
                  ? _riskScore /
                  100
                  : 0,
              minHeight:
              6,
              color:
              riskColor,
              backgroundColor:
              riskColor.withOpacity(
                0.10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SETUP STATUS CARD
  //
  // Shows EXACTLY which requirement is incomplete.
  // ============================================================

  Widget _buildSetupStatusCard() {
    return Container(
      padding:
      const EdgeInsets.all(
        14,
      ),
      decoration:
      BoxDecoration(
        color:
        Colors.orange.withOpacity(
          0.07,
        ),
        borderRadius:
        BorderRadius.circular(
          17,
        ),
        border:
        Border.all(
          color:
          Colors.orange.withOpacity(
            0.25,
          ),
        ),
      ),
      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons
                    .verified_user_outlined,
                color:
                Colors.orange,
                size:
                19,
              ),

              SizedBox(
                width: 8,
              ),

              Expanded(
                child: Text(
                  'Safety Setup Incomplete',
                  style:
                  TextStyle(
                    fontSize:
                    12,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 5,
          ),

          const Text(
            'Complete the required items before using SOS.',
            style:
            TextStyle(
              fontSize:
              9,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          // ====================================================
          // PHONE VERIFICATION
          // ====================================================

          _setupStatusRow(
            icon:
            Icons.phone_android_rounded,

            title:
            'Phone Verification',

            subtitle:
            _phoneVerified
                ? 'Verified'
                : !_hasPhoneNumber
                ? 'Phone number required'
                : 'Verification required',

            complete:
            _phoneVerified,

            onFix:
            _phoneVerified
                ? null
                : _openPersonalInformation,
          ),

          const SizedBox(
            height: 9,
          ),

          // ====================================================
          // DEVICE BINDING
          // ====================================================

          _setupStatusRow(
            icon:
            Icons.devices_rounded,

            title:
            'Device Binding',

            subtitle:
            _hasBoundDevice
                ? 'Completed'
                : 'Device binding required',

            complete:
            _hasBoundDevice,

            onFix:
            _hasBoundDevice
                ? null
                : _openRegisteredDevice,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SETUP STATUS ROW
  // ============================================================

  Widget _setupStatusRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool complete,
    required VoidCallback? onFix,
  }) {
    final color =
    complete
        ? Colors.green
        : Colors.orange;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration:
          BoxDecoration(
            borderRadius:
            BorderRadius.circular(
              10,
            ),
            color:
            color.withOpacity(
              0.10,
            ),
          ),
          child:
          Icon(
            complete
                ? Icons
                .check_rounded
                : icon,
            color:
            color,
            size:
            18,
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        Expanded(
          child:
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                const TextStyle(
                  fontSize:
                  10.5,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),

              Text(
                subtitle,
                style:
                TextStyle(
                  fontSize:
                  8.5,
                  color:
                  color,
                ),
              ),
            ],
          ),
        ),

        if (!complete &&
            onFix != null)
          TextButton(
            onPressed:
            onFix,
            child:
            const Text(
              'Fix',
            ),
          ),
      ],
    );
  }

  // ============================================================
  // NEARBY ALERT BUTTON
  // ============================================================

  Widget _buildNearbyAlertButton() {
    final hasAlerts =
        _nearbyAlerts.isNotEmpty;

    final color =
    hasAlerts
        ? Colors.orange
        : Colors.green;

    return Material(
      color:
      Colors.transparent,
      child:
      InkWell(
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        onTap:
        _showNearbyAlerts,
        child:
        Container(
          padding:
          const EdgeInsets.all(
            13,
          ),
          decoration:
          BoxDecoration(
            borderRadius:
            BorderRadius.circular(
              16,
            ),
            color:
            color.withOpacity(
              0.07,
            ),
            border:
            Border.all(
              color:
              color.withOpacity(
                0.18,
              ),
            ),
          ),
          child:
          Row(
            children: [
              Container(
                width: 37,
                height: 37,
                decoration:
                BoxDecoration(
                  shape:
                  BoxShape.circle,
                  color:
                  color.withOpacity(
                    0.12,
                  ),
                ),
                child:
                Icon(
                  hasAlerts
                      ? Icons
                      .crisis_alert_rounded
                      : Icons
                      .check_circle_outline_rounded,
                  color:
                  color,
                  size:
                  20,
                ),
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasAlerts
                          ? 'Nearby Alerts'
                          : 'All Clear Nearby',
                      style:
                      const TextStyle(
                        fontSize:
                        11.5,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 2,
                    ),

                    Text(
                      hasAlerts
                          ? '${_nearbyAlerts.length} active alert${_nearbyAlerts.length == 1 ? '' : 's'} within your nearby area'
                          : 'No active SafeZone incidents nearby',
                      style:
                      const TextStyle(
                        fontSize:
                        8.5,
                      ),
                    ),
                  ],
                ),
              ),

              if (hasAlerts)
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 27,
                  ),
                  height:
                  27,
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal:
                    7,
                  ),
                  alignment:
                  Alignment.center,
                  decoration:
                  BoxDecoration(
                    color:
                    Colors.orange,
                    borderRadius:
                    BorderRadius.circular(
                      20,
                    ),
                  ),
                  child:
                  Text(
                    '${_nearbyAlerts.length}',
                    style:
                    const TextStyle(
                      color:
                      Colors.white,
                      fontSize:
                      10,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),

              const SizedBox(
                width: 5,
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DETAILED RISK STATS
  // ============================================================

  Widget _buildDetailedRiskStats() {
    return Row(
      children: [
        Expanded(
          child:
          _detailStat(
            icon:
            Icons
                .bar_chart_rounded,
            title:
            'Historical Cases',
            value:
            _riskAvailable
                ? _formatNumber(
              _historicalCases,
            )
                : '--',
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        Expanded(
          child:
          _detailStat(
            icon:
            Icons
                .warning_amber_rounded,
            title:
            'Active Incidents',
            value:
            '${_nearbyAlerts.length}',
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        Expanded(
          child:
          _detailStat(
            icon:
            Icons.speed_rounded,
            title:
            'Crime Rate',
            value:
            _crimeRatePer100k != null
                ? _crimeRatePer100k!
                .toStringAsFixed(
              1,
            )
                : '--',
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DETAIL STAT
  // ============================================================

  Widget _detailStat({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 13,
      ),
      decoration:
      _cardDecoration(),
      child:
      Column(
        children: [
          Icon(
            icon,
            size:
            18,
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            value,
            maxLines:
            1,
            overflow:
            TextOverflow.ellipsis,
            style:
            const TextStyle(
              fontSize:
              15,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 2,
          ),

          Text(
            title,
            textAlign:
            TextAlign.center,
            style:
            const TextStyle(
              fontSize:
              7.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RISK DESCRIPTION
  // ============================================================

  Widget _buildRiskDescriptionCard() {
    final color =
    _riskColor();

    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(
        13,
      ),
      decoration:
      BoxDecoration(
        borderRadius:
        BorderRadius.circular(
          15,
        ),
        color:
        color.withOpacity(
          0.07,
        ),
        border:
        Border.all(
          color:
          color.withOpacity(
            0.17,
          ),
        ),
      ),
      child:
      Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons
                .info_outline_rounded,
            color:
            color,
            size:
            18,
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child:
            Text(
              _riskDescription(),
              style:
              const TextStyle(
                fontSize:
                9,
                height:
                1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NEARBY ALERT PREVIEW
  // ============================================================

  Widget _buildNearbyAlertsPreview() {
    if (_nearbyAlerts.isEmpty) {
      return Container(
        width:
        double.infinity,
        padding:
        const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 24,
        ),
        decoration:
        _cardDecoration(),
        child:
        const Column(
          children: [
            Icon(
              Icons
                  .shield_outlined,
              color:
              Colors.green,
              size:
              34,
            ),

            SizedBox(
              height: 9,
            ),

            Text(
              'No nearby alerts',
              style:
              TextStyle(
                fontSize:
                12,
                fontWeight:
                FontWeight.w600,
              ),
            ),

            SizedBox(
              height: 3,
            ),

            Text(
              'No active SafeZone emergency incidents are currently available nearby.',
              textAlign:
              TextAlign.center,
              style:
              TextStyle(
                fontSize:
                8.5,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final alert
        in _nearbyAlerts.take(
          4,
        ))
          Padding(
            padding:
            const EdgeInsets.only(
              bottom: 8,
            ),
            child:
            _buildAlertListItem(
              alert,
            ),
          ),

        if (_nearbyAlerts.length >
            4)
          TextButton(
            onPressed:
            _showNearbyAlerts,
            child:
            const Text(
              'View All Alerts',
            ),
          ),
      ],
    );
  }

  // ============================================================
  // ALERT LIST ITEM
  // ============================================================

  Widget _buildAlertListItem(
      _NearbyAlert alert,
      ) {
    final color =
    _alertColor(
      alert.category,
    );

    return Material(
      color:
      Colors.transparent,
      child:
      InkWell(
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        onTap: () =>
            _showAlertDetails(
              alert,
            ),
        child:
        Container(
          padding:
          const EdgeInsets.all(
            13,
          ),
          decoration:
          _cardDecoration(),
          child:
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                  color:
                  color.withOpacity(
                    0.10,
                  ),
                ),
                child:
                Icon(
                  _alertIcon(
                    alert.category,
                  ),
                  color:
                  color,
                  size:
                  20,
                ),
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style:
                      const TextStyle(
                        fontSize:
                        11,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      '${alert.distanceKm.toStringAsFixed(1)} km away • ${alert.timeAgo}',
                      style:
                      const TextStyle(
                        fontSize:
                        8.5,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SHOW NEARBY ALERTS
  // ============================================================

  Future<void> _showNearbyAlerts() async {
    final scheme =
        Theme.of(context)
            .colorScheme;

    await showModalBottomSheet(
      context:
      context,
      isScrollControlled:
      true,
      showDragHandle:
      true,
      backgroundColor:
      scheme.surface,
      builder: (
          context,
          ) {
        return SafeArea(
          top:
          false,
          child:
          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              18,
              4,
              18,
              24,
            ),
            child:
            Column(
              mainAxisSize:
              MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Nearby Alerts',
                        style:
                        TextStyle(
                          fontSize:
                          19,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),

                    if (_nearbyAlerts
                        .isNotEmpty)
                      Container(
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal:
                          9,
                          vertical:
                          5,
                        ),
                        decoration:
                        BoxDecoration(
                          color:
                          Colors.orange,
                          borderRadius:
                          BorderRadius.circular(
                            20,
                          ),
                        ),
                        child:
                        Text(
                          '${_nearbyAlerts.length} Active',
                          style:
                          const TextStyle(
                            color:
                            Colors.white,
                            fontSize:
                            9,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(
                  height: 5,
                ),

                const Text(
                  'SafeZone incidents detected near your current location.',
                  style:
                  TextStyle(
                    fontSize:
                    9,
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                if (_nearbyAlerts
                    .isEmpty)
                  Container(
                    width:
                    double.infinity,
                    padding:
                    const EdgeInsets.symmetric(
                      vertical:
                      32,
                      horizontal:
                      20,
                    ),
                    decoration:
                    _cardDecoration(),
                    child:
                    const Column(
                      children: [
                        Icon(
                          Icons
                              .check_circle_outline_rounded,
                          color:
                          Colors.green,
                          size:
                          42,
                        ),

                        SizedBox(
                          height:
                          10,
                        ),

                        Text(
                          'All Clear',
                          style:
                          TextStyle(
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        SizedBox(
                          height:
                          4,
                        ),

                        Text(
                          'There are currently no active nearby SafeZone alerts.',
                          textAlign:
                          TextAlign.center,
                          style:
                          TextStyle(
                            fontSize:
                            9,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child:
                    ListView.separated(
                      shrinkWrap:
                      true,

                      itemCount:
                      _nearbyAlerts.length,

                      separatorBuilder: (
                          context,
                          index,
                          ) =>
                      const SizedBox(
                        height:
                        8,
                      ),

                      itemBuilder: (
                          context,
                          index,
                          ) {
                        return _buildAlertListItem(
                          _nearbyAlerts[
                          index],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // ALERT DETAILS
  // ============================================================

  Future<void> _showAlertDetails(
      _NearbyAlert alert,
      ) async {
    final color =
    _alertColor(
      alert.category,
    );

    await showModalBottomSheet(
      context:
      context,
      showDragHandle:
      true,
      builder: (
          context,
          ) {
        return SafeArea(
          top:
          false,
          child:
          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24,
            ),
            child:
            Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration:
                  BoxDecoration(
                    shape:
                    BoxShape.circle,
                    color:
                    color.withOpacity(
                      0.12,
                    ),
                  ),
                  child:
                  Icon(
                    _alertIcon(
                      alert.category,
                    ),
                    color:
                    color,
                    size:
                    25,
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Text(
                  alert.title,
                  style:
                  const TextStyle(
                    fontSize:
                    18,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  '${alert.distanceKm.toStringAsFixed(1)} km away • ${alert.timeAgo}',
                ),

                if (alert.locationName !=
                    null) ...[
                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    alert.locationName!,
                    style:
                    const TextStyle(
                      fontSize:
                      10,
                    ),
                  ),
                ],

                const SizedBox(
                  height: 18,
                ),

                SizedBox(
                  width:
                  double.infinity,
                  child:
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );

                      _mapController.move(
                        LatLng(
                          alert.latitude,
                          alert.longitude,
                        ),
                        16,
                      );
                    },
                    icon:
                    const Icon(
                      Icons
                          .map_outlined,
                    ),
                    label:
                    const Text(
                      'Show on Map',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // SHEET SECTION TITLE
  // ============================================================

  Widget _sheetSectionTitle(
      String title,
      ) {
    return Text(
      title,
      style:
      const TextStyle(
        fontSize:
        14,
        fontWeight:
        FontWeight.bold,
      ),
    );
  }

  // ============================================================
  // SOS BUTTON
  // ============================================================

  Widget _buildSOSButton() {
    return SizedBox(
      width: 72,
      height: 72,
      child:
      FloatingActionButton(
        heroTag:
        'main_sos_button',

        onPressed:
        _startSOS,

        backgroundColor:
        Colors.redAccent,

        foregroundColor:
        Colors.white,

        elevation:
        8,

        shape:
        CircleBorder(
          side:
          BorderSide(
            color:
            Colors.red.shade300,
            width:
            3,
          ),
        ),

        child:
        const Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Text(
              'SOS',
              style:
              TextStyle(
                fontSize:
                19,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            Text(
              'HELP',
              style:
              TextStyle(
                fontSize:
                6,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigationBar() {
    final scheme =
        Theme.of(context)
            .colorScheme;

    return BottomAppBar(
      height: 74,

      padding:
      const EdgeInsets.symmetric(
        horizontal: 4,
      ),

      notchMargin:
      7,

      shape:
      const CircularNotchedRectangle(),

      color:
      scheme.surfaceContainer,

      child:
      Row(
        children: [
          Expanded(
            child:
            _bottomNavItem(
              index: 0,
              icon:
              Icons.home_outlined,
              selectedIcon:
              Icons.home_rounded,
              label:
              'Home',
            ),
          ),

          Expanded(
            child:
            _bottomNavItem(
              index: 1,
              icon:
              Icons
                  .analytics_outlined,
              selectedIcon:
              Icons
                  .analytics_rounded,
              label:
              'Insights',
            ),
          ),

          // ====================================================
          // CENTER SOS SPACE
          // ====================================================

          const SizedBox(
            width: 74,
          ),

          Expanded(
            child:
            _bottomNavItem(
              index: 2,
              icon:
              Icons
                  .history_outlined,
              selectedIcon:
              Icons
                  .history_rounded,
              label:
              'Activity',
            ),
          ),

          Expanded(
            child:
            _bottomNavItem(
              index: 3,
              icon:
              Icons.person_outline,
              selectedIcon:
              Icons.person_rounded,
              label:
              'Profile',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM NAV ITEM
  // ============================================================

  Widget _bottomNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final scheme =
        Theme.of(context)
            .colorScheme;

    final selected =
        _currentIndex ==
            index;

    final color =
    selected
        ? scheme.primary
        : scheme.onSurfaceVariant;

    return InkWell(
      borderRadius:
      BorderRadius.circular(
        14,
      ),
      onTap: () {
        setState(() {
          _currentIndex =
              index;
        });
      },
      child:
      Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          Icon(
            selected
                ? selectedIcon
                : icon,
            color:
            color,
            size:
            21,
          ),

          const SizedBox(
            height: 3,
          ),

          Text(
            label,
            style:
            TextStyle(
              fontSize:
              8,
              fontWeight:
              selected
                  ? FontWeight.w600
                  : FontWeight.normal,
              color:
              color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTIVITY PAGE
  // ============================================================

  Widget _buildActivityPage() {
    return SafeArea(
      child:
      ListView(
        padding:
        const EdgeInsets.all(
          20,
        ),
        children: [
          const Text(
            'Activity',
            style:
            TextStyle(
              fontSize:
              25,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          const Text(
            'Your SafeZone emergency and assistance history.',
            style:
            TextStyle(
              fontSize:
              10,
            ),
          ),

          const SizedBox(
            height: 28,
          ),

          Container(
            width:
            double.infinity,
            padding:
            const EdgeInsets.symmetric(
              vertical: 48,
              horizontal: 22,
            ),
            decoration:
            _cardDecoration(),
            child:
            const Column(
              children: [
                Icon(
                  Icons
                      .history_rounded,
                  size:
                  52,
                ),

                SizedBox(
                  height: 14,
                ),

                Text(
                  'No activity yet',
                  style:
                  TextStyle(
                    fontSize:
                    17,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),

                SizedBox(
                  height: 5,
                ),

                Text(
                  'SOS requests and incidents you respond to will appear here.',
                  textAlign:
                  TextAlign.center,
                  style:
                  TextStyle(
                    fontSize:
                    10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROFILE PAGE
  // ============================================================

  Widget _buildProfilePage() {
    return SafeArea(
      child:
      ListView(
        padding:
        const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          30,
        ),
        children: [
          const Text(
            'Profile',
            style:
            TextStyle(
              fontSize:
              25,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 24,
          ),

          CircleAvatar(
            radius:
            42,
            child:
            Text(
              _userName.isNotEmpty
                  ? _userName[0]
                  .toUpperCase()
                  : 'U',
              style:
              const TextStyle(
                fontSize:
                30,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Text(
            _userName,
            textAlign:
            TextAlign.center,
            style:
            const TextStyle(
              fontSize:
              19,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          Text(
            _userEmail,
            textAlign:
            TextAlign.center,
            style:
            const TextStyle(
              fontSize:
              10,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          // ====================================================
          // SAFETY SETUP SUMMARY
          // ====================================================

          Container(
            padding:
            const EdgeInsets.all(
              14,
            ),
            decoration:
            _cardDecoration(),
            child:
            Row(
              children: [
                Expanded(
                  child:
                  _profileStatus(
                    title:
                    'Phone',
                    complete:
                    _phoneVerified,
                  ),
                ),

                Container(
                  height: 34,
                  width: 1,
                  color:
                  Theme.of(context)
                      .colorScheme
                      .outlineVariant,
                ),

                Expanded(
                  child:
                  _profileStatus(
                    title:
                    'Device',
                    complete:
                    _hasBoundDevice,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 22,
          ),

          _profileOption(
            icon:
            Icons.person_outline,
            title:
            'Personal Information',
            subtitle:
            _phoneVerified
                ? 'Phone verified'
                : 'Phone verification required',
            onTap:
            _openPersonalInformation,
          ),

          _profileOption(
            icon:
            Icons.devices_outlined,
            title:
            'Registered Device',
            subtitle:
            _hasBoundDevice
                ? 'Device binding completed'
                : 'Device binding required',
            onTap:
            _openRegisteredDevice,
          ),

          _profileOption(
            icon:
            Icons.notifications_outlined,
            title:
            'Notifications',
            subtitle:
            'Notification preferences',
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                const SnackBar(
                  content:
                  Text(
                    'Notification settings will be available later.',
                  ),
                ),
              );
            },
          ),

          _profileOption(
            icon:
            Icons.security_outlined,
            title:
            'Privacy & Security',
            subtitle:
            'Account and safety settings',
            onTap:
            _openPrivacy,
          ),

          _profileOption(
            icon:
            Icons.help_outline_rounded,
            title:
            'Help & Support',
            subtitle:
            'Guides and support',
            onTap:
            _openHelp,
          ),

          const SizedBox(
            height: 20,
          ),

          SizedBox(
            height: 48,
            child:
            OutlinedButton.icon(
              onPressed:
              _logout,
              icon:
              const Icon(
                Icons
                    .logout_rounded,
              ),
              label:
              const Text(
                'Logout',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROFILE SETUP STATUS
  // ============================================================

  Widget _profileStatus({
    required String title,
    required bool complete,
  }) {
    final color =
    complete
        ? Colors.green
        : Colors.orange;

    return Column(
      children: [
        Icon(
          complete
              ? Icons
              .check_circle_rounded
              : Icons
              .error_outline_rounded,
          color:
          color,
          size:
          20,
        ),

        const SizedBox(
          height: 5,
        ),

        Text(
          title,
          style:
          const TextStyle(
            fontSize:
            9,
          ),
        ),

        Text(
          complete
              ? 'Completed'
              : 'Required',
          style:
          TextStyle(
            fontSize:
            8,
            color:
            color,
            fontWeight:
            FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PROFILE OPTION
  // ============================================================

  Widget _profileOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 2,
        vertical: 2,
      ),
      leading:
      Icon(
        icon,
      ),
      title:
      Text(
        title,
      ),
      subtitle:
      Text(
        subtitle,
        style:
        const TextStyle(
          fontSize:
          9,
        ),
      ),
      trailing:
      const Icon(
        Icons
            .chevron_right_rounded,
      ),
      onTap:
      onTap,
    );
  }

  // ============================================================
  // CARD DECORATION
  // ============================================================

  BoxDecoration _cardDecoration() {
    final scheme =
        Theme.of(context)
            .colorScheme;

    return BoxDecoration(
      color:
      scheme.surfaceContainer,
      borderRadius:
      BorderRadius.circular(
        17,
      ),
      border:
      Border.all(
        color:
        scheme.outlineVariant,
      ),
    );
  }

  // ============================================================
  // RISK COLOR
  // ============================================================

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

  // ============================================================
  // RISK DESCRIPTION
  // ============================================================

  String _riskDescription() {
    if (!_riskAvailable) {
      return 'Current risk information is unavailable until your Malaysian location can be identified.';
    }

    switch (_riskLevel.toUpperCase()) {
      case 'VERY HIGH':
        return 'Historical crime data indicates a significantly elevated population-adjusted risk compared with the Malaysia benchmark.';

      case 'HIGH':
        return 'Historical crime data indicates an elevated population-adjusted risk compared with the Malaysia benchmark.';

      case 'MODERATE':
      case 'MEDIUM':
        return 'Historical crime data indicates a moderate population-adjusted risk compared with the Malaysia benchmark.';

      case 'LOW':
      default:
        return 'Historical crime data indicates a comparatively lower population-adjusted risk compared with the Malaysia benchmark.';
    }
  }

  // ============================================================
  // ALERT COLOR
  // ============================================================

  Color _alertColor(
      _NearbyAlertCategory category,
      ) {
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

  // ============================================================
  // ALERT ICON
  // ============================================================

  IconData _alertIcon(
      _NearbyAlertCategory category,
      ) {
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

  // ============================================================
  // SHORT STATE NAME
  // ============================================================

  String _shortStateName(
      String state,
      ) {
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

  // ============================================================
  // NUMBER FORMAT
  // ============================================================

  String _formatNumber(
      int value,
      ) {
    return value
        .toString()
        .replaceAllMapped(
      RegExp(
        r'\B(?=(\d{3})+(?!\d))',
      ),
          (
          match,
          ) =>
      ',',
    );
  }
}

// ============================================================
// NEARBY ALERT CATEGORY
// ============================================================

enum _NearbyAlertCategory {
  sos,
  accident,
  suspicious,
  medical,
  other,
}

// ============================================================
// NEARBY ALERT MODEL
//
// Later this will be created from Supabase sos_incidents.
// ============================================================

class _NearbyAlert {
  final String id;

  final String title;

  final _NearbyAlertCategory category;

  final double latitude;

  final double longitude;

  final double distanceKm;

  final String timeAgo;

  final String? locationName;

  const _NearbyAlert({
    required this.id,
    required this.title,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.timeAgo,
    required this.locationName,
  });
}