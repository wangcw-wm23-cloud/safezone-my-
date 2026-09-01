import 'package:flutter/material.dart';
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
  // BOTTOM NAVIGATION
  // ============================================================

  int _currentIndex = 0;

  // ============================================================
  // CURRENT LOCATION
  // ============================================================

  bool _locationLoading = false;

  String _locationName =
      'Detecting your location...';

  String _district =
      'Location not available yet';

  String? _currentState;

  double? _currentLatitude;

  double? _currentLongitude;

  SafeZoneLocationErrorType?
  _lastLocationErrorType;

  // ============================================================
  // CURRENT AREA RISK
  // ============================================================

  bool _riskAvailable = false;

  String _riskLevel =
      'UNKNOWN';

  int _riskScore = 0;

  int _historicalCases = 0;

  // ============================================================
  // SAFEZONE LIVE INCIDENTS
  //
  // This will be connected to Supabase later.
  // ============================================================

  int _nearbyIncidents = 0;

  // ============================================================
  // SAFETY SETUP STATUS
  // ============================================================

  bool _setupLoading = true;

  String? _phoneNumber;

  bool _hasBoundDevice = false;

  bool get _hasPhoneNumber =>
      _phoneNumber != null &&
          _phoneNumber!.trim().isNotEmpty;

  bool get _setupComplete =>
      _hasPhoneNumber &&
          _hasBoundDevice;

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
  // INITIALIZE HOME
  // ============================================================

  Future<void> _initializeHome() async {
    await _loadSetupStatus();

    if (!mounted) return;

    await _loadCurrentSafetyData();
  }

  // ============================================================
  // LOAD ACCOUNT SETUP
  // ============================================================

  Future<void> _loadSetupStatus() async {
    final user =
        supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final profile =
      await supabase
          .from('profiles')
          .select(
        'phone_number',
      )
          .eq(
        'id',
        user.id,
      )
          .maybeSingle();

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

        _hasBoundDevice =
            device != null;

        _setupLoading = false;
      });
    } catch (e) {
      debugPrint(
        'LOAD SETUP STATUS ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _setupLoading = false;
      });
    }
  }

  // ============================================================
  // LOAD CURRENT GPS + STATE RISK
  // ============================================================

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

      _locationName =
      'Detecting your location...';

      _district =
      'Getting GPS and safety information...';
    });

    try {
      // ========================================================
      // STEP 1:
      // GET GPS + REVERSE GEOCODING
      // ========================================================

      final location =
      await LocationService.instance
          .getCurrentLocation();

      if (!mounted) {
        return false;
      }

      // ========================================================
      // SAVE GPS
      // ========================================================

      _currentLatitude =
          location.latitude;

      _currentLongitude =
          location.longitude;

      _currentState =
          location.state;

      // ========================================================
      // CREATE HOME DISPLAY
      // ========================================================

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
              stateName.toLowerCase()
          ? '${location.district} • $stateName'
          : location.district;

      // ========================================================
      // NO STATE FOUND
      //
      // GPS may still work, but risk cannot be matched.
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

          _locationLoading =
          false;
        });

        if (showErrorSnackBar &&
            mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Location detected, but the Malaysian state could not be identified.',
              ),
            ),
          );
        }

        return false;
      }

      // ========================================================
      // STEP 2:
      // LOAD STATE RISK DATA
      // ========================================================

      final stateRisks =
      await StateRiskService.instance
          .loadStateRisks(
        refresh:
        refreshRisk,
      );

      if (!mounted) {
        return false;
      }

      // ========================================================
      // STEP 3:
      // MATCH CURRENT STATE
      // ========================================================

      final currentRisk =
      _findStateRisk(
        stateRisks,
        location.state!,
      );

      // ========================================================
      // STATE FOUND BUT NO RISK DATA
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

          _locationLoading =
          false;
        });

        if (showErrorSnackBar &&
            mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            SnackBar(
              content: Text(
                'No historical risk information is available for ${_shortStateName(location.state!)}.',
              ),
            ),
          );
        }

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

        _locationLoading =
        false;
      });

      debugPrint(
        '============================================',
      );

      debugPrint(
        'SAFEZONE HOME SAFETY DATA',
      );

      debugPrint(
        'Location: ${location.locationName}',
      );

      debugPrint(
        'Area: $districtText',
      );

      debugPrint(
        'State: ${location.state}',
      );

      debugPrint(
        'Latitude: ${location.latitude}',
      );

      debugPrint(
        'Longitude: ${location.longitude}',
      );

      debugPrint(
        'Risk Score: ${currentRisk.riskScore}',
      );

      debugPrint(
        'Risk Level: ${currentRisk.riskLevel}',
      );

      debugPrint(
        'Historical Cases: ${currentRisk.totalCases}',
      );

      debugPrint(
        'Crime Rate: ${currentRisk.crimeRatePer100k.toStringAsFixed(2)} / 100k',
      );

      debugPrint(
        '============================================',
      );

      return true;
    }

    // ==========================================================
    // LOCATION-SPECIFIC ERROR
    // ==========================================================

    on SafeZoneLocationException catch (e) {
      debugPrint(
        'HOME LOCATION ERROR: ${e.message}',
      );

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

        switch (e.type) {
          case SafeZoneLocationErrorType
              .serviceDisabled:
            _locationName =
            'Location Disabled';

            _district =
            'Turn on GPS to view your current safety area';

            break;

          case SafeZoneLocationErrorType
              .permissionDenied:
            _locationName =
            'Location Permission Required';

            _district =
            'Allow location access to view local safety risk';

            break;

          case SafeZoneLocationErrorType
              .permissionDeniedForever:
            _locationName =
            'Location Access Blocked';

            _district =
            'Enable location permission in App Settings';

            break;

          case SafeZoneLocationErrorType
              .unableToGetLocation:
            _locationName =
            'Location Unavailable';

            _district =
            'Unable to get a GPS position';

            break;

          case SafeZoneLocationErrorType
              .unableToDetermineArea:
            _locationName =
            'Area Unavailable';

            _district =
            'Unable to determine the current area';

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
    }

    // ==========================================================
    // OTHER ERROR
    // ==========================================================

    catch (e) {
      debugPrint(
        'HOME SAFETY DATA ERROR: $e',
      );

      if (!mounted) {
        return false;
      }

      setState(() {
        _locationLoading =
        false;

        _riskAvailable =
        false;

        _riskLevel =
        'UNKNOWN';

        _riskScore =
        0;

        _historicalCases =
        0;

        _locationName =
        'Safety Data Unavailable';

        _district =
        'Unable to load current safety information';
      });

      if (showErrorSnackBar &&
          mounted) {
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
  // FIND STATE RISK
  // ============================================================

  StateRiskData? _findStateRisk(
      List<StateRiskData> data,
      String state,
      ) {
    for (final item in data) {
      if (item.state == state) {
        return item;
      }
    }

    return null;
  }

  // ============================================================
  // LOCATION ACTION
  //
  // GPS button behaviour:
  //
  // GPS off
  // -> Location settings
  //
  // Permanently denied
  // -> App settings
  //
  // Otherwise
  // -> Refresh location
  // ============================================================

  Future<void> _onLocationAction() async {
    if (_locationLoading) {
      return;
    }

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

    await _loadCurrentSafetyData(
      showErrorSnackBar:
      true,
    );
  }

  // ============================================================
  // OPEN PERSONAL INFORMATION
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

    setState(() {});

    await _loadSetupStatus();
  }

  // ============================================================
  // OPEN REGISTERED DEVICE
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
  // OPEN PRIVACY
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
  // OPEN HELP
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
  // REFRESH HOME
  //
  // Refresh:
  //
  // 1. Account setup
  // 2. GPS
  // 3. Area
  // 4. Risk data
  // ============================================================

  Future<void> _refreshHome() async {
    await _loadSetupStatus();

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
            'Current location and safety information updated.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // SETUP BANNER
  // ============================================================

  Widget _buildSetupBanner() {
    if (_setupLoading ||
        _setupComplete) {
      return const SizedBox.shrink();
    }

    late String title;

    late String description;

    late String buttonText;

    late IconData icon;

    late VoidCallback onPressed;

    // ==========================================================
    // BOTH MISSING
    // ==========================================================

    if (!_hasPhoneNumber &&
        !_hasBoundDevice) {
      title =
      'Complete Your Safety Setup';

      description =
      'Add your phone number and bind this '
          'device to activate SafeZone emergency features.';

      buttonText =
      'Start Setup';

      icon =
          Icons.warning_amber_rounded;

      onPressed = () {
        _openPersonalInformation();
      };
    }

    // ==========================================================
    // PHONE MISSING
    // ==========================================================

    else if (!_hasPhoneNumber) {
      title =
      'Add Your Phone Number';

      description =
      'Your phone number is required '
          'before emergency features can be activated.';

      buttonText =
      'Add Phone';

      icon =
          Icons.phone_outlined;

      onPressed = () {
        _openPersonalInformation();
      };
    }

    // ==========================================================
    // DEVICE MISSING
    // ==========================================================

    else {
      title =
      'Bind This Device';

      description =
      'Register this device to secure '
          'your SafeZone emergency access.';

      buttonText =
      'Bind Device';

      icon =
          Icons.devices_outlined;

      onPressed = () {
        _openRegisteredDevice();
      };
    }

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 22,
      ),
      padding:
      const EdgeInsets.all(
        18,
      ),
      decoration:
      BoxDecoration(
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: Colors.amber
              .withOpacity(
            0.45,
          ),
        ),
        color: Colors.amber
            .withOpacity(
          0.08,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                BoxDecoration(
                  shape:
                  BoxShape.circle,
                  color: Colors.amber
                      .withOpacity(
                    0.15,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                  Colors.amber,
                ),
              ),

              const SizedBox(
                width: 13,
              ),

              Expanded(
                child: Text(
                  title,
                  style:
                  const TextStyle(
                    fontSize: 16,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          Text(
            description,
            style:
            const TextStyle(
              fontSize: 12,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          SizedBox(
            width:
            double.infinity,
            child:
            OutlinedButton(
              onPressed:
              onPressed,
              child: Text(
                buttonText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // START SOS
  // ============================================================

  Future<void> _startSOS() async {
    // ==========================================================
    // CHECK SAFETY SETUP
    // ==========================================================

    if (!_setupComplete) {
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
                  .warning_amber_rounded,
              size: 45,
            ),
            title:
            const Text(
              'Safety Setup Required',
            ),
            content:
            Text(
              !_hasPhoneNumber &&
                  !_hasBoundDevice
                  ? 'Please add your phone number and bind this device before using SOS.'
                  : !_hasPhoneNumber
                  ? 'Please add your phone number before using SOS.'
                  : 'Please bind this device before using SOS.',
            ),
            actions: [
              TextButton(
                onPressed:
                    () {
                  Navigator.pop(
                    dialogContext,
                  );
                },
                child:
                const Text(
                  'Cancel',
                ),
              ),

              FilledButton(
                onPressed:
                    () {
                  Navigator.pop(
                    dialogContext,
                  );

                  if (!_hasPhoneNumber) {
                    _openPersonalInformation();
                  } else {
                    _openRegisteredDevice();
                  }
                },
                child:
                const Text(
                  'Complete Setup',
                ),
              ),
            ],
          );
        },
      );

      return;
    }

    if (!mounted) return;

    // ==========================================================
    // OPEN SOS CATEGORY PAGE
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
  // MAIN
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      body:
      IndexedStack(
        index:
        _currentIndex,
        children: [
          // ====================================================
          // HOME
          // ====================================================

          _buildHomePage(),

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
      // NAVIGATION
      // ========================================================

      bottomNavigationBar:
      NavigationBar(
        selectedIndex:
        _currentIndex,
        onDestinationSelected: (
            index,
            ) {
          setState(() {
            _currentIndex =
                index;
          });
        },
        destinations:
        const [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),
            selectedIcon: Icon(
              Icons.home_rounded,
            ),
            label:
            'Home',
          ),

          NavigationDestination(
            icon: Icon(
              Icons
                  .analytics_outlined,
            ),
            selectedIcon: Icon(
              Icons
                  .analytics_rounded,
            ),
            label:
            'Insights',
          ),

          NavigationDestination(
            icon: Icon(
              Icons
                  .history_outlined,
            ),
            selectedIcon: Icon(
              Icons
                  .history_rounded,
            ),
            label:
            'Activity',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),
            selectedIcon: Icon(
              Icons.person,
            ),
            label:
            'Profile',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HOME PAGE
  // ============================================================

  Widget _buildHomePage() {
    return SafeArea(
      child:
      RefreshIndicator(
        onRefresh:
        _refreshHome,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            30,
          ),
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration:
                  BoxDecoration(
                    borderRadius:
                    BorderRadius.circular(
                      15,
                    ),
                    color:
                    Theme.of(
                      context,
                    )
                        .colorScheme
                        .primary
                        .withOpacity(
                      0.15,
                    ),
                  ),
                  child:
                  Icon(
                    Icons
                        .shield_rounded,
                    color:
                    Theme.of(
                      context,
                    )
                        .colorScheme
                        .primary,
                  ),
                ),

                const SizedBox(
                  width: 13,
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
                          21,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const Text(
                        'Stay aware. Stay safe.',
                        style:
                        TextStyle(
                          fontSize:
                          13,
                        ),
                      ),
                    ],
                  ),
                ),

                // ==============================================
                // REFRESH
                // ==============================================

                IconButton(
                  onPressed:
                  _locationLoading
                      ? null
                      : _refreshHome,
                  icon:
                  _locationLoading
                      ? const SizedBox(
                    width:
                    20,
                    height:
                    20,
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

                // ==============================================
                // NOTIFICATION
                // ==============================================

                IconButton(
                  onPressed:
                      () {},
                  icon:
                  Badge(
                    isLabelVisible:
                    _nearbyIncidents >
                        0,
                    child:
                    const Icon(
                      Icons
                          .notifications_none_rounded,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 22,
            ),

            // ==================================================
            // SETUP
            // ==================================================

            _buildSetupBanner(),

            // ==================================================
            // CURRENT AREA
            // ==================================================

            _sectionTitle(
              icon: Icons
                  .location_on_outlined,
              title:
              'Your Current Area',
            ),

            const SizedBox(
              height: 10,
            ),

            _buildCurrentAreaCard(),

            const SizedBox(
              height: 24,
            ),

            // ==================================================
            // SOS
            // ==================================================

            _buildSOSCard(),

            const SizedBox(
              height: 24,
            ),

            // ==================================================
            // NEARBY ALERTS
            // ==================================================

            _sectionTitle(
              icon: Icons
                  .crisis_alert_outlined,
              title:
              'Nearby Alerts',
            ),

            const SizedBox(
              height: 10,
            ),

            _buildNearbyAlerts(),

            const SizedBox(
              height: 24,
            ),

            // ==================================================
            // SAFETY MAP
            // ==================================================

            Row(
              children: [
                Expanded(
                  child:
                  _sectionTitle(
                    icon: Icons
                        .map_outlined,
                    title:
                    'Safety Map',
                  ),
                ),

                TextButton(
                  onPressed:
                  _openFullMap,
                  child:
                  const Text(
                    'View Full Map',
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 8,
            ),

            _buildMapPreview(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CURRENT AREA CARD
  // ============================================================

  Widget _buildCurrentAreaCard() {
    return Container(
      padding:
      const EdgeInsets.all(
        20,
      ),
      decoration:
      _cardDecoration(),
      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          // ====================================================
          // LOCATION
          // ====================================================

          Row(
            children: [
              Container(
                width: 50,
                height: 50,
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
                    14,
                  ),
                  child:
                  CircularProgressIndicator(
                    strokeWidth:
                    2.5,
                  ),
                )
                    : const Icon(
                  Icons
                      .my_location_rounded,
                  color:
                  Colors.blue,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      _locationName,
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      _district,
                      style:
                      const TextStyle(
                        fontSize:
                        12,
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // GPS ACTION
              // ==================================================

              IconButton(
                tooltip:
                _lastLocationErrorType ==
                    SafeZoneLocationErrorType
                        .serviceDisabled
                    ? 'Open GPS settings'
                    : _lastLocationErrorType ==
                    SafeZoneLocationErrorType
                        .permissionDeniedForever
                    ? 'Open app settings'
                    : 'Refresh location',
                onPressed:
                _locationLoading
                    ? null
                    : _onLocationAction,
                icon:
                Icon(
                  _lastLocationErrorType ==
                      SafeZoneLocationErrorType
                          .serviceDisabled ||
                      _lastLocationErrorType ==
                          SafeZoneLocationErrorType
                              .permissionDeniedForever
                      ? Icons
                      .location_disabled_outlined
                      : Icons
                      .gps_fixed_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          const Divider(),

          const SizedBox(
            height: 12,
          ),

          // ====================================================
          // RISK
          // ====================================================

          Row(
            children: [
              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Safety Risk',
                      style:
                      TextStyle(
                        fontSize:
                        12,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration:
                          BoxDecoration(
                            shape:
                            BoxShape.circle,
                            color:
                            _riskColor(),
                          ),
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        Text(
                          _riskLevel,
                          style:
                          TextStyle(
                            fontSize:
                            24,
                            fontWeight:
                            FontWeight.bold,
                            color:
                            _riskColor(),
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
                      12,
                    ),
                  ),

                  Text(
                    _riskAvailable
                        ? '$_riskScore / 100'
                        : '-- / 100',
                    style:
                    const TextStyle(
                      fontSize:
                      21,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(
            height: 15,
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
              7,
              color:
              _riskColor(),
              backgroundColor:
              _riskColor()
                  .withOpacity(
                0.10,
              ),
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          // ====================================================
          // STATISTICS
          // ====================================================

          Row(
            children: [
              Expanded(
                child:
                _miniRiskStat(
                  label:
                  'Historical Cases',
                  value:
                  _riskAvailable
                      ? _formatNumber(
                    _historicalCases,
                  )
                      : '--',
                  icon: Icons
                      .bar_chart_rounded,
                ),
              ),

              Expanded(
                child:
                _miniRiskStat(
                  label:
                  'Active Incidents',
                  value:
                  '$_nearbyIncidents',
                  icon: Icons
                      .warning_amber_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          Text(
            _riskDescription(),
            style:
            const TextStyle(
              fontSize:
              11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SOS CARD
  // ============================================================

  Widget _buildSOSCard() {
    return Container(
      padding:
      const EdgeInsets.all(
        20,
      ),
      decoration:
      BoxDecoration(
        borderRadius:
        BorderRadius.circular(
          24,
        ),
        border:
        Border.all(
          color:
          Colors.redAccent.withOpacity(
            0.4,
          ),
        ),
        color:
        Colors.redAccent.withOpacity(
          0.06,
        ),
      ),
      child:
      Column(
        children: [
          const Text(
            'Need Emergency Help?',
            style:
            TextStyle(
              fontSize:
              20,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          const Text(
            'Send an emergency alert to verified '
                'SafeZone users nearby.',
            textAlign:
            TextAlign.center,
          ),

          const SizedBox(
            height: 18,
          ),

          GestureDetector(
            onTap:
            _startSOS,
            child:
            Container(
              width:
              125,
              height:
              125,
              decoration:
              BoxDecoration(
                shape:
                BoxShape.circle,
                color:
                Colors.redAccent,
                boxShadow: [
                  BoxShadow(
                    color:
                    Colors.redAccent.withOpacity(
                      0.3,
                    ),
                    blurRadius:
                    24,
                    spreadRadius:
                    5,
                  ),
                ],
              ),
              child:
              const Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons
                        .sos_rounded,
                    size:
                    45,
                    color:
                    Colors.white,
                  ),

                  Text(
                    'EMERGENCY',
                    style:
                    TextStyle(
                      color:
                      Colors.white,
                      fontWeight:
                      FontWeight.bold,
                      fontSize:
                      10,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(
            height: 15,
          ),

          Text(
            _setupComplete
                ? 'Tap SOS only when assistance is required.'
                : 'Complete your safety setup before using SOS.',
            textAlign:
            TextAlign.center,
            style:
            const TextStyle(
              fontSize:
              11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NEARBY ALERTS
  // ============================================================

  Widget _buildNearbyAlerts() {
    if (_nearbyIncidents == 0) {
      return Container(
        padding:
        const EdgeInsets.all(
          20,
        ),
        decoration:
        _cardDecoration(),
        child:
        const Row(
          children: [
            Icon(
              Icons
                  .check_circle_outline,
              color:
              Colors.green,
            ),

            SizedBox(
              width:
              14,
            ),

            Expanded(
              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    'No active incidents nearby',
                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),

                  SizedBox(
                    height:
                    4,
                  ),

                  Text(
                    'No SafeZone emergency alerts within 1 km.',
                    style:
                    TextStyle(
                      fontSize:
                      11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding:
      const EdgeInsets.all(
        18,
      ),
      decoration:
      _cardDecoration(),
      child:
      const Text(
        'Nearby SafeZone incidents will appear here.',
      ),
    );
  }

  // ============================================================
  // MAP PREVIEW
  // ============================================================

  Widget _buildMapPreview() {
    return InkWell(
      onTap:
      _openFullMap,
      child:
      Container(
        height:
        180,
        decoration:
        _cardDecoration(),
        child:
        Stack(
          children: [
            Positioned.fill(
              child:
              CustomPaint(
                painter:
                _MapBackgroundPainter(),
              ),
            ),

            const Center(
              child:
              Icon(
                Icons
                    .location_on_rounded,
                size:
                48,
                color:
                Colors.blueAccent,
              ),
            ),

            Positioned(
              left:
              14,
              top:
              14,
              child:
              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal:
                  11,
                  vertical:
                  7,
                ),
                decoration:
                BoxDecoration(
                  color:
                  Colors.black.withOpacity(
                    0.65,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),
                child:
                Text(
                  _currentState != null
                      ? _shortStateName(
                    _currentState!,
                  )
                      : 'Live Safety Map',
                  style:
                  const TextStyle(
                    color:
                    Colors.white,
                    fontSize:
                    12,
                  ),
                ),
              ),
            ),
          ],
        ),
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
              26,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
            5,
          ),

          const Text(
            'Your previous SafeZone requests and assistance.',
          ),

          const SizedBox(
            height:
            25,
          ),

          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal:
              24,
              vertical:
              50,
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
                  58,
                ),

                SizedBox(
                  height:
                  15,
                ),

                Text(
                  'No activity yet',
                  style:
                  TextStyle(
                    fontSize:
                    18,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),

                SizedBox(
                  height:
                  7,
                ),

                Text(
                  'Your SOS requests and incidents you '
                      'responded to will appear here.',
                  textAlign:
                  TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Widget _buildProfilePage() {
    return SafeArea(
      child:
      ListView(
        padding:
        const EdgeInsets.all(
          20,
        ),
        children: [
          const Text(
            'Profile',
            style:
            TextStyle(
              fontSize:
              26,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
            28,
          ),

          Center(
            child:
            CircleAvatar(
              radius:
              48,
              child:
              Text(
                _userName.isNotEmpty
                    ? _userName[0]
                    .toUpperCase()
                    : 'U',
                style:
                const TextStyle(
                  fontSize:
                  34,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(
            height:
            14,
          ),

          Text(
            _userName,
            textAlign:
            TextAlign.center,
            style:
            const TextStyle(
              fontSize:
              21,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          Text(
            _userEmail,
            textAlign:
            TextAlign.center,
          ),

          const SizedBox(
            height:
            30,
          ),

          _profileOption(
            icon:
            Icons.person_outline,
            title:
            'Personal Information',
            subtitle:
            'Name, phone, email and password',
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
                ? 'Device registered'
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
            onTap:
                () {
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
            'Account and safety information',
            onTap:
            _openPrivacy,
          ),

          _profileOption(
            icon:
            Icons.help_outline_rounded,
            title:
            'Help & Support',
            subtitle:
            'SafeZone guides and support',
            onTap:
            _openHelp,
          ),

          const SizedBox(
            height:
            22,
          ),

          SizedBox(
            height:
            50,
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
  // FULL MAP
  // ============================================================

  void _openFullMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
            Scaffold(
              appBar:
              AppBar(
                title:
                const Text(
                  'Safety Map',
                ),
              ),
              body:
              Stack(
                children: [
                  Positioned.fill(
                    child:
                    CustomPaint(
                      painter:
                      _MapBackgroundPainter(),
                    ),
                  ),

                  Center(
                    child:
                    Column(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons
                              .location_on_rounded,
                          size:
                          65,
                          color:
                          Colors.blueAccent,
                        ),

                        const SizedBox(
                          height:
                          10,
                        ),

                        Text(
                          _currentState != null
                              ? _shortStateName(
                            _currentState!,
                          )
                              : 'Live Safety Map',
                          style:
                          const TextStyle(
                            fontSize:
                            20,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height:
                          4,
                        ),

                        if (_currentLatitude !=
                            null &&
                            _currentLongitude !=
                                null)
                          Text(
                            '${_currentLatitude!.toStringAsFixed(5)}, '
                                '${_currentLongitude!.toStringAsFixed(5)}',
                            style:
                            const TextStyle(
                              fontSize:
                              11,
                            ),
                          ),

                        const SizedBox(
                          height:
                          4,
                        ),

                        const Text(
                          'Real map integration will be connected later.',
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

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size:
          20,
        ),

        const SizedBox(
          width:
          8,
        ),

        Text(
          title,
          style:
          const TextStyle(
            fontSize:
            18,
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CARD DECORATION
  // ============================================================

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
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
    );
  }

  // ============================================================
  // MINI RISK STAT
  // ============================================================

  Widget _miniRiskStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size:
          20,
        ),

        const SizedBox(
          height:
          5,
        ),

        Text(
          value,
          style:
          const TextStyle(
            fontSize:
            20,
            fontWeight:
            FontWeight.bold,
          ),
        ),

        Text(
          label,
          textAlign:
          TextAlign.center,
          style:
          const TextStyle(
            fontSize:
            10,
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
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal:
        4,
        vertical:
        2,
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
      subtitle != null
          ? Text(
        subtitle,
        style:
        const TextStyle(
          fontSize:
          11,
        ),
      )
          : null,
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
  // RISK COLOUR
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
      if (_locationLoading) {
        return 'Detecting your current area and loading historical safety information.';
      }

      return 'Current area risk information is unavailable until your location can be determined.';
    }

    switch (_riskLevel.toUpperCase()) {
      case 'VERY HIGH':
        return 'Historical crime data indicates a significantly elevated population-adjusted risk compared with the Malaysia benchmark.';

      case 'HIGH':
        return 'Historical crime data indicates an elevated population-adjusted risk compared with the Malaysia benchmark.';

      case 'MODERATE':
      case 'MEDIUM':
        return 'Historical crime data indicates a moderate population-adjusted risk for this area.';

      case 'LOW':
      default:
        return 'Historical crime data indicates a comparatively lower population-adjusted risk for this area.';
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
// TEMPORARY SAFETY MAP BACKGROUND
//
// We keep this for now.
// Later it will be replaced with the real live map.
// ============================================================

class _MapBackgroundPainter
    extends CustomPainter {
  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final gridPaint =
    Paint()
      ..color =
      Colors.grey.withOpacity(
        0.15,
      )
      ..strokeWidth =
      1.5;

    final roadPaint =
    Paint()
      ..color =
      Colors.grey.withOpacity(
        0.28,
      )
      ..strokeWidth =
      5
      ..style =
          PaintingStyle.stroke;

    // ==========================================================
    // HORIZONTAL GRID
    // ==========================================================

    for (
    double y = 30;
    y < size.height;
    y += 45
    ) {
      canvas.drawLine(
        Offset(
          0,
          y,
        ),
        Offset(
          size.width,
          y,
        ),
        gridPaint,
      );
    }

    // ==========================================================
    // VERTICAL GRID
    // ==========================================================

    for (
    double x = 35;
    x < size.width;
    x += 55
    ) {
      canvas.drawLine(
        Offset(
          x,
          0,
        ),
        Offset(
          x,
          size.height,
        ),
        gridPaint,
      );
    }

    // ==========================================================
    // ROAD
    // ==========================================================

    final road =
    Path()
      ..moveTo(
        0,
        size.height *
            0.72,
      )
      ..quadraticBezierTo(
        size.width *
            0.30,
        size.height *
            0.35,
        size.width *
            0.58,
        size.height *
            0.58,
      )
      ..quadraticBezierTo(
        size.width *
            0.78,
        size.height *
            0.75,
        size.width,
        size.height *
            0.28,
      );

    canvas.drawPath(
      road,
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(
      covariant CustomPainter oldDelegate,
      ) {
    return false;
  }
}