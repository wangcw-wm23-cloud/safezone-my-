import 'package:flutter/material.dart';

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Security')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.shield_outlined, size: 70),

            const SizedBox(height: 15),

            const Text(
              'Your Safety & Privacy',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 25),

            _section(
              context,
              icon: Icons.verified_user_outlined,
              title: 'Account Security',
              text:
                  'Your SafeZone account uses verified email authentication and secure account credentials.',
            ),

            _section(
              context,
              icon: Icons.devices_outlined,
              title: 'Device Security',
              text:
                  'Device binding helps prevent the same account from being actively registered on multiple devices.',
            ),

            _section(
              context,
              icon: Icons.location_on_outlined,
              title: 'Location Privacy',
              text:
                  'Location information is used for safety risk analysis, nearby incidents and emergency SOS features.',
            ),

            _section(
              context,
              icon: Icons.sos_outlined,
              title: 'Emergency Location Sharing',
              text:
                  'During an active SOS, your live location may be shared with nearby verified SafeZone users who can provide assistance.',
            ),

            _section(
              context,
              icon: Icons.storage_outlined,
              title: 'Data Storage',
              text:
                  'SafeZone uses cloud storage for shared account and emergency data, while selected application data may also be stored locally for offline access.',
            ),

            _section(
              context,
              icon: Icons.analytics_outlined,
              title: 'Safety Data',
              text:
                  'Historical crime information used by SafeZone is intended for safety awareness and does not guarantee that an area is completely safe or unsafe.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        children: [
          Text(text, style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}
