import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';
import 'personal_information_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  int _currentIndex = 0;

  // ============================================================
  // TEMPORARY DATA
  // Later replace with GPS / data.gov.my / Supabase.
  // ============================================================

  String _locationName = 'Detecting your location...';
  String _district = 'Location not available yet';

  String _riskLevel = 'LOW';
  int _riskScore = 24;

  int _historicalCases = 0;
  int _nearbyIncidents = 0;

  // ============================================================
  // USER
  // ============================================================

  User? get _currentUser => supabase.auth.currentUser;

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

  // ============================================================
  // REFRESH HOME
  // ============================================================

  Future<void> _refreshHome() async {
    // Later:
    // GPS
    // District
    // data.gov.my
    // Risk calculation
    // Nearby SafeZone incidents

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Safety information refreshed.')),
    );
  }

  // ============================================================
  // PERSONAL INFORMATION
  // ============================================================

  Future<void> _openPersonalInformation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonalInformationScreen()),
    );

    // Refresh Home/Profile after user changes name,
    // email or personal information.
    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // SOS
  // ============================================================

  void _startSOS() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 24),

                const Icon(
                  Icons.sos_rounded,
                  size: 72,
                  color: Colors.redAccent,
                ),

                const SizedBox(height: 15),

                const Text(
                  'Emergency SOS',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Are you sure you need emergency assistance?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Your location will be shared with verified '
                  'SafeZone users nearby.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context);

                      // TODO:
                      // Later connect real SOS function here.

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('SOS function will be connected next.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text(
                      'Confirm SOS',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
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
    try {
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to logout. Please try again.')),
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
          _buildSafetyDataPage(),
          _buildActivityPage(),
          _buildProfilePage(),
        ],
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),

          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded),
            label: 'Safety Data',
          ),

          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Activity',
          ),

          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
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
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
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
                    borderRadius: BorderRadius.circular(15),
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.15),
                  ),
                  child: Icon(
                    Icons.shield_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $_userName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 2),

                      const Text(
                        'Stay aware. Stay safe.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _refreshHome,
                  icon: const Icon(Icons.refresh_rounded),
                ),

                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () {},
                  icon: Badge(
                    isLabelVisible: _nearbyIncidents > 0,
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ==================================================
            // CURRENT AREA + RISK
            // ==================================================
            _sectionTitle(
              icon: Icons.location_on_outlined,
              title: 'Your Current Area',
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.withOpacity(0.12),
                        ),
                        child: const Icon(
                          Icons.my_location_rounded,
                          color: Colors.blue,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _locationName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              _district,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(Icons.gps_fixed_rounded),
                    ],
                  ),

                  const SizedBox(height: 22),

                  Divider(color: Theme.of(context).colorScheme.outlineVariant),

                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Safety Risk',
                              style: TextStyle(fontSize: 13),
                            ),

                            const SizedBox(height: 6),

                            Row(
                              children: [
                                Container(
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _riskColor(),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                Text(
                                  _riskLevel,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: _riskColor(),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Risk Score',
                            style: TextStyle(fontSize: 12),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            '$_riskScore / 100',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 17),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: _riskScore / 100,
                      minHeight: 7,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      color: _riskColor(),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: _miniRiskStat(
                          label: 'Historical Cases',
                          value: '$_historicalCases',
                          icon: Icons.bar_chart_rounded,
                        ),
                      ),

                      Container(
                        width: 1,
                        height: 42,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),

                      Expanded(
                        child: _miniRiskStat(
                          label: 'Active Incidents',
                          value: '$_nearbyIncidents',
                          icon: Icons.warning_amber_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16),

                      const SizedBox(width: 7),

                      Expanded(
                        child: Text(
                          _riskDescription(),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // SOS
            // ==================================================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                gradient: LinearGradient(
                  colors: [
                    Colors.redAccent.withOpacity(0.18),
                    Colors.redAccent.withOpacity(0.04),
                  ],
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Need Emergency Help?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Send an emergency alert to verified '
                    'SafeZone users nearby.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),

                  const SizedBox(height: 18),

                  GestureDetector(
                    onTap: _startSOS,
                    child: Container(
                      width: 125,
                      height: 125,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.redAccent,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.30),
                            blurRadius: 24,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sos_rounded,
                            size: 46,
                            color: Colors.white,
                          ),

                          SizedBox(height: 2),

                          Text(
                            'EMERGENCY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    'Tap SOS only when assistance is required.',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // NEARBY ALERTS
            // ==================================================
            _sectionTitle(
              icon: Icons.crisis_alert_outlined,
              title: 'Nearby Alerts',
            ),

            const SizedBox(height: 10),

            if (_nearbyIncidents == 0)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color.fromARGB(35, 76, 175, 80),
                      child: Icon(Icons.check_rounded, color: Colors.green),
                    ),

                    SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No active incidents nearby',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),

                          SizedBox(height: 4),

                          Text(
                            'No SafeZone emergency alerts '
                            'within 1 km.',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              _buildIncidentCard(),

            const SizedBox(height: 24),

            // ==================================================
            // MAP
            // ==================================================
            Row(
              children: [
                Expanded(
                  child: _sectionTitle(
                    icon: Icons.map_outlined,
                    title: 'Safety Map',
                  ),
                ),

                TextButton(
                  onPressed: _openFullMap,
                  child: const Text('View Full Map'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _openFullMap,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  color: Theme.of(context).colorScheme.surfaceContainer,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _MapBackgroundPainter()),
                      ),

                      const Center(
                        child: Icon(
                          Icons.location_on_rounded,
                          size: 48,
                          color: Colors.blueAccent,
                        ),
                      ),

                      Positioned(
                        left: 14,
                        top: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Live Safety Map',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
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
  // SAFETY DATA PAGE
  // ============================================================

  Widget _buildSafetyDataPage() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          const Text(
            'Safety Data',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 5),

          const Text(
            'Historical safety information and '
            'SafeZone community statistics.',
            style: TextStyle(fontSize: 13),
          ),

          const SizedBox(height: 28),

          // ====================================================
          // GOVERNMENT DATA
          // ====================================================
          _dataHeader(
            icon: Icons.account_balance_outlined,
            title: 'Government Data',
            subtitle: 'Source: data.gov.my',
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Historical Crime Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 4),

                const Text(
                  'Historical crime statistics for '
                  'your selected area.',
                  style: TextStyle(fontSize: 12),
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: _dataStat('Historical Cases', '$_historicalCases'),
                    ),

                    Expanded(child: _dataStat('Risk Score', '$_riskScore')),
                  ],
                ),

                const SizedBox(height: 22),

                Container(
                  height: 190,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.show_chart_rounded, size: 46),

                      SizedBox(height: 10),

                      Text(
                        'Historical Crime Trend',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),

                      SizedBox(height: 4),

                      Text(
                        'data.gov.my chart will appear here',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Crime Categories',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 12),

                _categoryRow('Violent Crime', 0),

                _categoryRow('Property Crime', 0),

                _categoryRow('Other Reported Cases', 0),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // ====================================================
          // SAFEZONE COMMUNITY
          // ====================================================
          _dataHeader(
            icon: Icons.shield_outlined,
            title: 'SafeZone Community',
            subtitle: 'Live statistics generated by SafeZone',
          ),

          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _communityStatCard(
                icon: Icons.sos_rounded,
                value: '0',
                label: 'Total SOS',
              ),

              _communityStatCard(
                icon: Icons.warning_amber_rounded,
                value: '0',
                label: 'Active Incidents',
              ),

              _communityStatCard(
                icon: Icons.check_circle_outline,
                value: '0',
                label: 'Resolved',
              ),

              _communityStatCard(
                icon: Icons.volunteer_activism_outlined,
                value: '0',
                label: 'Users Assisted',
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SafeZone Activity Trend',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Community SOS and response activity.',
                  style: TextStyle(fontSize: 12),
                ),

                const SizedBox(height: 20),

                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.insights_rounded, size: 45),

                      SizedBox(height: 10),

                      Text(
                        'SafeZone Statistics Chart',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),

                      SizedBox(height: 4),

                      Text(
                        'Live Supabase data will appear here',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
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
  // ACTIVITY PAGE
  // ============================================================

  Widget _buildActivityPage() {
    // Later:
    // SQLite + Supabase history.

    final activities = <Map<String, String>>[];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          const Text(
            'Activity',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 5),

          const Text(
            'Your previous SafeZone requests and assistance.',
            style: TextStyle(fontSize: 13),
          ),

          const SizedBox(height: 25),

          if (activities.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
              decoration: _cardDecoration(),
              child: const Column(
                children: [
                  Icon(Icons.history_rounded, size: 58),

                  SizedBox(height: 16),

                  Text(
                    'No activity yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),

                  SizedBox(height: 7),

                  Text(
                    'Your SOS requests and incidents '
                    'you responded to will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ...activities.map((activity) {
              return _activityCard(
                title: activity['title'] ?? '',
                location: activity['location'] ?? '',
                status: activity['status'] ?? '',
                time: activity['time'] ?? '',
                type: activity['type'] ?? '',
              );
            }),
        ],
      ),
    );
  }

  // ============================================================
  // PROFILE PAGE
  // ============================================================

  Widget _buildProfilePage() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          const Text(
            'Profile',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 28),

          Center(
            child: CircleAvatar(
              radius: 48,
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          Text(
            _userName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          Text(_userEmail, textAlign: TextAlign.center),

          const SizedBox(height: 30),

          // ====================================================
          // PERSONAL INFORMATION - WORKING
          // ====================================================
          _profileOption(
            icon: Icons.person_outline,
            title: 'Personal Information',
            subtitle: 'Name, phone, email and password',
            onTap: _openPersonalInformation,
          ),

          // ====================================================
          // DEVICE BINDING - NEXT
          // ====================================================
          _profileOption(
            icon: Icons.devices_outlined,
            title: 'Registered Device',
            subtitle: 'Device binding and security',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Device Binding will be connected next.'),
                ),
              );
            },
          ),

          // ====================================================
          // NOTIFICATIONS - LATER
          // ====================================================
          _profileOption(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Notification preferences',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Notification settings will be available soon.',
                  ),
                ),
              );
            },
          ),

          // ====================================================
          // PRIVACY - LATER STATIC PAGE
          // ====================================================
          _profileOption(
            icon: Icons.security_outlined,
            title: 'Privacy & Security',
            subtitle: 'Account and safety information',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Privacy & Security information will be added later.',
                  ),
                ),
              );
            },
          ),

          // ====================================================
          // HELP - LATER STATIC PAGE
          // ====================================================
          _profileOption(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            subtitle: 'SafeZone guides and support',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Help & Support information will be added later.',
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 22),

          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout'),
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
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Safety Map')),
          body: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _MapBackgroundPainter()),
              ),

              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 65,
                      color: Colors.blueAccent,
                    ),

                    SizedBox(height: 12),

                    Text(
                      'Live Safety Map',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 5),

                    Text('Real map integration will be connected here.'),
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

  Widget _sectionTitle({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 20),

        const SizedBox(width: 8),

        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).colorScheme.surfaceContainer,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    );
  }

  Widget _miniRiskStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20),

        const SizedBox(height: 5),

        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 2),

        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10),
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
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: Theme.of(context).colorScheme.primary.withOpacity(0.13),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),

        const SizedBox(width: 13),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 2),

              Text(subtitle, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dataStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 3),

        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _categoryRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),

          Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 25),

          const Spacer(),

          Text(
            value,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),

          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _activityCard({
    required String title,
    required String location,
    required String status,
    required String time,
    required String type,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            child: Icon(
              type == 'helped' ? Icons.volunteer_activism : Icons.sos_rounded,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 4),

                Text(location, style: const TextStyle(fontSize: 12)),

                const SizedBox(height: 6),

                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Text(time, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildIncidentCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.redAccent,
            child: Icon(Icons.warning_rounded, color: Colors.white),
          ),

          SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency Alert',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                SizedBox(height: 4),

                Text(
                  'Nearby incident information '
                  'will appear here.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 11))
          : null,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  // ============================================================
  // RISK
  // ============================================================

  Color _riskColor() {
    switch (_riskLevel.toUpperCase()) {
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
    switch (_riskLevel.toUpperCase()) {
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
// TEMPORARY MAP BACKGROUND
// Later replace with real map.
// ============================================================

class _MapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1.5;

    final roadPaint = Paint()
      ..color = Colors.grey.withOpacity(0.28)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    for (double y = 30; y < size.height; y += 45) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (double x = 35; x < size.width; x += 55) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final road = Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.35,
        size.width * 0.58,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.75,
        size.width,
        size.height * 0.28,
      );

    canvas.drawPath(road, roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
