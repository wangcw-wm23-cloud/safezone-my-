import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  final SupabaseClient supabase = Supabase.instance.client;

  bool _isLoading = false;

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      await supabase.auth.resetPasswordForEmail(
        email,

        // Reset link successful → return to SafeZone App
        redirectTo: 'safezone://reset-password',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password reset email sent. Please check your email.',
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
    } catch (e) {
      debugPrint(
        'FORGOT PASSWORD ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to send reset email. Please try again.',
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
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Forgot Password',
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
                const SizedBox(height: 20),

                const Icon(
                  Icons.lock_reset_rounded,
                  size: 80,
                ),

                const SizedBox(height: 24),

                const Text(
                  'Reset Your Password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Enter your registered email address. '
                      'We will send you a password reset link.',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 30),

                TextFormField(
                  controller: _emailController,
                  keyboardType:
                  TextInputType.emailAddress,
                  textInputAction:
                  TextInputAction.done,
                  autocorrect: false,
                  onFieldSubmitted: (_) {
                    if (!_isLoading) {
                      _sendResetEmail();
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                    ),
                  ),
                  validator: (value) {
                    final email =
                        value?.trim() ?? '';

                    if (email.isEmpty) {
                      return 'Please enter your email';
                    }

                    if (!email.contains('@') ||
                        !email.contains('.')) {
                      return 'Please enter a valid email';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 26),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                    _isLoading
                        ? null
                        : _sendResetEmail,
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
                      'Send Reset Email',
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