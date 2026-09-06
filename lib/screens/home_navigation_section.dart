part of 'home_screen.dart';

extension _HomeNavigationSection on _HomeScreenState {


  Widget _buildSOSButton() {
    return SizedBox(
      width: 72,
      height: 72,
      child: FloatingActionButton(
        heroTag: 'main_sos_button',
        onPressed: _startSOS,
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: CircleBorder(
          side: BorderSide(color: Colors.red.shade300, width: 3),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SOS',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            Text(
              'HELP',
              style: TextStyle(fontSize: 6, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildBottomNavigationBar() {
    final scheme = Theme.of(context).colorScheme;

    return BottomAppBar(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      notchMargin: 7,
      shape: const CircularNotchedRectangle(),
      color: scheme.surfaceContainer,
      child: Row(
        children: [
          Expanded(
            child: _bottomNavItem(
              index: 0,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Home',
            ),
          ),
          Expanded(
            child: _bottomNavItem(
              index: 1,
              icon: Icons.analytics_outlined,
              selectedIcon: Icons.analytics_rounded,
              label: 'Insights',
            ),
          ),

          // Space for the center SOS button.
          const SizedBox(width: 74),

          Expanded(
            child: _bottomNavItem(
              index: 2,
              icon: Icons.history_outlined,
              selectedIcon: Icons.history_rounded,
              label: 'Activity',
            ),
          ),
          Expanded(
            child: _bottomNavItem(
              index: 3,
              icon: Icons.person_outline,
              selectedIcon: Icons.person_rounded,
              label: 'Profile',
            ),
          ),
        ],
      ),
    );
  }


  Widget _bottomNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final scheme = Theme.of(context).colorScheme;

    final selected = _currentIndex == index;

    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        _changeHomeTab(index);

        if (index == 2) {
          await _loadActivities();
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? selectedIcon : icon, color: color, size: 21),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
