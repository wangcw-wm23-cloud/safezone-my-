import 'package:flutter/material.dart';

import '../services/auth_recovery_handler.dart';
import '../services/session_manager.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({
    super.key,
  });

  @override
  State<SessionGate> createState() =>
      _SessionGateState();
}

class _SessionGateState
    extends State<SessionGate>
    with WidgetsBindingObserver {
  final AuthRecoveryHandler
  _authRecoveryHandler =
  AuthRecoveryHandler();

  bool _checking = true;

  bool _authenticated = false;

  bool _validating = false;

  bool _handlingRecovery = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _authRecoveryHandler.start(
      onPasswordRecovery: () {
        if (!mounted) return;

        _handlingRecovery = true;

        WidgetsBinding.instance
            .addPostFrameCallback(
              (_) {
            if (!mounted) return;

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) =>
                const ResetPasswordScreen(),
              ),
                  (route) => false,
            );
          },
        );
      },
    );

    _checkSession();
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (state ==
        AppLifecycleState.resumed &&
        !_handlingRecovery) {
      _checkSession(
        showLoading: false,
      );
    }
  }

  Future<void> _checkSession({
    bool showLoading = true,
  }) async {
    if (_validating ||
        _handlingRecovery) {
      return;
    }

    _validating = true;

    if (showLoading && mounted) {
      setState(() {
        _checking = true;
      });
    }

    try {
      final valid =
      await SessionManager.instance
          .validateSession();

      if (!mounted ||
          _handlingRecovery) {
        return;
      }

      setState(() {
        _authenticated = valid;
        _checking = false;
      });
    } catch (e, stackTrace) {
      debugPrint(
        'SESSION GATE ERROR: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      await SessionManager.instance.logout();

      if (!mounted ||
          _handlingRecovery) {
        return;
      }

      setState(() {
        _authenticated = false;
        _checking = false;
      });
    } finally {
      _validating = false;
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child:
          CircularProgressIndicator(),
        ),
      );
    }

    if (_authenticated) {
      return const HomeScreen();
    }

    return LoginScreen(
      onLoginSuccess: () async {
        await _checkSession();
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance
        .removeObserver(this);

    _authRecoveryHandler.dispose();

    super.dispose();
  }
}