import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  bool _isLoading = false;

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      showDialog(
        context: context,

        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0D1B2C),

            title: const Text(
              'Reset Email Sent',
              style: TextStyle(color: Colors.white),
            ),

            content: Text(
              'A password reset link has been sent to:\n\n$email',
              style: const TextStyle(color: Colors.white70),
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },

                child: const Text(
                  'BACK TO LOGIN',
                  style: TextStyle(color: Colors.cyanAccent),
                ),
              ),
            ],
          );
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Unable to send reset email'),
          backgroundColor: Colors.redAccent,
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
      backgroundColor: const Color(0xFF07111F),

      appBar: AppBar(
        backgroundColor: const Color(0xFF07111F),
        elevation: 0,

        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const SizedBox(height: 30),

              Container(
                width: 68,
                height: 68,

                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),

                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: Colors.cyanAccent,
                  size: 38,
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Forgot Password?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Enter your registered email. '
                'We will send you a password reset link.',
                style: TextStyle(color: Colors.white60, height: 1.5),
              ),

              const SizedBox(height: 28),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,

                style: const TextStyle(color: Colors.white),

                decoration: InputDecoration(
                  labelText: 'Email Address',

                  labelStyle: const TextStyle(color: Colors.white54),

                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: Colors.cyanAccent,
                  ),

                  filled: true,
                  fillColor: const Color(0xFF0D1B2C),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 55,

                child: ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: const Color(0xFF07111F),
                  ),

                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'SEND RESET LINK',
                          style: TextStyle(fontWeight: FontWeight.bold),
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
