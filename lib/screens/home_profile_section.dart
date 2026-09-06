part of 'home_screen.dart';

extension _HomeProfileSection on _HomeScreenState {


  Widget _buildProfilePage() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          const Text(
            'Profile',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 24),

          CircleAvatar(
            radius: 42,
            child: Text(
              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            _userName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),

          Text(
            _userEmail,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10),
          ),

          const SizedBox(height: 16),


          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: _profileStatus(
                    title: 'Phone',
                    complete: _phoneVerified,
                  ),
                ),

                Container(
                  height: 34,
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),

                Expanded(
                  child: _profileStatus(
                    title: 'Device',
                    complete: _hasBoundDevice,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          _profileOption(
            icon: Icons.person_outline,
            title: 'Personal Information',
            subtitle: _phoneVerified
                ? 'Phone verified'
                : 'Phone verification required',
            onTap: _openPersonalInformation,
          ),

          _profileOption(
            icon: Icons.devices_outlined,
            title: 'Registered Device',
            subtitle: _hasBoundDevice
                ? 'Device binding completed'
                : 'Device binding required',
            onTap: _openRegisteredDevice,
          ),

          _profileOption(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Notification preferences',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Notification settings will be available later.',
                  ),
                ),
              );
            },
          ),

          _profileOption(
            icon: Icons.security_outlined,
            title: 'Privacy & Security',
            subtitle: 'Account and safety settings',
            onTap: _openPrivacy,
          ),

          _profileOption(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            subtitle: 'Guides and support',
            onTap: _openHelp,
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 48,
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



  Widget _profileStatus({required String title, required bool complete}) {
    final color = complete ? Colors.green : Colors.orange;

    return Column(
      children: [
        Icon(
          complete ? Icons.check_circle_rounded : Icons.error_outline_rounded,
          color: color,
          size: 20,
        ),

        const SizedBox(height: 5),

        Text(title, style: const TextStyle(fontSize: 9)),

        Text(
          complete ? 'Completed' : 'Required',
          style: TextStyle(
            fontSize: 8,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }



  Widget _profileOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 9)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
