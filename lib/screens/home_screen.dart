import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  int _currentIndex = 0;

  // ============================================================
  // TEMPORARY HOME DATA
  // Later:
  // Location        -> GPS
  // Risk            -> data.gov.my + risk calculation
  // Incidents       -> Supabase
  // Map             -> Google Maps / Flutter Map
  // SOS             -> Supabase + Live GPS
  // ============================================================

  String _locationName = 'Detecting your location...';
  String _district = 'Location not available yet';

  String _riskLevel = 'LOW';
  int _riskScore = 24;

  int _nearbyIncidents = 0;
  int _historicalCases = 0;

  bool _locationEnabled = false;

  // ============================================================
  // USER INFORMATION
  // ============================================================

  User? get _currentUser => supabase.auth.currentUser;

  String get _userName {
    final user = _currentUser;

    if (user == null) {
      return 'User';
    }

    final metadataName =
    user.userMetadata?['full_name']?.toString().trim();

    if (metadataName != null && metadataName.isNotEmpty) {
      return metadataName;
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

  // ============================================================
  // FUTURE FUNCTIONS
  // ============================================================

  Future<void> _refreshHome() async {
    // Later:
    // 1. Get GPS
    // 2. Determine district
    // 3. Fetch historical crime data
    // 4. Calculate risk score
    // 5. Fetch nearby SafeZone incidents

    await Future.delayed(
      const Duration(milliseconds: 600),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Safety information refreshed.',
        ),
      ),
    );
  }

  void _openFullMap() {
    setState(() {
      _currentIndex = 1;
    });
  }

  void _startSOS() {
    // Later connect to SOS flow.

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              20,
              24,
              30,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius:
                    BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 24),

                const Icon(
                  Icons.sos_rounded,
                  size: 70,
                  color: Colors.redAccent,
                ),

                const SizedBox(height: 16),

                const Text(
                  'Emergency SOS',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Your emergency alert will be sent together '
                      'with your live location to nearby SafeZone users.',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'SOS function will be connected next.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.warning_amber_rounded,
                    ),
                    label: const Text(
                      'Activate SOS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
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

  Future<void> _logout() async {
    try {
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
            (route) => false,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to logout. Please try again.',
          ),
        ),
      );
    }
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
          _buildMapPage(),
          _buildActivityPage(),
          _buildProfilePage(),
        ],
      ),

      // ========================================================
      // BOTTOM NAVIGATION
      // ========================================================

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
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
              Icons.map_outlined,
            ),
            selectedIcon: Icon(
              Icons.map_rounded,
            ),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.history_outlined,
            ),
            selectedIcon: Icon(
              Icons.history_rounded,
            ),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),
            selectedIcon: Icon(
              Icons.person,
            ),
            label: 'Profile',
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
      child: RefreshIndicator(
        onRefresh: _refreshHome,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
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
                  decoration: BoxDecoration(
                    borderRadius:
                    BorderRadius.circular(14),
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(
                      alpha: 0.15,
                    ),
                  ),
                  child: Icon(
                    Icons.shield_rounded,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $_userName',
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 2),

                      const Text(
                        'Stay aware. Stay safe.',
                        style: TextStyle(
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _refreshHome,
                  icon: const Icon(
                    Icons.refresh_rounded,
                  ),
                ),

                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () {},
                  icon: Badge(
                    isLabelVisible:
                    _nearbyIncidents > 0,
                    child: const Icon(
                      Icons.notifications_none_rounded,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            // ==================================================
            // CURRENT LOCATION
            // ==================================================

            _sectionTitle(
              title: 'Current Location',
              icon: Icons.location_on_outlined,
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: _cardDecoration(context),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue
                          .withValues(
                        alpha: 0.12,
                      ),
                    ),
                    child: const Icon(
                      Icons.my_location_rounded,
                      color: Colors.blue,
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          _locationName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          _district,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    _locationEnabled
                        ? Icons.gps_fixed_rounded
                        : Icons.gps_not_fixed_rounded,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // RISK STATUS
            // ==================================================

            _sectionTitle(
              title: 'Safety Risk',
              icon: Icons.health_and_safety_outlined,
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: _cardDecoration(context),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Risk Level',
                              style: TextStyle(
                                fontSize: 13,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration:
                                  BoxDecoration(
                                    shape:
                                    BoxShape.circle,
                                    color:
                                    _riskColor(),
                                  ),
                                ),

                                const SizedBox(
                                  width: 9,
                                ),

                                Text(
                                  _riskLevel,
                                  style: TextStyle(
                                    fontSize: 25,
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

                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: 7,
                            color: _riskColor()
                                .withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            Text(
                              '$_riskScore',
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),
                            const Text(
                              '/100',
                              style: TextStyle(
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  ClipRRect(
                    borderRadius:
                    BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value:
                      _riskScore / 100,
                      minHeight: 8,
                      backgroundColor:
                      Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      color: _riskColor(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 17,
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          _riskDescription(),
                          style: const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // STATS
            // ==================================================

            Row(
              children: [
                Expanded(
                  child: _smallStatCard(
                    icon:
                    Icons.warning_amber_rounded,
                    title: 'Nearby',
                    value:
                    '$_nearbyIncidents',
                    subtitle:
                    'Active incidents',
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _smallStatCard(
                    icon:
                    Icons.analytics_outlined,
                    title: 'Historical',
                    value:
                    '$_historicalCases',
                    subtitle:
                    'Reported cases',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ==================================================
            // MAP PREVIEW
            // ==================================================

            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle(
                  title: 'Safety Map',
                  icon: Icons.map_outlined,
                ),

                TextButton(
                  onPressed: _openFullMap,
                  child: const Text(
                    'View Map',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            InkWell(
              borderRadius:
              BorderRadius.circular(20),
              onTap: _openFullMap,
              child: Container(
                height: 210,
                decoration: BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context)
                          .colorScheme
                          .surfaceContainer,
                      Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius:
                        BorderRadius.circular(
                          20,
                        ),
                        child: CustomPaint(
                          painter:
                          _MapBackgroundPainter(),
                        ),
                      ),
                    ),

                    const Center(
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 50,
                        color: Colors.blueAccent,
                      ),
                    ),

                    Positioned(
                      left: 15,
                      top: 15,
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration:
                        BoxDecoration(
                          color: Colors.black
                              .withValues(
                            alpha: 0.65,
                          ),
                          borderRadius:
                          BorderRadius.circular(
                            12,
                          ),
                        ),
                        child: const Text(
                          'Live Safety Map',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      right: 15,
                      bottom: 15,
                      child: Container(
                        padding:
                        const EdgeInsets.all(
                          10,
                        ),
                        decoration:
                        BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fullscreen_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // NEARBY INCIDENT
            // ==================================================

            _sectionTitle(
              title: 'Nearby Incidents',
              icon: Icons.crisis_alert_outlined,
            ),

            const SizedBox(height: 10),

            if (_nearbyIncidents == 0)
              Container(
                padding: const EdgeInsets.all(22),
                decoration:
                _cardDecoration(context),
                child: const Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 40,
                      color: Colors.green,
                    ),

                    SizedBox(height: 10),

                    Text(
                      'No active incidents nearby',
                      style: TextStyle(
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    SizedBox(height: 5),

                    Text(
                      'No SafeZone emergency alerts '
                          'have been detected within 1 km.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              _incidentCard(),

            const SizedBox(height: 26),

            // ==================================================
            // SOS
            // ==================================================

            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius:
                BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    Colors.redAccent
                        .withValues(
                      alpha: 0.20,
                    ),
                    Colors.redAccent
                        .withValues(
                      alpha: 0.06,
                    ),
                  ],
                ),
                border: Border.all(
                  color: Colors.redAccent
                      .withValues(
                    alpha: 0.35,
                  ),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Need Emergency Help?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Activate SOS to notify verified '
                        'SafeZone users near you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: _startSOS,
                    child: Container(
                      width: 135,
                      height: 135,
                      decoration:
                      BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                        Colors.redAccent,
                        boxShadow: [
                          BoxShadow(
                            color:
                            Colors.redAccent
                                .withValues(
                              alpha:
                              0.35,
                            ),
                            blurRadius: 25,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      alignment:
                      Alignment.center,
                      child: const Column(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                        children: [
                          Icon(
                            Icons.sos_rounded,
                            color:
                            Colors.white,
                            size: 46,
                          ),
                          SizedBox(height: 3),
                          Text(
                            'EMERGENCY',
                            style: TextStyle(
                              color:
                              Colors.white,
                              fontSize: 11,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Tap SOS only when assistance is required.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MAP PAGE
  // ============================================================

  Widget _buildMapPage() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              12,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Safety Map',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),

                IconButton(
                  onPressed: _refreshHome,
                  icon: const Icon(
                    Icons.refresh_rounded,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    margin:
                    const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      16,
                    ),
                    decoration:
                    BoxDecoration(
                      borderRadius:
                      BorderRadius.circular(
                        24,
                      ),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainer,
                    ),
                    child: ClipRRect(
                      borderRadius:
                      BorderRadius.circular(
                        24,
                      ),
                      child: CustomPaint(
                        painter:
                        _MapBackgroundPainter(),
                      ),
                    ),
                  ),
                ),

                const Center(
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 65,
                        color:
                        Colors.blueAccent,
                      ),

                      SizedBox(height: 10),

                      Text(
                        'Map Integration Ready',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 5),

                      Text(
                        'Live map will be connected here.',
                      ),
                    ],
                  ),
                ),

                Positioned(
                  left: 30,
                  right: 30,
                  bottom: 32,
                  child: Container(
                    padding:
                    const EdgeInsets.all(
                      14,
                    ),
                    decoration:
                    BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(
                        alpha: 0.95,
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        18,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .spaceAround,
                      children: [
                        _LegendItem(
                          color:
                          Colors.green,
                          text: 'Low',
                        ),
                        _LegendItem(
                          color:
                          Colors.orange,
                          text:
                          'Moderate',
                        ),
                        _LegendItem(
                          color: Colors.red,
                          text: 'High',
                        ),
                      ],
                    ),
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
  // ACTIVITY
  // ============================================================

  Widget _buildActivityPage() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Activity',
            style: TextStyle(
              fontSize: 25,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Your SafeZone activity and SOS history.',
          ),

          const SizedBox(height: 24),

          _activityTile(
            icon:
            Icons.sos_outlined,
            title: 'SOS History',
            subtitle:
            'Emergency alerts you have created.',
          ),

          const SizedBox(height: 12),

          _activityTile(
            icon:
            Icons.volunteer_activism_outlined,
            title: 'Assistance History',
            subtitle:
            'Incidents where you offered help.',
          ),

          const SizedBox(height: 12),

          _activityTile(
            icon:
            Icons.location_history,
            title: 'Safety History',
            subtitle:
            'Previously viewed safety areas.',
          ),

          const SizedBox(height: 40),

          const Center(
            child: Column(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 55,
                ),
                SizedBox(height: 12),
                Text(
                  'No activity yet',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                    FontWeight.w600,
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
  // PROFILE
  // ============================================================

  Widget _buildProfilePage() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Profile',
            style: TextStyle(
              fontSize: 25,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(height: 25),

          Center(
            child: CircleAvatar(
              radius: 48,
              child: Text(
                _userName.isNotEmpty
                    ? _userName[0]
                    .toUpperCase()
                    : 'U',
                style:
                const TextStyle(
                  fontSize: 35,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          Text(
            _userName,
            textAlign:
            TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            _userEmail,
            textAlign:
            TextAlign.center,
          ),

          const SizedBox(height: 30),

          _profileOption(
            icon:
            Icons.person_outline,
            title:
            'Personal Information',
          ),

          _profileOption(
            icon:
            Icons.devices_outlined,
            title:
            'Registered Device',
          ),

          _profileOption(
            icon:
            Icons.notifications_outlined,
            title:
            'Notifications',
          ),

          _profileOption(
            icon:
            Icons.security_outlined,
            title:
            'Privacy & Security',
          ),

          _profileOption(
            icon:
            Icons.help_outline,
            title:
            'Help & Support',
          ),

          const SizedBox(height: 22),

          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(
              Icons.logout_rounded,
            ),
            label: const Text(
              'Logout',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPER WIDGETS
  // ============================================================

  Widget _sectionTitle({
    required String title,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
        ),

        const SizedBox(width: 8),

        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration(
      BuildContext context,
      ) {
    return BoxDecoration(
      borderRadius:
      BorderRadius.circular(20),
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

  Widget _smallStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding:
      const EdgeInsets.all(16),
      decoration:
      _cardDecoration(context),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 24,
          ),

          const SizedBox(height: 12),

          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            title,
            style: const TextStyle(
              fontWeight:
              FontWeight.w600,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _incidentCard() {
    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration:
      _cardDecoration(context),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor:
            Colors.redAccent,
            child: Icon(
              Icons.warning_rounded,
              color: Colors.white,
            ),
          ),

          SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency Alert',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                SizedBox(height: 3),

                Text(
                  'Incident information will appear here.',
                  style: TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      decoration:
      _cardDecoration(context),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          subtitle,
        ),
        trailing:
        const Icon(
          Icons.chevron_right,
        ),
        onTap: () {},
      ),
    );
  }

  Widget _profileOption({
    required IconData icon,
    required String title,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing:
      const Icon(
        Icons.chevron_right,
      ),
      onTap: () {},
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
        return 'Higher historical risk detected. '
            'Stay alert and avoid isolated areas.';
      case 'MODERATE':
      case 'MEDIUM':
        return 'Moderate historical risk detected. '
            'Remain aware of your surroundings.';
      default:
        return 'This area currently shows a relatively '
            'low historical safety risk.';
    }
  }
}

// ============================================================
// MAP LEGEND
// ============================================================

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
          BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// TEMPORARY MAP BACKGROUND
//
// Later replace ONLY this map area with GoogleMap / FlutterMap.
// The Home layout does not need to be redesigned.
// ============================================================

class _MapBackgroundPainter
    extends CustomPainter {
  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final paint = Paint()
      ..color =
      Colors.grey.withValues(
        alpha: 0.16,
      )
      ..strokeWidth = 2;

    final roadPaint = Paint()
      ..color =
      Colors.grey.withValues(
        alpha: 0.28,
      )
      ..strokeWidth = 5
      ..style =
          PaintingStyle.stroke;

    for (double y = 30;
    y < size.height;
    y += 45) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    for (double x = 35;
    x < size.width;
    x += 55) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    final path = Path()
      ..moveTo(
        0,
        size.height * 0.75,
      )
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.40,
        size.width * 0.55,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.75,
        size.width,
        size.height * 0.30,
      );

    canvas.drawPath(
      path,
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