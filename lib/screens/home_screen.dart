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

  bool _isLoading = true;

  String _fullName = 'SafeZone User';
  String _email = '';

  @override
  void initState() {
    super.initState();

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
              (route) => false,
        );

        return;
      }

      final profile = await supabase
          .from('profiles')
          .select(
        'full_name, email, created_at',
      )
          .eq(
        'id',
        user.id,
      )
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _fullName =
            profile?['full_name']?.toString() ??
                'SafeZone User';

        _email =
            profile?['email']?.toString() ??
                user.email ??
                '';

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load profile: $e',
          ),
        ),
      );
    }
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
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'SafeZone MY',
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            tooltip: 'Logout',
            icon: const Icon(
              Icons.logout,
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Welcome, $_fullName',
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              _email,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 30),

            // LOCATION
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Current Location',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'GPS location will be connected later.',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            // RISK
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.security_outlined,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Area Risk',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Historical crime risk from '
                          'data.gov.my will appear here.',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            // NEARBY INCIDENT
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_outlined,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Nearby Alerts',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Active SafeZone alerts within '
                          '1 km will appear here.',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'SOS module will be connected later.',
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.sos,
                  size: 28,
                ),
                label: const Text(
                  'SOS',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}