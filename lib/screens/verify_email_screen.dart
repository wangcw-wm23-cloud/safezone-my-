import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerifiedScreen extends StatefulWidget {
  final String email;

  const VerifiedScreen({
    super.key,
    required this.email,
  });

  @override
  State<VerifiedScreen> createState() => _VerifiedScreenState();
}

class _VerifiedScreenState extends State<VerifiedScreen> {
  final supabase = Supabase.instance.client;

  StreamSubscription<AuthState>? _authSubscription;

  bool _isResending = false;
  bool _verified = false;

  @override
  void initState() {
    super.initState();

    _listenForVerification();
  }

  void _listenForVerification() {
    _authSubscription =
        supabase.auth.onAuthStateChange.listen((authState) {
          final session = authState.session;
          final user = session?.user;

          if (user?.emailConfirmedAt != null) {
            if (!mounted) return;

            setState(() {
              _verified = true;
            });
          }
        });
  }

  Future<void> _resendVerificationEmail() async {
    setState(() {
      _isResending = true;
    });

    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification email has been sent again.',
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _goToLogin() async {
    // If confirmation deep link created a temporary session,
    // sign out so the user follows our intended:
    // Verify → Login flow.
    if (supabase.auth.currentSession != null) {
      await supabase.auth.signOut();
    }

    if (!mounted) return;

    // Assumption:
    // Login is your first/root page.
    Navigator.of(context).popUntil(
          (route) => route.isFirst,
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Verify Email'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _verified
                    ? Icons.verified
                    : Icons.mark_email_unread_outlined,
                size: 90,
              ),

              const SizedBox(height: 24),

              Text(
                _verified
                    ? 'Email Verified'
                    : 'Check Your Email',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall,
              ),

              const SizedBox(height: 12),

              Text(
                _verified
                    ? 'Your email has been successfully verified.'
                    : 'We sent a verification email to:',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                widget.email,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToLogin,
                  child: Text(
                    _verified
                        ? 'Continue to Login'
                        : 'I Have Verified My Email',
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: _isResending
                    ? null
                    : _resendVerificationEmail,
                child: _isResending
                    ? const CircularProgressIndicator()
                    : const Text(
                  'Resend Verification Email',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}