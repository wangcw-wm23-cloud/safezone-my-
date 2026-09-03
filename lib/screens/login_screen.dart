import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/device_binding_service.dart';
import '../services/session_manager.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  final Future<void> Function()?
  onLoginSuccess;

  const LoginScreen({
    super.key,
    this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {
  final _formKey =
  GlobalKey<FormState>();

  final TextEditingController
  _emailController =
  TextEditingController();

  final TextEditingController
  _passwordController =
  TextEditingController();

  final SupabaseClient supabase =
      Supabase.instance.client;

  bool _isLoading = false;

  bool _obscurePassword = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email =
    _emailController.text.trim();

    final password =
        _passwordController.text;

    bool signedIn = false;

    setState(() {
      _isLoading = true;
    });

    try {
      final response =
      await supabase.auth
          .signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;

      if (user == null) {
        throw const AuthException(
          'Login failed.',
        );
      }

      signedIn = true;

      // ========================================================
      // EMAIL VERIFICATION
      // ========================================================

      if (user.emailConfirmedAt == null) {
        await SessionManager.instance.logout();

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                VerifiedScreen(
                  email: email,
                ),
          ),
        );

        return;
      }

      // ========================================================
      // DEVICE CHECK
      //
      // Not bound = allowed.
      // Same device = allowed.
      // Another device = rejected.
      // No automatic binding happens here.
      // ========================================================

      final deviceAllowed =
      await DeviceBindingService.instance
          .checkDeviceBinding();

      if (!deviceAllowed) {
        await SessionManager.instance.logout();

        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'This account is already bound to another device.',
            ),
          ),
        );

        return;
      }

      await SessionManager.instance
          .markActive();

      if (!mounted) return;

      if (widget.onLoginSuccess != null) {
        await widget.onLoginSuccess!();

        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
          const HomeScreen(),
        ),
            (route) => false,
      );
    } on AuthException catch (e) {
      final message =
      e.message.toLowerCase();

      if (message.contains(
        'email not confirmed',
      )) {
        await SessionManager.instance.logout();

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                VerifiedScreen(
                  email: email,
                ),
          ),
        );

        return;
      }

      if (signedIn) {
        await SessionManager.instance.logout();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(e.message),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint(
        'LOGIN ERROR: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      await SessionManager.instance.logout();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Login could not be completed. Please try again.',
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
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      body: SafeArea(
        child:
        SingleChildScrollView(
          padding:
          const EdgeInsets.symmetric(
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
                ),

                const SizedBox(
                  height: 40,
                ),

                TextFormField(
                  controller:
                  _emailController,
                  keyboardType:
                  TextInputType
                      .emailAddress,
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
                    if (value == null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'Please enter your email';
                    }

                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 18,
                ),

                TextFormField(
                  controller:
                  _passwordController,
                  obscureText:
                  _obscurePassword,
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
                      icon: Icon(
                        _obscurePassword
                            ? Icons
                            .visibility_off
                            : Icons
                            .visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword =
                          !_obscurePassword;
                        });
                      },
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

                Align(
                  alignment:
                  Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
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
                    ),
                  ),
                ),

                const SizedBox(
                  height: 22,
                ),

                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account?",
                    ),

                    TextButton(
                      onPressed:
                      _isLoading
                          ? null
                          : () {
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

  @override
  void dispose() {
    _emailController.dispose();

    _passwordController.dispose();

    super.dispose();
  }
}