import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_recovery_handler.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController =
  TextEditingController();

  final TextEditingController _passwordController =
  TextEditingController();

  final SupabaseClient supabase =
      Supabase.instance.client;

  final AuthRecoveryHandler _authRecoveryHandler =
  AuthRecoveryHandler();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    // Listen for Supabase password recovery event.
    //
    // Forgot Password
    // → Email link
    // → safezone://reset-password
    // → Supabase passwordRecovery event
    // → ResetPasswordScreen
    _authRecoveryHandler.start(
      onPasswordRecovery: () {
        if (!mounted) return;

        WidgetsBinding.instance.addPostFrameCallback(
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
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String email =
    _emailController.text.trim();

    final String password =
        _passwordController.text;

    setState(() {
      _isLoading = true;
    });

    try {
      final AuthResponse response =
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final User? user = response.user;

      if (user == null) {
        throw const AuthException(
          'Login failed. Please try again.',
        );
      }

      // Extra verification check.
      if (user.emailConfirmedAt == null) {
        await supabase.auth.signOut();

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifiedScreen(
              email: email,
            ),
          ),
        );

        return;
      }

      if (!mounted) return;

      // Login successful.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
          const HomeScreen(),
        ),
            (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      final String message =
      e.message.toLowerCase();

      // Supabase may reject login before returning
      // the user when the email is not confirmed.
      if (message.contains(
        'email not confirmed',
      )) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifiedScreen(
              email: email,
            ),
          ),
        );

        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message,
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'LOGIN ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Stop recovery listener.
    _authRecoveryHandler.dispose();

    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 30,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                const SizedBox(
                  height: 40,
                ),

                const Icon(
                  Icons.shield_outlined,
                  size: 85,
                ),

                const SizedBox(
                  height: 20,
                ),

                const Text(
                  'SafeZone MY',
                  textAlign:
                  TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                const Text(
                  'Welcome Back',
                  textAlign:
                  TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                  ),
                ),

                const SizedBox(
                  height: 40,
                ),

                // EMAIL
                TextFormField(
                  controller:
                  _emailController,
                  keyboardType:
                  TextInputType
                      .emailAddress,
                  textInputAction:
                  TextInputAction.next,
                  autocorrect: false,
                  decoration:
                  const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                    ),
                    border:
                    OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final String email =
                        value?.trim() ?? '';

                    if (email.isEmpty) {
                      return 'Please enter your email';
                    }

                    if (!email.contains('@')) {
                      return 'Please enter a valid email';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 18,
                ),

                // PASSWORD
                TextFormField(
                  controller:
                  _passwordController,
                  obscureText:
                  _obscurePassword,
                  textInputAction:
                  TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!_isLoading) {
                      _login();
                    }
                  },
                  decoration:
                  InputDecoration(
                    labelText: 'Password',
                    prefixIcon:
                    const Icon(
                      Icons.lock_outline,
                    ),
                    border:
                    const OutlineInputBorder(),
                    suffixIcon:
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword =
                          !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons
                            .visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'Please enter your password';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 6,
                ),

                // FORGOT PASSWORD
                Align(
                  alignment:
                  Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                          const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Forgot Password?',
                    ),
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                // LOGIN
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                    _isLoading
                        ? null
                        : _login,
                    child: _isLoading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      'Login',
                      style:
                      TextStyle(
                        fontSize: 16,
                        fontWeight:
                        FontWeight
                            .bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 22,
                ),

                // REGISTER
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account?",
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                            const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Register',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}