import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }

    if (value.trim().length < 2) {
      return 'Name is too short';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }

    final emailRegex = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }

    if (value.length < 8) {
      return 'Minimum 8 characters required';
    }

    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Add at least 1 uppercase letter';
    }

    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Add at least 1 lowercase letter';
    }

    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Add at least 1 number';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Add at least 1 special character';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final credential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Unable to create account');
      }

      await user.updateDisplayName(
        _nameController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),

        // Verification status
        'emailVerified': false,
        'phoneNumber': '',
        'phoneVerified': false,
        'deviceBound': false,

        // Account level
        'verificationLevel': 'basic',

        'createdAt': FieldValue.serverTimestamp(),
      });

      await user.sendEmailVerification();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const VerifyEmailScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed';

      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak';
      } else if (e.message != null) {
        message = e.message!;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Something went wrong: $e',
          ),
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07111F),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.cyanAccent,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Create Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Create your SafeZone MY account to access community safety features.',
                  style: TextStyle(
                    color: Colors.white60,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 28),

                _field(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  validator: _validateName,
                ),

                const SizedBox(height: 16),

                _field(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),

                const SizedBox(height: 16),

                _passwordField(
                  controller: _passwordController,
                  label: 'Password',
                  hidePassword: _hidePassword,
                  onToggle: () {
                    setState(() {
                      _hidePassword = !_hidePassword;
                    });
                  },
                  validator: _validatePassword,
                ),

                const SizedBox(height: 12),

                _passwordRequirements(),

                const SizedBox(height: 16),

                _passwordField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hidePassword: _hideConfirmPassword,
                  onToggle: () {
                    setState(() {
                      _hideConfirmPassword =
                      !_hideConfirmPassword;
                    });
                  },
                  validator: _validateConfirmPassword,
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed:
                    _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor:
                      const Color(0xFF07111F),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(18),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 25,
                      height: 25,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF07111F),
                      ),
                    )
                        : const Text(
                      'CREATE ACCOUNT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1B2C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white12,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.mark_email_read_outlined,
                        color: Colors.greenAccent,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You must verify your email before accessing SafeZone MY.',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType =
        TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
        const TextStyle(color: Colors.white54),
        prefixIcon: Icon(
          icon,
          color: Colors.cyanAccent,
        ),
        filled: true,
        fillColor: const Color(0xFF0D1B2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool hidePassword,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: hidePassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
        const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(
          Icons.lock_outline,
          color: Colors.cyanAccent,
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            hidePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.white54,
          ),
        ),
        filled: true,
        fillColor: const Color(0xFF0D1B2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  Widget _passwordRequirements() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1727),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'Password requirements\n\n'
            '• Minimum 8 characters\n'
            '• At least 1 uppercase letter\n'
            '• At least 1 lowercase letter\n'
            '• At least 1 number\n'
            '• At least 1 special character',
        style: TextStyle(
          color: Colors.white54,
          height: 1.5,
          fontSize: 12,
        ),
      ),
    );
  }
}