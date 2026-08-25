import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState
    extends State<PersonalInformationScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController =
  TextEditingController();

  final TextEditingController _phoneController =
  TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  bool _phoneVerified = false;

  String _currentEmail = '';

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
          .select(
        'full_name, email, phone_number, phone_verified',
      )
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _nameController.text =
            profile?['full_name']?.toString() ??
                user.userMetadata?['full_name']?.toString() ??
                '';

        _phoneController.text =
            profile?['phone_number']?.toString() ?? '';

        _phoneVerified =
            profile?['phone_verified'] == true;

        _currentEmail =
            user.email ??
                profile?['email']?.toString() ??
                '';
      });
    } catch (e) {
      debugPrint(
        'LOAD PROFILE ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to load profile information.',
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

    final newName =
    _nameController.text.trim();

    final newPhone =
    _phoneController.text.trim();

    setState(() {
      _isSaving = true;
    });

    try {
      final currentProfile = await supabase
          .from('profiles')
          .select(
        'phone_number, phone_verified',
      )
          .eq('id', user.id)
          .maybeSingle();

      final oldPhone =
          currentProfile?['phone_number']
              ?.toString()
              .trim() ??
              '';

      final bool phoneChanged =
          oldPhone != newPhone;

      await supabase
          .from('profiles')
          .update({
        'full_name': newName,
        'phone_number':
        newPhone.isEmpty
            ? null
            : newPhone,
        'phone_verified':
        phoneChanged
            ? false
            : _phoneVerified,
        'updated_at':
        DateTime.now()
            .toUtc()
            .toIso8601String(),
      })
          .eq(
        'id',
        user.id,
      );

      // Keep Auth metadata synchronized
      // with public.profiles.
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': newName,
          },
        ),
      );

      if (!mounted) return;

      setState(() {
        if (phoneChanged) {
          _phoneVerified = false;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Personal information updated successfully.',
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message,
          ),
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message,
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'SAVE PROFILE ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update personal information.',
          ),
        ),
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

    final String? newEmail =
    await showDialog<String>(
      context: context,
      builder: (_) {
        return _ChangeEmailDialog(
          currentEmail:
          user.email ?? _currentEmail,
        );
      },
    );

    if (newEmail == null ||
        newEmail.trim().isEmpty) {
      return;
    }

    if (newEmail.toLowerCase() ==
        user.email?.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This is already your current email address.',
          ),
        ),
      );

      return;
    }

    try {
      await supabase.auth.updateUser(
        UserAttributes(
          email: newEmail,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Confirmation email sent to $newEmail. '
                'Please verify the new email address to complete the change.',
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message,
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'CHANGE EMAIL ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to change email address.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<void> _changePassword() async {
    final String? newPassword =
    await showDialog<String>(
      context: context,
      builder: (_) {
        return const _ChangePasswordDialog();
      },
    );

    if (newPassword == null ||
        newPassword.isEmpty) {
      return;
    }

    try {
      await supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password changed successfully.',
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message,
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'CHANGE PASSWORD ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to change password. Please try again.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // PHONE VERIFICATION
  // ============================================================

  void _verifyPhone() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Phone OTP verification will be connected later.',
        ),
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

    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Personal Information',
        ),
      ),
      body: _isLoading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : SafeArea(
        child:
        SingleChildScrollView(
          padding:
          const EdgeInsets.all(
            20,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .stretch,
              children: [
                // ========================================
                // PROFILE ICON
                // ========================================

                Center(
                  child: CircleAvatar(
                    radius: 46,
                    child: Text(
                      _nameController
                          .text
                          .trim()
                          .isNotEmpty
                          ? _nameController
                          .text
                          .trim()[0]
                          .toUpperCase()
                          : 'U',
                      style:
                      const TextStyle(
                        fontSize: 33,
                        fontWeight:
                        FontWeight
                            .bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Text(
                  _nameController
                      .text
                      .trim()
                      .isEmpty
                      ? 'SafeZone User'
                      : _nameController
                      .text
                      .trim(),
                  textAlign:
                  TextAlign.center,
                  style:
                  const TextStyle(
                    fontSize: 20,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  _currentEmail,
                  textAlign:
                  TextAlign.center,
                  style:
                  const TextStyle(
                    fontSize: 12,
                  ),
                ),

                const SizedBox(
                  height: 30,
                ),

                // ========================================
                // PERSONAL DETAILS TITLE
                // ========================================

                const Text(
                  'Personal Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                // ========================================
                // FULL NAME
                // ========================================

                TextFormField(
                  controller:
                  _nameController,
                  textInputAction:
                  TextInputAction.next,
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Full Name',
                    prefixIcon: Icon(
                      Icons
                          .person_outline,
                    ),
                    border:
                    OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'Please enter your full name';
                    }

                    if (value
                        .trim()
                        .length <
                        2) {
                      return 'Please enter a valid name';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 18,
                ),

                // ========================================
                // PHONE NUMBER
                // ========================================

                TextFormField(
                  controller:
                  _phoneController,
                  keyboardType:
                  TextInputType.phone,
                  textInputAction:
                  TextInputAction.done,
                  decoration:
                  InputDecoration(
                    labelText:
                    'Phone Number',
                    hintText:
                    '+60123456789',
                    prefixIcon:
                    const Icon(
                      Icons
                          .phone_outlined,
                    ),
                    border:
                    const OutlineInputBorder(),
                    suffixIcon:
                    _phoneVerified
                        ? const Tooltip(
                      message:
                      'Verified',
                      child:
                      Icon(
                        Icons
                            .verified_rounded,
                        color:
                        Colors.green,
                      ),
                    )
                        : null,
                  ),
                  validator: (value) {
                    final phone =
                        value?.trim() ??
                            '';

                    if (phone.isEmpty) {
                      return 'Please enter your phone number';
                    }

                    final cleaned =
                    phone
                        .replaceAll(
                      ' ',
                      '',
                    )
                        .replaceAll(
                      '-',
                      '',
                    )
                        .replaceAll(
                      '+',
                      '',
                    );

                    if (!RegExp(
                      r'^[0-9]{8,15}$',
                    ).hasMatch(
                      cleaned,
                    )) {
                      return 'Please enter a valid phone number';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 8,
                ),

                // ========================================
                // PHONE STATUS
                // ========================================

                Row(
                  children: [
                    Icon(
                      _phoneVerified
                          ? Icons
                          .check_circle_outline
                          : Icons
                          .info_outline,
                      size: 17,
                      color:
                      _phoneVerified
                          ? Colors.green
                          : null,
                    ),

                    const SizedBox(
                      width: 7,
                    ),

                    Expanded(
                      child: Text(
                        _phoneVerified
                            ? 'Phone number verified'
                            : 'Phone number not verified',
                        style:
                        const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ),

                    if (!_phoneVerified)
                      TextButton(
                        onPressed:
                        _verifyPhone,
                        child:
                        const Text(
                          'Verify',
                        ),
                      ),
                  ],
                ),

                const SizedBox(
                  height: 12,
                ),

                // ========================================
                // SAVE CHANGES
                // ========================================

                SizedBox(
                  height: 52,
                  child:
                  ElevatedButton
                      .icon(
                    onPressed:
                    _isSaving
                        ? null
                        : _saveProfile,
                    icon: _isSaving
                        ? const SizedBox
                        .shrink()
                        : const Icon(
                      Icons
                          .save_outlined,
                    ),
                    label: _isSaving
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                      CircularProgressIndicator(
                        strokeWidth:
                        2,
                      ),
                    )
                        : const Text(
                      'Save Changes',
                    ),
                  ),
                ),

                const SizedBox(
                  height: 32,
                ),

                // ========================================
                // ACCOUNT & SECURITY
                // ========================================

                const Text(
                  'Account & Security',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Container(
                  decoration:
                  BoxDecoration(
                    borderRadius:
                    BorderRadius
                        .circular(
                      18,
                    ),
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .surfaceContainer,
                    border:
                    Border.all(
                      color: Theme.of(
                        context,
                      )
                          .colorScheme
                          .outlineVariant,
                    ),
                  ),
                  child: Column(
                    children: [
                      // EMAIL

                      ListTile(
                        leading:
                        const Icon(
                          Icons
                              .email_outlined,
                        ),
                        title:
                        const Text(
                          'Email Address',
                        ),
                        subtitle: Text(
                          _currentEmail,
                        ),
                        trailing:
                        const Icon(
                          Icons
                              .chevron_right_rounded,
                        ),
                        onTap:
                        _changeEmail,
                      ),

                      Divider(
                        height: 1,
                        color: Theme.of(
                          context,
                        )
                            .colorScheme
                            .outlineVariant,
                      ),

                      // PASSWORD

                      ListTile(
                        leading:
                        const Icon(
                          Icons
                              .password_rounded,
                        ),
                        title:
                        const Text(
                          'Change Password',
                        ),
                        subtitle:
                        const Text(
                          'Update your account password',
                        ),
                        trailing:
                        const Icon(
                          Icons
                              .chevron_right_rounded,
                        ),
                        onTap:
                        _changePassword,
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 22,
                ),

                // ========================================
                // INFORMATION
                // ========================================

                Container(
                  padding:
                  const EdgeInsets
                      .all(
                    16,
                  ),
                  decoration:
                  BoxDecoration(
                    borderRadius:
                    BorderRadius
                        .circular(
                      16,
                    ),
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .surfaceContainer,
                  ),
                  child:
                  const Row(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Icon(
                        Icons
                            .security_outlined,
                        size: 20,
                      ),

                      SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child: Text(
                          'SafeZone uses your account information '
                              'to support emergency identification, '
                              'device security and safety features.',
                          style:
                          TextStyle(
                            fontSize:
                            11,
                            height: 1.4,
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
}

// ============================================================
// CHANGE EMAIL DIALOG
//
// Dialog owns its own controller.
// Controller is disposed only when Dialog is really removed.
// ============================================================

class _ChangeEmailDialog
    extends StatefulWidget {
  final String currentEmail;

  const _ChangeEmailDialog({
    required this.currentEmail,
  });

  @override
  State<_ChangeEmailDialog> createState() =>
      _ChangeEmailDialogState();
}

class _ChangeEmailDialogState
    extends State<_ChangeEmailDialog> {
  final _formKey =
  GlobalKey<FormState>();

  late final TextEditingController
  _emailController;

  @override
  void initState() {
    super.initState();

    _emailController =
        TextEditingController(
          text: widget.currentEmail,
        );
  }

  @override
  void dispose() {
    _emailController.dispose();

    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.pop(
      context,
      _emailController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Change Email',
      ),
      content:
      SingleChildScrollView(
        child: Form(
          key: _formKey,
          child:
          TextFormField(
            controller:
            _emailController,
            keyboardType:
            TextInputType
                .emailAddress,
            textInputAction:
            TextInputAction.done,
            autofocus: true,
            onFieldSubmitted: (_) {
              _submit();
            },
            decoration:
            const InputDecoration(
              labelText:
              'New Email',
              prefixIcon:
              Icon(
                Icons
                    .email_outlined,
              ),
              border:
              OutlineInputBorder(),
            ),
            validator: (value) {
              final email =
                  value?.trim() ??
                      '';

              if (email.isEmpty) {
                return 'Please enter your new email';
              }

              if (!email.contains('@') ||
                  !email.contains('.')) {
                return 'Please enter a valid email';
              }

              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(
              context,
            );
          },
          child: const Text(
            'Cancel',
          ),
        ),

        FilledButton(
          onPressed: _submit,
          child: const Text(
            'Continue',
          ),
        ),
      ],
    );
  }
}

// ============================================================
// CHANGE PASSWORD DIALOG
//
// This fixes:
// "TextEditingController was used after being disposed"
// ============================================================

class _ChangePasswordDialog
    extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState
    extends State<_ChangePasswordDialog> {
  final _formKey =
  GlobalKey<FormState>();

  final TextEditingController
  _passwordController =
  TextEditingController();

  final TextEditingController
  _confirmPasswordController =
  TextEditingController();

  bool _obscurePassword = true;

  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();

    _confirmPasswordController.dispose();

    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.pop(
      context,
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Change Password',
      ),

      // Important:
      // prevents keyboard / small screen overflow.
      content:
      SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              // NEW PASSWORD

              TextFormField(
                controller:
                _passwordController,
                obscureText:
                _obscurePassword,
                textInputAction:
                TextInputAction.next,
                decoration:
                InputDecoration(
                  labelText:
                  'New Password',
                  prefixIcon:
                  const Icon(
                    Icons
                        .lock_outline,
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
                          : Icons
                          .visibility,
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

              const SizedBox(
                height: 16,
              ),

              // CONFIRM PASSWORD

              TextFormField(
                controller:
                _confirmPasswordController,
                obscureText:
                _obscureConfirmPassword,
                textInputAction:
                TextInputAction.done,
                onFieldSubmitted: (_) {
                  _submit();
                },
                decoration:
                InputDecoration(
                  labelText:
                  'Confirm New Password',
                  prefixIcon:
                  const Icon(
                    Icons
                        .lock_outline,
                  ),
                  border:
                  const OutlineInputBorder(),
                  suffixIcon:
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword =
                        !_obscureConfirmPassword;
                      });
                    },
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons
                          .visibility_off
                          : Icons
                          .visibility,
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
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(
              context,
            );
          },
          child: const Text(
            'Cancel',
          ),
        ),

        FilledButton(
          onPressed: _submit,
          child: const Text(
            'Update',
          ),
        ),
      ],
    );
  }
}