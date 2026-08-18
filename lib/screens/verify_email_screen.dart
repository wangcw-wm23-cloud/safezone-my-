import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isChecking = false;
  bool _isVerified = false;
  bool _isResending = false;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _checkVerificationStatus();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isVerified) {
        _checkVerificationStatus(showMessage: false);
      }
    });
  }

  Future<void> _checkVerificationStatus({bool showMessage = true}) async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      await user.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        return;
      }

      if (refreshedUser.emailVerified) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(refreshedUser.uid)
            .update({'emailVerified': true});

        if (!mounted) return;

        setState(() {
          _isVerified = true;
        });

        _timer?.cancel();

        if (showMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email verified successfully.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (!mounted) return;

        setState(() {
          _isVerified = false;
        });

        if (showMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email is still waiting for verification.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to check verification status: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      await user.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        return;
      }

      if (refreshedUser.emailVerified) {
        if (!mounted) return;

        setState(() {
          _isVerified = true;
        });

        return;
      }

      await refreshedUser.sendEmailVerification();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent again.'),
          backgroundColor: Colors.cyan,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'Unable to resend verification email.';

      if (e.code == 'too-many-requests') {
        message = 'Too many requests. Please wait before trying again.';
      } else if (e.message != null) {
        message = e.message!;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _continueToLogin() async {
    if (!_isVerified) return;

    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),

      appBar: AppBar(
        backgroundColor: const Color(0xFF07111F),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),

          child: Column(
            children: [
              const SizedBox(height: 20),

              AnimatedContainer(
                duration: const Duration(milliseconds: 300),

                width: 105,
                height: 105,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color: _isVerified
                      ? Colors.greenAccent.withOpacity(0.10)
                      : Colors.cyanAccent.withOpacity(0.10),

                  border: Border.all(
                    color: _isVerified ? Colors.greenAccent : Colors.cyanAccent,
                    width: 2,
                  ),

                  boxShadow: [
                    BoxShadow(
                      color:
                          (_isVerified ? Colors.greenAccent : Colors.cyanAccent)
                              .withOpacity(0.20),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),

                child: Icon(
                  _isVerified
                      ? Icons.verified_rounded
                      : Icons.mark_email_unread_outlined,

                  color: _isVerified ? Colors.greenAccent : Colors.cyanAccent,

                  size: 55,
                ),
              ),

              const SizedBox(height: 28),

              Text(
                _isVerified ? 'Email Verified' : 'Verify Your Email',

                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                _isVerified
                    ? 'Your email verification is complete.'
                    : 'We sent a verification link to:',

                textAlign: TextAlign.center,

                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),

              const SizedBox(height: 10),

              Text(
                email,

                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 30),

              AnimatedContainer(
                duration: const Duration(milliseconds: 300),

                width: double.infinity,

                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2C),

                  borderRadius: BorderRadius.circular(20),

                  border: Border.all(
                    color: _isVerified
                        ? Colors.greenAccent.withOpacity(0.5)
                        : Colors.white12,
                  ),
                ),

                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,

                      decoration: BoxDecoration(
                        color: _isVerified
                            ? Colors.greenAccent.withOpacity(0.10)
                            : Colors.white.withOpacity(0.05),

                        borderRadius: BorderRadius.circular(14),
                      ),

                      child: Icon(
                        _isVerified
                            ? Icons.check_circle_rounded
                            : Icons.schedule_rounded,

                        color: _isVerified
                            ? Colors.greenAccent
                            : Colors.white38,
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          const Text(
                            'Email Verification',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            _isVerified
                                ? 'VERIFIED'
                                : 'WAITING FOR VERIFICATION',

                            style: TextStyle(
                              color: _isVerified
                                  ? Colors.greenAccent
                                  : Colors.white38,

                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_isVerified)
                      const Icon(
                        Icons.verified_rounded,
                        color: Colors.greenAccent,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              if (!_isVerified)
                Container(
                  width: double.infinity,

                  padding: const EdgeInsets.all(18),

                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1727),

                    borderRadius: BorderRadius.circular(18),
                  ),

                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.cyanAccent,
                            size: 19,
                          ),

                          SizedBox(width: 9),

                          Text(
                            'What to do',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 12),

                      Text(
                        '1. Open your email inbox.\n'
                        '2. Open the SafeZone MY verification email.\n'
                        '3. Tap the verification link.\n'
                        '4. Return to this app.\n\n'
                        'SafeZone MY will automatically check your verification status.',

                        style: TextStyle(
                          color: Colors.white60,
                          height: 1.5,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),

              if (_isVerified) ...[
                const SizedBox(height: 8),

                Container(
                  width: double.infinity,

                  padding: const EdgeInsets.all(18),

                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.06),

                    borderRadius: BorderRadius.circular(18),

                    border: Border.all(
                      color: Colors.greenAccent.withOpacity(0.25),
                    ),
                  ),

                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.greenAccent,
                      ),

                      SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          'Your email has been successfully verified. You can now continue to login.',

                          style: TextStyle(color: Colors.white70, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 56,

                child: ElevatedButton.icon(
                  onPressed: _isVerified ? _continueToLogin : null,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,

                    disabledBackgroundColor: Colors.white12,

                    foregroundColor: const Color(0xFF07111F),

                    disabledForegroundColor: Colors.white30,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),

                  icon: Icon(
                    _isVerified
                        ? Icons.login_rounded
                        : Icons.lock_outline_rounded,
                  ),

                  label: const Text(
                    'CONTINUE TO LOGIN',

                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              if (!_isVerified)
                SizedBox(
                  width: double.infinity,
                  height: 52,

                  child: OutlinedButton.icon(
                    onPressed: _isChecking
                        ? null
                        : () => _checkVerificationStatus(),

                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.cyanAccent,

                      side: const BorderSide(color: Colors.cyanAccent),

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),

                    icon: _isChecking
                        ? const SizedBox(
                            width: 18,
                            height: 18,

                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.cyanAccent,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),

                    label: Text(
                      _isChecking ? 'CHECKING...' : 'CHECK STATUS',

                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              if (!_isVerified) const SizedBox(height: 10),

              if (!_isVerified)
                TextButton(
                  onPressed: _isResending ? null : _resendVerificationEmail,

                  child: Text(
                    _isResending ? 'Sending...' : 'Resend verification email',

                    style: const TextStyle(color: Colors.white60),
                  ),
                ),

              const SizedBox(height: 20),

              if (!_isVerified)
                const Text(
                  'This page checks your Firebase account status automatically every few seconds.',

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    color: Colors.white30,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
