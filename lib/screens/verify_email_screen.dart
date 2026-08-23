import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';

class VerifiedScreen extends StatefulWidget {
  final String email;
  final String? userId;

  const VerifiedScreen({
    super.key,
    required this.email,
    this.userId,
  });

  @override
  State<VerifiedScreen> createState() => _VerifiedScreenState();
}

class _VerifiedScreenState extends State<VerifiedScreen>
    with WidgetsBindingObserver {
  final SupabaseClient supabase = Supabase.instance.client;

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _verificationTimer;
  Timer? _resendTimer;

  bool _isVerified = false;
  bool _verificationHandled = false;
  bool _isChecking = false;
  bool _isResending = false;

  int _resendSeconds = 60;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _listenToAuthChanges();
    _startVerificationPolling();
    _startResendCountdown();

    // 一进入页面马上检查一次
    Future.microtask(_checkVerificationFromBackend);
  }

  // =========================================================
  // SUPABASE AUTH LISTENER
  // =========================================================

  void _listenToAuthChanges() {
    _authSubscription =
        supabase.auth.onAuthStateChange.listen(
              (data) {
            final user = data.session?.user;

            if (user != null &&
                user.emailConfirmedAt != null) {
              debugPrint(
                'VERIFY AUTH EVENT: email verified',
              );

              _completeVerification();
            }
          },
          onError: (error, stackTrace) {
            debugPrint(
              'VERIFY AUTH LISTENER ERROR: $error',
            );
          },
        );
  }

  // =========================================================
  // AUTOMATIC BACKEND POLLING
  // =========================================================

  void _startVerificationPolling() {
    if (widget.userId == null) {
      debugPrint(
        'VERIFY: userId is NULL, polling cannot start',
      );
      return;
    }

    debugPrint(
      'VERIFY: polling started for ${widget.userId}',
    );

    _verificationTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) {
        _checkVerificationFromBackend();
      },
    );
  }

  Future<void> _checkVerificationFromBackend() async {
    if (_verificationHandled) return;
    if (_isChecking) return;

    final userId = widget.userId;

    if (userId == null) {
      debugPrint(
        'VERIFY: backend check skipped because userId is null',
      );
      return;
    }

    _isChecking = true;

    try {
      final result = await supabase.rpc(
        'is_email_verified',
        params: {
          'p_user_id': userId,
          'p_email': widget.email,
        },
      );

      debugPrint(
        'VERIFY RESULT = $result',
      );

      if (result == true) {
        await _completeVerification();
      }
    } catch (e) {
      debugPrint(
        'VERIFY RPC ERROR = $e',
      );
    } finally {
      _isChecking = false;
    }
  }

  // =========================================================
  // WHEN USER RETURNS FROM EMAIL / BROWSER
  // =========================================================

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      debugPrint(
        'VERIFY: app resumed, checking immediately',
      );

      _checkVerificationFromBackend();

      final currentUser =
          supabase.auth.currentUser;

      if (currentUser != null &&
          currentUser.emailConfirmedAt != null) {
        _completeVerification();
      }
    }
  }

  // =========================================================
  // VERIFICATION SUCCESS
  // =========================================================

  Future<void> _completeVerification() async {
    if (_verificationHandled) return;

    _verificationHandled = true;
    _verificationTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _isVerified = true;
    });

    debugPrint(
      'VERIFY: verification completed successfully',
    );

    // 让用户看到成功画面
    await Future.delayed(
      const Duration(seconds: 2),
    );

    // Email verification deep link 有时候会建立 session。
    // SafeZone 流程是 Verify -> Login，
    // 所以这里先 logout。
    if (supabase.auth.currentSession != null) {
      try {
        await supabase.auth.signOut();
      } catch (e) {
        debugPrint(
          'VERIFY SIGNOUT ERROR: $e',
        );
      }
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
          (route) => false,
    );
  }

  // =========================================================
  // RESEND COUNTDOWN
  // =========================================================

  void _startResendCountdown() {
    _resendTimer?.cancel();

    _resendSeconds = 60;

    _resendTimer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_resendSeconds <= 1) {
          timer.cancel();

          setState(() {
            _resendSeconds = 0;
          });

          return;
        }

        setState(() {
          _resendSeconds--;
        });
      },
    );
  }

  // =========================================================
  // RESEND VERIFICATION EMAIL
  // =========================================================

  Future<void> _resendVerificationEmail() async {
    if (_isResending ||
        _resendSeconds > 0 ||
        _isVerified) {
      return;
    }

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
            'Verification email sent again.',
          ),
        ),
      );

      _startResendCountdown();
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
        ),
      );
    } catch (e) {
      debugPrint(
        'VERIFY RESEND ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to resend verification email.',
          ),
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

  // =========================================================
  // MANUAL CHECK BUTTON
  // =========================================================

  Future<void> _checkNow() async {
    if (_isChecking) return;

    await _checkVerificationFromBackend();

    if (!_verificationHandled &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email has not been verified yet.',
          ),
        ),
      );
    }
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _authSubscription?.cancel();
    _verificationTimer?.cancel();
    _resendTimer?.cancel();

    super.dispose();
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Verify Email',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 30,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 430,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    _isVerified
                        ? Icons.verified_rounded
                        : Icons.mark_email_unread_outlined,
                    size: 90,
                    color: _isVerified
                        ? Colors.green
                        : Theme.of(context)
                        .colorScheme
                        .primary,
                  ),

                  const SizedBox(height: 28),

                  Text(
                    _isVerified
                        ? 'Email Verified!'
                        : 'Check Your Email',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (!_isVerified) ...[
                    const Text(
                      'We sent a verification link to:',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 30),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius:
                        BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant,
                        ),
                      ),
                      child: const Column(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child:
                            CircularProgressIndicator(
                              strokeWidth: 2.5,
                            ),
                          ),

                          SizedBox(height: 14),

                          Text(
                            'Waiting for verification...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),

                          SizedBox(height: 8),

                          Text(
                            'SafeZone is checking your verification status automatically.',
                            textAlign:
                            TextAlign.center,
                          ),

                          SizedBox(height: 6),

                          Text(
                            'Status refreshes every 5 seconds.',
                            textAlign:
                            TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    TextButton.icon(
                      onPressed:
                      _isChecking ? null : _checkNow,
                      icon: const Icon(
                        Icons.refresh,
                      ),
                      label: Text(
                        _isChecking
                            ? 'Checking...'
                            : 'Check Verification Now',
                      ),
                    ),

                    const SizedBox(height: 8),

                    OutlinedButton(
                      onPressed:
                      _isResending ||
                          _resendSeconds > 0
                          ? null
                          : _resendVerificationEmail,
                      child: _isResending
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        _resendSeconds > 0
                            ? 'Resend Email in ${_resendSeconds}s'
                            : 'Resend Verification Email',
                      ),
                    ),
                  ],

                  if (_isVerified) ...[
                    const SizedBox(height: 20),

                    const Text(
                      'Your email address has been successfully verified.',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    const Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),

                        SizedBox(width: 12),

                        Text(
                          'Redirecting to login...',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}