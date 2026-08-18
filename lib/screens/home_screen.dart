import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,

      body: SafeArea(
        child: Stack(
          children: [
            _buildBackgroundGlow(),

            Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      _buildHomePage(),
                      _buildMapPlaceholder(),
                      _buildAlertsPlaceholder(),
                      _buildProfilePlaceholder(),
                    ],
                  ),
                ),

                _buildBottomNavigation(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BACKGROUND
  // ============================================================

  Widget _buildBackgroundGlow() {
    return Positioned(
      top: -100,
      right: -100,
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.purple.withOpacity(0.10),
          boxShadow: [
            BoxShadow(
              color: AppTheme.purple.withOpacity(0.12),
              blurRadius: 120,
              spreadRadius: 50,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HOME
  // ============================================================

  Widget _buildHomePage() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(
          const Duration(milliseconds: 500),
        );
      },

      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24,
        ),

        children: [
          _buildHeader(),

          const SizedBox(height: 24),

          _buildLocationRow(),

          const SizedBox(height: 20),

          _buildRiskCard(),

          const SizedBox(height: 20),

          _buildMapCard(),

          const SizedBox(height: 24),

          _buildNearbyHeader(),

          const SizedBox(height: 14),

          _buildAlertCard(
            crimeType: 'Robbery',
            distance: '320 m',
            time: '2 min ago',
            color: AppTheme.emergencyRed,
            icon: Icons.warning_rounded,
          ),

          const SizedBox(height: 12),

          _buildAlertCard(
            crimeType: 'Suspicious Activity',
            distance: '740 m',
            time: '6 min ago',
            color: AppTheme.riskOrange,
            icon: Icons.visibility_rounded,
          ),

          const SizedBox(height: 30),

          _buildSosButton(),

          const SizedBox(height: 10),

          const Center(
            child: Text(
              'Tap for immediate emergency assistance',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),

            gradient: const LinearGradient(
              colors: [
                AppTheme.purple,
                AppTheme.cyan,
              ],
            ),

            boxShadow: [
              BoxShadow(
                color: AppTheme.purple.withOpacity(0.3),
                blurRadius: 18,
              ),
            ],
          ),

          child: const Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),

        const SizedBox(width: 12),

        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                'SafeZone MY',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),

              SizedBox(height: 2),

              Text(
                'Safer communities. Smarter response.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),

        _headerIcon(
          icon: Icons.notifications_none_rounded,
          showBadge: true,
        ),

        const SizedBox(width: 8),

        _headerIcon(
          icon: Icons.person_outline_rounded,
        ),
      ],
    );
  }

  Widget _headerIcon({
    required IconData icon,
    bool showBadge = false,
  }) {
    return Stack(
      clipBehavior: Clip.none,

      children: [
        Container(
          width: 42,
          height: 42,

          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),

            border: Border.all(
              color: const Color(0xFF25304B),
            ),
          ),

          child: Icon(
            icon,
            size: 21,
            color: Colors.white,
          ),
        ),

        if (showBadge)
          Positioned(
            top: -2,
            right: -2,

            child: Container(
              width: 10,
              height: 10,

              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.emergencyRed,

                border: Border.all(
                  color: AppTheme.background,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // LOCATION
  // ============================================================

  Widget _buildLocationRow() {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,

          decoration: BoxDecoration(
            color: AppTheme.cyan.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),

          child: const Icon(
            Icons.location_on_rounded,
            color: AppTheme.cyan,
            size: 18,
          ),
        ),

        const SizedBox(width: 10),

        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                'Current location',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),

              SizedBox(height: 2),

              Text(
                'Petaling Jaya, Selangor',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        TextButton(
          onPressed: () {},

          child: const Text(
            'Refresh',
            style: TextStyle(
              color: AppTheme.cyan,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // RISK CARD
  // ============================================================

  Widget _buildRiskCard() {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),

        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,

          colors: [
            Color(0xFF17172D),
            Color(0xFF121529),
          ],
        ),

        border: Border.all(
          color: AppTheme.riskOrange.withOpacity(0.45),
        ),

        boxShadow: [
          BoxShadow(
            color: AppTheme.riskOrange.withOpacity(0.08),
            blurRadius: 30,
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color: AppTheme.riskOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),

                child: const Row(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      color: AppTheme.riskOrange,
                      size: 15,
                    ),

                    SizedBox(width: 6),

                    Text(
                      'HISTORICAL SAFETY',
                      style: TextStyle(
                        color: AppTheme.riskOrange,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppTheme.textSecondary,
                size: 14,
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Row(
            crossAxisAlignment: CrossAxisAlignment.end,

            children: [
              Text(
                'HIGH',
                style: TextStyle(
                  color: AppTheme.riskOrange,
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                ),
              ),

              SizedBox(width: 10),

              Padding(
                padding: EdgeInsets.only(bottom: 5),

                child: Text(
                  'RISK',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          const Text(
            'Property crime is currently the most reported '
                'historical category in this district.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              height: 1.5,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              _riskTag(
                'Property Crime',
                AppTheme.riskOrange,
              ),

              const SizedBox(width: 8),

              _riskTag(
                'Official Data',
                AppTheme.cyan,
              ),
            ],
          ),

          const SizedBox(height: 12),

          const Row(
            children: [
              Icon(
                Icons.verified_rounded,
                color: AppTheme.safeGreen,
                size: 14,
              ),

              SizedBox(width: 6),

              Text(
                'Based on data.gov.my historical statistics',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _riskTag(
      String label,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),

      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),

        border: Border.all(
          color: color.withOpacity(0.25),
        ),
      ),

      child: Text(
        label,

        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================================
  // MAP CARD
  // ============================================================

  Widget _buildMapCard() {
    return Container(
      height: 260,

      clipBehavior: Clip.antiAlias,

      decoration: BoxDecoration(
        color: const Color(0xFF0A1020),

        borderRadius: BorderRadius.circular(24),

        border: Border.all(
          color: const Color(0xFF26324F),
        ),
      ),

      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MapPreviewPainter(),
            ),
          ),

          // 1 KM RADIUS

          Center(
            child: Container(
              width: 170,
              height: 170,

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                color: AppTheme.cyan.withOpacity(0.03),

                border: Border.all(
                  color: AppTheme.cyan.withOpacity(0.25),
                ),
              ),
            ),
          ),

          // Current location

          Center(
            child: Container(
              width: 22,
              height: 22,

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                color: AppTheme.cyan,

                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),

                boxShadow: [
                  BoxShadow(
                    color: AppTheme.cyan.withOpacity(0.7),
                    blurRadius: 16,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),

          const Positioned(
            top: 30,
            right: 40,

            child: _CrimeMarker(
              color: AppTheme.emergencyRed,
              icon: Icons.warning_rounded,
            ),
          ),

          const Positioned(
            bottom: 50,
            left: 45,

            child: _CrimeMarker(
              color: AppTheme.riskOrange,
              icon: Icons.visibility_rounded,
            ),
          ),

          const Positioned(
            bottom: 40,
            right: 75,

            child: _CrimeMarker(
              color: AppTheme.emergencyRed,
              icon: Icons.warning_rounded,
            ),
          ),

          // 1km label

          Positioned(
            top: 18,
            left: 18,

            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),

              decoration: BoxDecoration(
                color: AppTheme.background.withOpacity(0.85),

                borderRadius: BorderRadius.circular(12),

                border: Border.all(
                  color: const Color(0xFF283551),
                ),
              ),

              child: const Row(
                children: [
                  Icon(
                    Icons.radar_rounded,
                    size: 15,
                    color: AppTheme.cyan,
                  ),

                  SizedBox(width: 6),

                  Text(
                    '1 km safety radius',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Full map button

          Positioned(
            right: 14,
            bottom: 14,

            child: Container(
              width: 42,
              height: 42,

              decoration: BoxDecoration(
                color: AppTheme.surface,

                borderRadius: BorderRadius.circular(13),

                border: Border.all(
                  color: const Color(0xFF2C3854),
                ),
              ),

              child: const Icon(
                Icons.open_in_full_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NEARBY ALERTS
  // ============================================================

  Widget _buildNearbyHeader() {
    return const Row(
      children: [
        Text(
          'Nearby Alerts',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        Spacer(),

        Text(
          '2 active',
          style: TextStyle(
            color: AppTheme.emergencyRed,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertCard({
    required String crimeType,
    required String distance,
    required String time,
    required Color color,
    required IconData icon,
  }) {
    return InkWell(
      onTap: () {},

      borderRadius: BorderRadius.circular(18),

      child: Container(
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: AppTheme.surface,

          borderRadius: BorderRadius.circular(18),

          border: Border.all(
            color: color.withOpacity(0.25),
          ),
        ),

        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,

              decoration: BoxDecoration(
                color: color.withOpacity(0.12),

                borderRadius: BorderRadius.circular(14),
              ),

              child: Icon(
                icon,
                color: color,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    crimeType,

                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    '$distance  •  $time',

                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SOS
  // ============================================================

  Widget _buildSosButton() {
    return GestureDetector(
      onTap: () {
        _showEmergencyTypeSheet();
      },

      child: Center(
        child: Container(
          width: 148,
          height: 148,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            gradient: const RadialGradient(
              colors: [
                Color(0xFFFF6278),
                AppTheme.emergencyRed,
                Color(0xFFCF1736),
              ],
            ),

            border: Border.all(
              color: const Color(0xFFFF8798),
              width: 3,
            ),

            boxShadow: [
              BoxShadow(
                color: AppTheme.emergencyRed.withOpacity(0.35),
                blurRadius: 35,
                spreadRadius: 7,
              ),
            ],
          ),

          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Icon(
                Icons.sos_rounded,
                size: 40,
                color: Colors.white,
              ),

              SizedBox(height: 4),

              Text(
                'SOS',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMERGENCY BOTTOM SHEET
  // ============================================================

  void _showEmergencyTypeSheet() {
    showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(
            20,
            14,
            20,
            32,
          ),

          decoration: const BoxDecoration(
            color: Color(0xFF0D1328),

            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,

                  decoration: BoxDecoration(
                    color: const Color(0xFF39445F),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                "What's happening?",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Select the type of crime emergency.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 22),

              _emergencyOption(
                'Robbery',
                Icons.warning_rounded,
                AppTheme.emergencyRed,
              ),

              _emergencyOption(
                'Assault',
                Icons.personal_injury_rounded,
                const Color(0xFFB967FF),
              ),

              _emergencyOption(
                'Snatch Theft',
                Icons.directions_run_rounded,
                AppTheme.riskOrange,
              ),

              _emergencyOption(
                'Break-In',
                Icons.home_work_outlined,
                AppTheme.cyan,
              ),

              _emergencyOption(
                'Theft',
                Icons.inventory_2_outlined,
                const Color(0xFF5C8CFF),
              ),

              _emergencyOption(
                'Suspicious Activity',
                Icons.visibility_outlined,
                AppTheme.safeGreen,
              ),

              _emergencyOption(
                'Other',
                Icons.more_horiz_rounded,
                AppTheme.textSecondary,
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(14),

                decoration: BoxDecoration(
                  color: AppTheme.safeGreen.withOpacity(0.07),

                  borderRadius: BorderRadius.circular(16),

                  border: Border.all(
                    color: AppTheme.safeGreen.withOpacity(0.2),
                  ),
                ),

                child: const Row(
                  children: [
                    Icon(
                      Icons.gps_fixed_rounded,
                      color: AppTheme.safeGreen,
                      size: 18,
                    ),

                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'GPS location ready • Verified identity',
                        style: TextStyle(
                          color: AppTheme.safeGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emergencyOption(
      String title,
      IconData icon,
      Color color,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),

      child: InkWell(
        onTap: () {
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$title selected. SOS publishing will be connected later.',
              ),
            ),
          );
        },

        borderRadius: BorderRadius.circular(16),

        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),

          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,

            borderRadius: BorderRadius.circular(16),

            border: Border.all(
              color: color.withOpacity(0.18),
            ),
          ),

          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,

                decoration: BoxDecoration(
                  color: color.withOpacity(0.11),

                  borderRadius: BorderRadius.circular(11),
                ),

                child: Icon(
                  icon,
                  color: color,
                  size: 19,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Text(
                  title,

                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        12,
      ),

      decoration: const BoxDecoration(
        color: Color(0xFF080D1C),

        border: Border(
          top: BorderSide(
            color: Color(0xFF1C2740),
          ),
        ),
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,

        children: [
          _navItem(
            index: 0,
            icon: Icons.home_rounded,
            label: 'Home',
          ),

          _navItem(
            index: 1,
            icon: Icons.map_outlined,
            label: 'Map',
          ),

          _navItem(
            index: 2,
            icon: Icons.notifications_active_outlined,
            label: 'Alerts',
          ),

          _navItem(
            index: 3,
            icon: Icons.person_outline_rounded,
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool selected = _currentIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },

      borderRadius: BorderRadius.circular(15),

      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 7,
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(
              icon,
              size: 21,

              color: selected
                  ? AppTheme.cyan
                  : AppTheme.textSecondary,
            ),

            const SizedBox(height: 4),

            Text(
              label,

              style: TextStyle(
                fontSize: 10,

                color: selected
                    ? AppTheme.cyan
                    : AppTheme.textSecondary,

                fontWeight: selected
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TEMP TABS
  // ============================================================

  Widget _buildMapPlaceholder() {
    return _simplePage(
      Icons.map_rounded,
      'Safety Map',
      'Real OpenStreetMap will be connected here.',
    );
  }

  Widget _buildAlertsPlaceholder() {
    return _simplePage(
      Icons.notifications_active_rounded,
      'Nearby Alerts',
      'Live SOS alerts within 1 km will appear here.',
    );
  }

  Widget _buildProfilePlaceholder() {
    return _simplePage(
      Icons.person_rounded,
      'Profile',
      'Verified profile and emergency contact.',
    );
  }

  Widget _simplePage(
      IconData icon,
      String title,
      String subtitle,
      ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(
              icon,
              size: 60,
              color: AppTheme.cyan,
            ),

            const SizedBox(height: 18),

            Text(
              title,

              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              subtitle,

              textAlign: TextAlign.center,

              style: const TextStyle(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===============================================================
// CRIME MARKER
// ===============================================================

class _CrimeMarker extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _CrimeMarker({
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,

      decoration: BoxDecoration(
        color: color,

        shape: BoxShape.circle,

        border: Border.all(
          color: Colors.white,
          width: 2,
        ),

        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.45),
            blurRadius: 15,
          ),
        ],
      ),

      child: Icon(
        icon,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}

// ===============================================================
// TEMP MAP VISUAL
// ===============================================================

class _MapPreviewPainter extends CustomPainter {
  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final roadPaint = Paint()
      ..color = const Color(0xFF1A2740)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final smallRoadPaint = Paint()
      ..color = const Color(0xFF121D31)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = AppTheme.cyan.withOpacity(0.05)
      ..strokeWidth = 1;

    // Main horizontal roads

    canvas.drawLine(
      Offset(0, size.height * 0.30),
      Offset(size.width, size.height * 0.45),
      roadPaint,
    );

    canvas.drawLine(
      Offset(0, size.height * 0.73),
      Offset(size.width, size.height * 0.57),
      roadPaint,
    );

    // Main vertical roads

    canvas.drawLine(
      Offset(size.width * 0.22, 0),
      Offset(size.width * 0.40, size.height),
      roadPaint,
    );

    canvas.drawLine(
      Offset(size.width * 0.72, 0),
      Offset(size.width * 0.58, size.height),
      roadPaint,
    );

    // Small roads

    for (int i = 1; i < 7; i++) {
      final double y =
          size.height * (i / 7);

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + 30),
        smallRoadPaint,
      );
    }

    for (int i = 1; i < 7; i++) {
      final double x =
          size.width * (i / 7);

      canvas.drawLine(
        Offset(x, 0),
        Offset(x - 30, size.height),
        smallRoadPaint,
      );
    }

    // Radar rings

    canvas.drawCircle(
      Offset(
        size.width / 2,
        size.height / 2,
      ),
      55,
      glowPaint,
    );

    canvas.drawCircle(
      Offset(
        size.width / 2,
        size.height / 2,
      ),
      90,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(
      covariant CustomPainter oldDelegate,
      ) {
    return false;
  }
}