import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  bool _phoneVerified = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ============================================================
  // LOAD PROFILE
  // ============================================================

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('full_name, email, phone_number, phone_verified')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      _nameController.text =
          profile?['full_name']?.toString() ??
          user.userMetadata?['full_name']?.toString() ??
          '';

      _phoneController.text = profile?['phone_number']?.toString() ?? '';

      _emailController.text = user.email ?? profile?['email']?.toString() ?? '';

      _phoneVerified = profile?['phone_verified'] == true;
    } catch (e) {
      debugPrint('LOAD PROFILE ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load profile information.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // SAVE NAME + PHONE
  // ============================================================

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    final newName = _nameController.text.trim();

    final newPhone = _phoneController.text.trim();

    setState(() {
      _isSaving = true;
    });

    try {
      final currentProfile = await supabase
          .from('profiles')
          .select('phone_number')
          .eq('id', user.id)
          .maybeSingle();

      final oldPhone = currentProfile?['phone_number']?.toString().trim();

      // If phone number changed,
      // verification status must reset.
      final phoneChanged = oldPhone != newPhone;

      await supabase
          .from('profiles')
          .update({
            'full_name': newName,
            'phone_number': newPhone.isEmpty ? null : newPhone,
            'phone_verified': phoneChanged ? false : _phoneVerified,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      // Keep Supabase Auth metadata
      // synchronized with profiles table.
      await supabase.auth.updateUser(
        UserAttributes(data: {'full_name': newName}),
      );

      if (!mounted) return;

      setState(() {
        if (phoneChanged) {
          _phoneVerified = false;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Personal information updated successfully.'),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      debugPrint('SAVE PROFILE ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update personal information.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // CHANGE EMAIL
  // ============================================================

  Future<void> _changeEmail() async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    final controller = TextEditingController(text: user.email ?? '');

    final newEmail = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Email'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'New Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final email = controller.text.trim();

                if (email.isEmpty ||
                    !email.contains('@') ||
                    !email.contains('.')) {
                  return;
                }

                Navigator.pop(context, email);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (newEmail == null) {
      return;
    }

    if (newEmail.toLowerCase() == user.email?.toLowerCase()) {
      return;
    }

    try {
      await supabase.auth.updateUser(UserAttributes(email: newEmail));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Confirmation email sent to $newEmail. '
            'Open the verification link to complete the email change.',
          ),
        ),
      );

      // Do not immediately overwrite profiles.email.
      // Supabase may require the new email
      // to be confirmed first.
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      debugPrint('CHANGE EMAIL ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to change email.')));
    }
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<void> _changePassword() async {
    final passwordController = TextEditingController();

    final confirmController = TextEditingController();

    bool obscurePassword = true;
    bool obscureConfirm = true;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(() {
                            obscureConfirm = !obscureConfirm;
                          });
                        },
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final password = passwordController.text;

                    final confirm = confirmController.text;

                    if (password.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Password must be at least 6 characters.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (password != confirm) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Passwords do not match.'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context, password);
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
    confirmController.dispose();

    if (result == null) {
      return;
    }

    try {
      await supabase.auth.updateUser(UserAttributes(password: result));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      debugPrint('CHANGE PASSWORD ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to change password.')),
      );
    }
  }

  // ============================================================
  // PHONE VERIFICATION
  // ============================================================

  void _verifyPhone() {
    // We will connect actual OTP later.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Phone OTP verification will be connected next.'),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();

    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personal Information')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // =========================================
                      // PROFILE HEADER
                      // =========================================
                      Center(
                        child: CircleAvatar(
                          radius: 45,
                          child: Text(
                            _nameController.text.trim().isNotEmpty
                                ? _nameController.text.trim()[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // =========================================
                      // NAME
                      // =========================================
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your full name';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      // =========================================
                      // PHONE
                      // =========================================
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '+60123456789',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: const OutlineInputBorder(),
                          suffixIcon: _phoneVerified
                              ? const Tooltip(
                                  message: 'Verified',
                                  child: Icon(
                                    Icons.verified_rounded,
                                    color: Colors.green,
                                  ),
                                )
                              : null,
                        ),
                        validator: (value) {
                          final phone = value?.trim() ?? '';

                          if (phone.isEmpty) {
                            return 'Please enter your phone number';
                          }

                          final cleaned = phone
                              .replaceAll(' ', '')
                              .replaceAll('-', '')
                              .replaceAll('+', '');

                          if (!RegExp(r'^[0-9]{8,15}$').hasMatch(cleaned)) {
                            return 'Please enter a valid phone number';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Icon(
                            _phoneVerified
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            size: 17,
                            color: _phoneVerified ? Colors.green : null,
                          ),

                          const SizedBox(width: 7),

                          Expanded(
                            child: Text(
                              _phoneVerified
                                  ? 'Phone number verified'
                                  : 'Phone number not verified',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),

                          if (!_phoneVerified)
                            TextButton(
                              onPressed: _verifyPhone,
                              child: const Text('Verify'),
                            ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save Changes'),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // =========================================
                      // ACCOUNT SECURITY
                      // =========================================
                      const Text(
                        'Account & Security',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.email_outlined),
                              title: const Text('Email Address'),
                              subtitle: Text(_emailController.text),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _changeEmail,
                            ),

                            Divider(
                              height: 1,
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),

                            ListTile(
                              leading: const Icon(Icons.password_rounded),
                              title: const Text('Change Password'),
                              subtitle: const Text(
                                'Update your account password',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _changePassword,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.security_outlined, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'SafeZone uses your verified account '
                                'information to support emergency '
                                'identification and safety features.',
                                style: TextStyle(fontSize: 11),
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
}
