import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _passwordController =
  TextEditingController();

  final _confirmPasswordController =
  TextEditingController();

  final SupabaseClient supabase =
      Supabase.instance.client;

  bool _isLoading = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Recovery link should already have created
      // a temporary Supabase session.
      if (supabase.auth.currentSession == null) {
        throw const AuthException(
          'Password recovery session is invalid or expired. '
              'Please request a new reset email.',
        );
      }

      await supabase.auth.updateUser(
        UserAttributes(
          password: _passwordController.text,
        ),
      );

      // Password changed successfully.
      await supabase.auth.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password updated successfully. '
                'Please login with your new password.',
          ),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
          const LoginScreen(),
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
    } catch (e) {
      debugPrint(
        'RESET PASSWORD ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update password. '
                'Please try again.',
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
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Reset Password',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 30),

                const Icon(
                  Icons.password_rounded,
                  size: 80,
                ),

                const SizedBox(height: 24),

                const Text(
                  'Set New Password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Enter your new password below.',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 30),

                TextFormField(
                  controller:
                  _passwordController,
                  obscureText:
                  _hidePassword,
                  textInputAction:
                  TextInputAction.next,
                  decoration: InputDecoration(
                    labelText:
                    'New Password',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _hidePassword =
                          !_hidePassword;
                        });
                      },
                      icon: Icon(
                        _hidePassword
                            ? Icons
                            .visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'Please enter a new password';
                    }

                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                TextFormField(
                  controller:
                  _confirmPasswordController,
                  obscureText:
                  _hideConfirmPassword,
                  textInputAction:
                  TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!_isLoading) {
                      _updatePassword();
                    }
                  },
                  decoration: InputDecoration(
                    labelText:
                    'Confirm New Password',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _hideConfirmPassword =
                          !_hideConfirmPassword;
                        });
                      },
                      icon: Icon(
                        _hideConfirmPassword
                            ? Icons
                            .visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'Please confirm your new password';
                    }

                    if (value !=
                        _passwordController.text) {
                      return 'Passwords do not match';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 28),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                    _isLoading
                        ? null
                        : _updatePassword,
                    child: _isLoading
                        ? const SizedBox(
                      height: 22,
                      width: 22,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      'Update Password',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}