import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() =>
      _VerifyEmailScreenState();
}

class _VerifyEmailScreenState
    extends State<VerifyEmailScreen> {
  bool _checking = false;
  bool _resending = false;

  Future<void> _checkVerification() async {
    setState(() {
      _checking = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      await user.reload();

      final refreshedUser =
          FirebaseAuth.instance.currentUser;

      if (refreshedUser != null &&
          refreshedUser.emailVerified) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(refreshedUser.uid)
            .update({
          'emailVerified': true,
        });

        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
              (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email verified successfully. Please login.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email has not been verified yet.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  Future<void> _resendVerification() async {
    setState(() {
      _resending = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Verification email sent again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _resending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(26),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Container(
                width: 90,
                height: 90,

                decoration: BoxDecoration(
                  color:
                  Colors.cyanAccent.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),

                child: const Icon(
                  Icons.mark_email_read_outlined,
                  color: Colors.cyanAccent,
                  size: 48,
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Verify Your Email',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                'We sent a verification link to:',
                style: TextStyle(
                  color: Colors.white60,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                user?.email ?? '',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Open your email and tap the verification link. '
                    'Then return here and continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 55,

                child: ElevatedButton(
                  onPressed:
                  _checking ? null : _checkVerification,

                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    Colors.cyanAccent,
                    foregroundColor:
                    const Color(0xFF07111F),
                  ),

                  child: _checking
                      ? const CircularProgressIndicator()
                      : const Text(
                    'I HAVE VERIFIED MY EMAIL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed:
                _resending ? null : _resendVerification,

                child: Text(
                  _resending
                      ? 'Sending...'
                      : 'Resend Verification Email',

                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}