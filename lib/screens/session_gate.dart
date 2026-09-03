import 'package:flutter/material.dart';

import '../services/session_manager.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({
    super.key,
  });

  @override
  State<SessionGate> createState() =>
      _SessionGateState();
}

class _SessionGateState
    extends State<SessionGate> {
  bool _checking = true;

  bool _authenticated = false;

  @override
  void initState() {
    super.initState();

    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final valid =
      await SessionManager.instance
          .validateSession();

      if (!mounted) return;

      setState(() {
        _authenticated = valid;
        _checking = false;
      });
    } catch (e) {
      debugPrint(
        'SESSION GATE ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _authenticated = false;
        _checking = false;
      });
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_authenticated) {
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}