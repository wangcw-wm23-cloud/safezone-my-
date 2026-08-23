import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'help_support_screen.dart';
import 'login_screen.dart';
import 'personal_information_screen.dart';
import 'privacy_security_screen.dart';
import 'registered_device_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {
  final SupabaseClient supabase =
      Supabase.instance.client;

  int _currentIndex = 0;

  String _locationName =
      'Detecting your location...';

  String _district =
      'Location not available yet';

  String _riskLevel = 'LOW';

  int _riskScore = 24;

  int _historicalCases = 0;

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
    final user = _currentUser;

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

    final email = user.email;

    if (email != null &&
        email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'User';
  }

  String get _userEmail =>
      _currentUser?.email ??
          'No email available';

  @override
  void initState() {
    super.initState();

    _loadSetupStatus();
  }

  // ============================================================
  // LOAD ACCOUNT SETUP
  // ============================================================

  Future<void> _loadSetupStatus() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('phone_number')
          .eq('id', user.id)
          .maybeSingle();

      final device = await supabase
          .from('user_devices')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_active', true)
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
  // OPEN PROFILE FUNCTIONS
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

  void _openPrivacy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const PrivacySecurityScreen(),
      ),
    );
  }

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
  // REFRESH
  // ============================================================

  Future<void> _refreshHome() async {
    await _loadSetupStatus();

    await Future.delayed(
      const Duration(
        milliseconds: 300,
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Safety information refreshed.',
        ),
      ),
    );
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
    } else if (!_hasPhoneNumber) {
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
    } else {
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
              .withOpacity(0.45),
        ),
        color: Colors.amber
            .withOpacity(0.08),
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
                    FontWeight
                        .bold,
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
  // SOS
  // ============================================================

  Future<void> _startSOS() async {
    if (!_setupComplete) {
      await showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons
                  .warning_amber_rounded,
              size: 45,
            ),
            title: const Text(
              'Safety Setup Required',
            ),
            content: Text(
              !_hasPhoneNumber &&
                  !_hasBoundDevice
                  ? 'Please add your phone number and bind this device before using SOS.'
                  : !_hasPhoneNumber
                  ? 'Please add your phone number before using SOS.'
                  : 'Please bind this device before using SOS.',
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
                  'Cancel',
                ),
              ),

              FilledButton(
                onPressed: () {
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding:
            const EdgeInsets
                .fromLTRB(
              24,
              20,
              24,
              30,
            ),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration:
                  BoxDecoration(
                    color:
                    Colors.grey,
                    borderRadius:
                    BorderRadius
                        .circular(
                      20,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                const Icon(
                  Icons.sos_rounded,
                  size: 72,
                  color:
                  Colors.redAccent,
                ),

                const SizedBox(
                  height: 15,
                ),

                const Text(
                  'Emergency SOS',
                  style:
                  TextStyle(
                    fontSize: 25,
                    fontWeight:
                    FontWeight
                        .bold,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                const Text(
                  'Are you sure you need emergency assistance?',
                  textAlign:
                  TextAlign.center,
                ),

                const SizedBox(
                  height: 8,
                ),

                const Text(
                  'Your live location will be shared with '
                      'eligible SafeZone users nearby.',
                  textAlign:
                  TextAlign.center,
                  style:
                  TextStyle(
                    fontSize: 12,
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                SizedBox(
                  width:
                  double.infinity,
                  height: 52,
                  child:
                  ElevatedButton
                      .icon(
                    style:
                    ElevatedButton
                        .styleFrom(
                      backgroundColor:
                      Colors
                          .redAccent,
                      foregroundColor:
                      Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(
                        sheetContext,
                      );

                      ScaffoldMessenger
                          .of(context)
                          .showSnackBar(
                        const SnackBar(
                          content:
                          Text(
                            'SOS backend will be connected later.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons
                          .warning_amber_rounded,
                    ),
                    label:
                    const Text(
                      'Confirm SOS',
                      style:
                      TextStyle(
                        fontWeight:
                        FontWeight
                            .bold,
                      ),
                    ),
                  ),
                ),

                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      sheetContext,
                    );
                  },
                  child:
                  const Text(
                    'Cancel',
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
          (route) => false,
    );
  }

  // ============================================================
  // MAIN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomePage(),
          _buildSafetyDataPage(),
          _buildActivityPage(),
          _buildProfilePage(),
        ],
      ),

      bottomNavigationBar:
      NavigationBar(
        selectedIndex:
        _currentIndex,
        onDestinationSelected:
            (index) {
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
            label: 'Home',
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
            'Safety Data',
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
              Icons
                  .person_outline,
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
  // HOME
  // ============================================================

  Widget _buildHomePage() {
    return SafeArea(
      child:
      RefreshIndicator(
        onRefresh:
        _refreshHome,
        child: ListView(
          padding:
          const EdgeInsets
              .fromLTRB(
            20,
            18,
            20,
            30,
          ),
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration:
                  BoxDecoration(
                    borderRadius:
                    BorderRadius
                        .circular(
                      15,
                    ),
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .primary
                        .withOpacity(
                      0.15,
                    ),
                  ),
                  child: Icon(
                    Icons
                        .shield_rounded,
                    color: Theme.of(
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
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(
                        'Hello, $_userName',
                        maxLines:
                        1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          fontSize:
                          21,
                          fontWeight:
                          FontWeight
                              .bold,
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

                IconButton(
                  onPressed:
                  _refreshHome,
                  icon:
                  const Icon(
                    Icons
                        .refresh_rounded,
                  ),
                ),

                IconButton(
                  onPressed:
                      () {},
                  icon: Badge(
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

            _buildSetupBanner(),

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

            _buildSOSCard(),

            const SizedBox(
              height: 24,
            ),

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

  Widget _buildCurrentAreaCard() {
    return Container(
      padding:
      const EdgeInsets.all(
        20,
      ),
      decoration:
      _cardDecoration(),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration:
                BoxDecoration(
                  shape:
                  BoxShape.circle,
                  color: Colors.blue
                      .withOpacity(
                    0.12,
                  ),
                ),
                child:
                const Icon(
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
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      _locationName,
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight
                            .w600,
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

              const Icon(
                Icons
                    .gps_fixed_rounded,
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

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
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
                            BoxShape
                                .circle,
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
                            FontWeight
                                .bold,
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
                CrossAxisAlignment
                    .end,
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
                    '$_riskScore / 100',
                    style:
                    const TextStyle(
                      fontSize:
                      21,
                      fontWeight:
                      FontWeight
                          .bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(
            height: 15,
          ),

          LinearProgressIndicator(
            value:
            _riskScore / 100,
            minHeight: 7,
            color:
            _riskColor(),
          ),

          const SizedBox(
            height: 18,
          ),

          Row(
            children: [
              Expanded(
                child:
                _miniRiskStat(
                  label:
                  'Historical Cases',
                  value:
                  '$_historicalCases',
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
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

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
        border: Border.all(
          color:
          Colors.redAccent
              .withOpacity(
            0.4,
          ),
        ),
        color:
        Colors.redAccent
            .withOpacity(
          0.06,
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Need Emergency Help?',
            style:
            TextStyle(
              fontSize: 20,
              fontWeight:
              FontWeight
                  .bold,
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
            onTap: _startSOS,
            child:
            Container(
              width: 125,
              height: 125,
              decoration:
              BoxDecoration(
                shape:
                BoxShape.circle,
                color: Colors
                    .redAccent,
                boxShadow: [
                  BoxShadow(
                    color: Colors
                        .redAccent
                        .withOpacity(
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
                MainAxisAlignment
                    .center,
                children: [
                  Icon(
                    Icons
                        .sos_rounded,
                    size: 45,
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
                      FontWeight
                          .bold,
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
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

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
              width: 14,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    'No active incidents nearby',
                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight
                          .w600,
                    ),
                  ),

                  SizedBox(
                    height: 4,
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

  Widget _buildMapPreview() {
    return InkWell(
      onTap: _openFullMap,
      child:
      Container(
        height: 180,
        decoration:
        _cardDecoration(),
        child: Stack(
          children: [
            Positioned.fill(
              child:
              CustomPaint(
                painter:
                _MapBackgroundPainter(),
              ),
            ),

            const Center(
              child: Icon(
                Icons
                    .location_on_rounded,
                size: 48,
                color: Colors
                    .blueAccent,
              ),
            ),

            Positioned(
              left: 14,
              top: 14,
              child:
              Container(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal:
                  11,
                  vertical:
                  7,
                ),
                decoration:
                BoxDecoration(
                  color:
                  Colors.black
                      .withOpacity(
                    0.65,
                  ),
                  borderRadius:
                  BorderRadius
                      .circular(
                    10,
                  ),
                ),
                child:
                const Text(
                  'Live Safety Map',
                  style:
                  TextStyle(
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
  // SAFETY DATA
  // ============================================================

  Widget _buildSafetyDataPage() {
    return SafeArea(
      child: ListView(
        padding:
        const EdgeInsets.all(
          20,
        ),
        children: [
          const Text(
            'Safety Data',
            style:
            TextStyle(
              fontSize: 26,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          const Text(
            'Government historical data and '
                'SafeZone community statistics.',
          ),

          const SizedBox(
            height: 25,
          ),

          _dataHeader(
            icon: Icons
                .account_balance_outlined,
            title:
            'Government Data',
            subtitle:
            'Source: data.gov.my',
          ),

          const SizedBox(
            height: 12,
          ),

          Container(
            padding:
            const EdgeInsets.all(
              20,
            ),
            decoration:
            _cardDecoration(),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                const Text(
                  'Historical Crime Overview',
                  style:
                  TextStyle(
                    fontSize:
                    18,
                    fontWeight:
                    FontWeight
                        .bold,
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                      _dataStat(
                        'Historical Cases',
                        '$_historicalCases',
                      ),
                    ),

                    Expanded(
                      child:
                      _dataStat(
                        'Risk Score',
                        '$_riskScore',
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 20,
                ),

                Container(
                  height: 180,
                  width:
                  double.infinity,
                  decoration:
                  BoxDecoration(
                    borderRadius:
                    BorderRadius
                        .circular(
                      18,
                    ),
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                  child:
                  const Column(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .center,
                    children: [
                      Icon(
                        Icons
                            .show_chart_rounded,
                        size: 45,
                      ),
                      SizedBox(
                        height: 8,
                      ),
                      Text(
                        'Historical Crime Trend',
                        style:
                        TextStyle(
                          fontWeight:
                          FontWeight
                              .w600,
                        ),
                      ),
                      Text(
                        'data.gov.my chart will appear here',
                        style:
                        TextStyle(
                          fontSize:
                          11,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                _categoryRow(
                  'Violent Crime',
                  0,
                ),

                _categoryRow(
                  'Property Crime',
                  0,
                ),

                _categoryRow(
                  'Other Reported Cases',
                  0,
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 30,
          ),

          _dataHeader(
            icon: Icons
                .shield_outlined,
            title:
            'SafeZone Community',
            subtitle:
            'Live SafeZone statistics',
          ),

          const SizedBox(
            height: 12,
          ),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics:
            const NeverScrollableScrollPhysics(),
            mainAxisSpacing:
            12,
            crossAxisSpacing:
            12,
            childAspectRatio:
            1.35,
            children: [
              _communityStatCard(
                icon:
                Icons.sos_rounded,
                value: '0',
                label:
                'Total SOS',
              ),
              _communityStatCard(
                icon: Icons
                    .warning_amber_rounded,
                value: '0',
                label:
                'Active Incidents',
              ),
              _communityStatCard(
                icon: Icons
                    .check_circle_outline,
                value: '0',
                label:
                'Resolved',
              ),
              _communityStatCard(
                icon: Icons
                    .volunteer_activism_outlined,
                value: '0',
                label:
                'Users Assisted',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTIVITY
  // ============================================================

  Widget _buildActivityPage() {
    return SafeArea(
      child: ListView(
        padding:
        const EdgeInsets.all(
          20,
        ),
        children: [
          const Text(
            'Activity',
            style:
            TextStyle(
              fontSize: 26,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          const Text(
            'Your previous SafeZone requests and assistance.',
          ),

          const SizedBox(
            height: 25,
          ),

          Container(
            padding:
            const EdgeInsets
                .symmetric(
              horizontal: 24,
              vertical: 50,
            ),
            decoration:
            _cardDecoration(),
            child:
            const Column(
              children: [
                Icon(
                  Icons
                      .history_rounded,
                  size: 58,
                ),

                SizedBox(
                  height: 15,
                ),

                Text(
                  'No activity yet',
                  style:
                  TextStyle(
                    fontSize:
                    18,
                    fontWeight:
                    FontWeight
                        .w600,
                  ),
                ),

                SizedBox(
                  height: 7,
                ),

                Text(
                  'Your SOS requests and incidents you '
                      'responded to will appear here.',
                  textAlign:
                  TextAlign
                      .center,
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
      child: ListView(
        padding:
        const EdgeInsets.all(
          20,
        ),
        children: [
          const Text(
            'Profile',
            style:
            TextStyle(
              fontSize: 26,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 28,
          ),

          Center(
            child:
            CircleAvatar(
              radius: 48,
              child: Text(
                _userName.isNotEmpty
                    ? _userName[0]
                    .toUpperCase()
                    : 'U',
                style:
                const TextStyle(
                  fontSize:
                  34,
                  fontWeight:
                  FontWeight
                      .bold,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          Text(
            _userName,
            textAlign:
            TextAlign.center,
            style:
            const TextStyle(
              fontSize: 21,
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
            height: 30,
          ),

          _profileOption(
            icon: Icons
                .person_outline,
            title:
            'Personal Information',
            subtitle:
            'Name, phone, email and password',
            onTap:
            _openPersonalInformation,
          ),

          _profileOption(
            icon: Icons
                .devices_outlined,
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
            icon: Icons
                .notifications_outlined,
            title:
            'Notifications',
            subtitle:
            'Notification preferences',
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Notification settings will be available later.',
                  ),
                ),
              );
            },
          ),

          _profileOption(
            icon: Icons
                .security_outlined,
            title:
            'Privacy & Security',
            subtitle:
            'Account and safety information',
            onTap:
            _openPrivacy,
          ),

          _profileOption(
            icon: Icons
                .help_outline_rounded,
            title:
            'Help & Support',
            subtitle:
            'SafeZone guides and support',
            onTap:
            _openHelp,
          ),

          const SizedBox(
            height: 22,
          ),

          SizedBox(
            height: 50,
            child:
            OutlinedButton
                .icon(
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
        builder: (_) =>
            Scaffold(
              appBar: AppBar(
                title:
                const Text(
                  'Safety Map',
                ),
              ),
              body: Stack(
                children: [
                  Positioned.fill(
                    child:
                    CustomPaint(
                      painter:
                      _MapBackgroundPainter(),
                    ),
                  ),

                  const Center(
                    child: Column(
                      mainAxisSize:
                      MainAxisSize
                          .min,
                      children: [
                        Icon(
                          Icons
                              .location_on_rounded,
                          size: 65,
                          color: Colors
                              .blueAccent,
                        ),

                        SizedBox(
                          height: 10,
                        ),

                        Text(
                          'Live Safety Map',
                          style:
                          TextStyle(
                            fontSize:
                            20,
                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),

                        Text(
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
  // HELPERS
  // ============================================================

  Widget _sectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
        ),

        const SizedBox(
          width: 8,
        ),

        Text(
          title,
          style:
          const TextStyle(
            fontSize: 18,
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      borderRadius:
      BorderRadius.circular(
        20,
      ),
      color: Theme.of(context)
          .colorScheme
          .surfaceContainer,
      border: Border.all(
        color: Theme.of(context)
            .colorScheme
            .outlineVariant,
      ),
    );
  }

  Widget _miniRiskStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
        ),
        const SizedBox(
          height: 5,
        ),
        Text(
          value,
          style:
          const TextStyle(
            fontSize: 20,
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
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _dataHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 30,
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,
            children: [
              Text(
                title,
                style:
                const TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight
                      .bold,
                ),
              ),

              Text(
                subtitle,
                style:
                const TextStyle(
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dataStat(
      String label,
      String value,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style:
          const TextStyle(
            fontSize: 27,
            fontWeight:
            FontWeight.bold,
          ),
        ),
        Text(
          label,
          style:
          const TextStyle(
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _categoryRow(
      String label,
      int value,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
            ),
          ),
          Text(
            '$value',
            style:
            const TextStyle(
              fontWeight:
              FontWeight
                  .bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _communityStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding:
      const EdgeInsets.all(
        17,
      ),
      decoration:
      _cardDecoration(),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const Spacer(),
          Text(
            value,
            style:
            const TextStyle(
              fontSize: 25,
              fontWeight:
              FontWeight.bold,
            ),
          ),
          Text(
            label,
            style:
            const TextStyle(
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileOption({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding:
      const EdgeInsets
          .symmetric(
        horizontal: 4,
        vertical: 2,
      ),
      leading:
      Icon(icon),
      title:
      Text(title),
      subtitle:
      subtitle != null
          ? Text(
        subtitle,
        style:
        const TextStyle(
          fontSize: 11,
        ),
      )
          : null,
      trailing:
      const Icon(
        Icons
            .chevron_right_rounded,
      ),
      onTap: onTap,
    );
  }

  Color _riskColor() {
    switch (
    _riskLevel.toUpperCase()) {
      case 'HIGH':
        return Colors.red;

      case 'MODERATE':
      case 'MEDIUM':
        return Colors.orange;

      default:
        return Colors.green;
    }
  }

  String _riskDescription() {
    switch (
    _riskLevel.toUpperCase()) {
      case 'HIGH':
        return 'Higher historical risk detected. Stay alert and avoid isolated areas.';

      case 'MODERATE':
      case 'MEDIUM':
        return 'Moderate historical risk detected. Remain aware of your surroundings.';

      default:
        return 'This area currently shows a relatively low historical safety risk.';
    }
  }
}

// ============================================================
// TEMPORARY MAP
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
      ..color = Colors.grey
          .withOpacity(
        0.15,
      )
      ..strokeWidth = 1.5;

    final roadPaint =
    Paint()
      ..color = Colors.grey
          .withOpacity(
        0.28,
      )
      ..strokeWidth = 5
      ..style =
          PaintingStyle
              .stroke;

    for (
    double y = 30;
    y < size.height;
    y += 45
    ) {
      canvas.drawLine(
        Offset(0, y),
        Offset(
          size.width,
          y,
        ),
        gridPaint,
      );
    }

    for (
    double x = 35;
    x < size.width;
    x += 55
    ) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(
          x,
          size.height,
        ),
        gridPaint,
      );
    }

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
      covariant CustomPainter
      oldDelegate,
      ) {
    return false;
  }
}