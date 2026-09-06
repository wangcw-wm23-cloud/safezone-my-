import 'package:flutter/material.dart';

import '../services/session_manager.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool _checking = true;
  bool _authenticated = false;
  bool _busy = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    if (_busy || !mounted) {
      return;
    }

    _busy = true;

    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final valid =
      await SessionManager.instance.validateSession();

      if (!mounted) {
        return;
      }

      setState(() {
        _authenticated = valid;
      });
    } catch (error, stackTrace) {
      debugPrint('SESSION CHECK ERROR: $error');
      debugPrint(stackTrace.toString());

      if (mounted) {
        setState(() {
          _authenticated = false;
          _error =
          'Unable to check your session. '
              'Check your connection and retry.';
        });
      }
    } finally {
      _busy = false;

      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _checkSession,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_authenticated) {
      return const HomeScreen();
    }

    return LoginScreen(
      onLoginSuccess: _checkSession,
    );
  }
}