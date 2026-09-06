import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  String _currentEmail = '';


  String _storedPhoneDigits = '';

  bool _storedPhoneVerified = false;


  static const String _testingOtp = '123456';

  @override
  void initState() {
    super.initState();

    _loadProfile();
  }


  String _normalizeMalaysiaPhoneDigits(String value) {
    String digits =
    value.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    // Remove Malaysia country code if pasted.
    if (digits.startsWith('60')) {
      digits =
          digits.substring(2);
    }

    // Remove local leading zero.
    if (digits.startsWith('0')) {
      digits =
          digits.substring(1);
    }

    return digits;
  }


  bool _isValidMalaysiaMobile(
      String value,
      ) {
    final digits =
    _normalizeMalaysiaPhoneDigits(
      value,
    );

    return RegExp(
      r'^1\d{8,9}$',
    ).hasMatch(
      digits,
    );
  }

  String _fullMalaysiaPhone(
      String value,
      ) {
    final digits =
    _normalizeMalaysiaPhoneDigits(
      value,
    );

    return '+60$digits';
  }

  bool get _isCurrentPhoneVerified {
    final current =
    _normalizeMalaysiaPhoneDigits(
      _phoneController.text,
    );

    return _storedPhoneVerified &&
        current.isNotEmpty &&
        current == _storedPhoneDigits;
  }


  Future<void> _loadProfile() async {
    final user =
        supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      return;
    }

    try {
      final profile =
      await supabase
          .from('profiles')
          .select(
        'full_name, email, phone_number, phone_verified',
      )
          .eq(
        'id',
        user.id,
      )
          .maybeSingle();

      if (!mounted) return;

      final databasePhone =
          profile?['phone_number']
              ?.toString() ??
              '';

      final phoneDigits =
      _normalizeMalaysiaPhoneDigits(
        databasePhone,
      );

      setState(() {
        _nameController.text =
            profile?['full_name']
                ?.toString() ??
                user
                    .userMetadata?[
                'full_name']
                    ?.toString() ??
                '';

        _phoneController.text =
            phoneDigits;

        _storedPhoneDigits =
            phoneDigits;

        _storedPhoneVerified =
            profile?['phone_verified'] ==
                true;

        _currentEmail =
            user.email ??
                profile?['email']
                    ?.toString() ??
                '';

        _isLoading = false;
      });
    } catch (e) {
      debugPrint(
        'LOAD PROFILE ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to load personal information.',
          ),
        ),
      );
    }
  }


  Future<void> _saveProfile() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final user =
        supabase.auth.currentUser;

    if (user == null) return;

    final newName =
    _nameController.text.trim();

    final newPhoneDigits =
    _normalizeMalaysiaPhoneDigits(
      _phoneController.text,
    );

    final fullPhone =
        '+60$newPhoneDigits';

    final bool phoneChanged =
        newPhoneDigits !=
            _storedPhoneDigits;

    setState(() {
      _isSaving = true;
    });

    try {
      await supabase
          .from('profiles')
          .update(
        {
          'full_name': newName,
          'phone_number': fullPhone,


          'phone_verified':
          phoneChanged
              ? false
              : _storedPhoneVerified,

          'updated_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
        },
      ).eq(
        'id',
        user.id,
      );


      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': newName,
          },
        ),
      );

      if (!mounted) return;

      setState(() {
        _storedPhoneDigits =
            newPhoneDigits;

        if (phoneChanged) {
          _storedPhoneVerified =
          false;
        }
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            phoneChanged
                ? 'Information saved. Please verify your new phone number.'
                : 'Personal information updated successfully.',
          ),
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e.message,
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
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

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to save personal information.',
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


  Future<void> _verifyPhone() async {
    final user =
        supabase.auth.currentUser;

    if (user == null) return;

    final rawPhone =
    _phoneController.text.trim();

    if (!_isValidMalaysiaMobile(
      rawPhone,
    )) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid Malaysian mobile number.',
          ),
        ),
      );

      return;
    }

    final digits =
    _normalizeMalaysiaPhoneDigits(
      rawPhone,
    );

    final fullPhone =
        '+60$digits';


    final bool? verified =
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _PhoneOtpDialog(
          phoneNumber:
          fullPhone,
          testingOtp:
          _testingOtp,
        );
      },
    );

    if (verified != true) {
      return;
    }

    try {
      await supabase
          .from('profiles')
          .update(
        {
          'phone_number':
          fullPhone,
          'phone_verified':
          true,
          'updated_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
        },
      ).eq(
        'id',
        user.id,
      );

      if (!mounted) return;

      setState(() {
        _storedPhoneDigits =
            digits;

        _storedPhoneVerified =
        true;

        _phoneController.text =
            digits;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Phone number verified successfully.',
          ),
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e.message,
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'PHONE VERIFY ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to verify phone number.',
          ),
        ),
      );
    }
  }

  Future<void> _changeEmail() async {
    final user =
        supabase.auth.currentUser;

    if (user == null) return;

    final String? newEmail =
    await showDialog<String>(
      context: context,
      builder: (_) {
        return _ChangeEmailDialog(
          currentEmail:
          user.email ??
              _currentEmail,
        );
      },
    );

    if (newEmail == null ||
        newEmail.trim().isEmpty) {
      return;
    }

    if (newEmail
        .trim()
        .toLowerCase() ==
        user.email
            ?.toLowerCase()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
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
          email:
          newEmail.trim(),
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Confirmation email sent to ${newEmail.trim()}.',
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
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

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to change email address.',
          ),
        ),
      );
    }
  }

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
          password:
          newPassword,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Password changed successfully.',
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
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

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to change password.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();

    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text(
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

                Center(
                  child:
                  CircleAvatar(
                    radius: 45,
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
                        fontSize:
                        32,
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
                    FontWeight
                        .bold,
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

                const Text(
                  'Personal Details',
                  style:
                  TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight
                        .bold,
                  ),
                ),

                const SizedBox(
                  height: 14,
                ),

                TextFormField(
                  controller:
                  _nameController,
                  textInputAction:
                  TextInputAction
                      .next,
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Full Name',
                    prefixIcon:
                    Icon(
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

                TextFormField(
                  controller:
                  _phoneController,
                  keyboardType:
                  TextInputType.phone,
                  textInputAction:
                  TextInputAction.done,

                  // User only enters digits after +60.
                  inputFormatters: [
                    FilteringTextInputFormatter
                        .digitsOnly,

                    LengthLimitingTextInputFormatter(
                      10,
                    ),
                  ],

                  onChanged: (_) {
                    setState(() {});
                  },

                  decoration:
                  InputDecoration(
                    labelText:
                    'Phone Number',

                    hintText:
                    '123456789',

                    prefixIcon:
                    const Icon(
                      Icons
                          .phone_outlined,
                    ),

                    prefixText:
                    '+60 ',

                    border:
                    const OutlineInputBorder(),

                    suffixIcon:
                    _isCurrentPhoneVerified
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
                    if (value == null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'Please enter your phone number';
                    }

                    if (!_isValidMalaysiaMobile(
                      value,
                    )) {
                      return 'Enter a valid Malaysian mobile number';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 8,
                ),


                Row(
                  children: [
                    Icon(
                      _isCurrentPhoneVerified
                          ? Icons
                          .check_circle
                          : Icons
                          .info_outline,
                      size: 18,
                      color:
                      _isCurrentPhoneVerified
                          ? Colors.green
                          : null,
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Expanded(
                      child: Text(
                        _isCurrentPhoneVerified
                            ? 'Phone number verified'
                            : 'Phone number not verified',
                        style:
                        TextStyle(
                          fontSize: 12,
                          color:
                          _isCurrentPhoneVerified
                              ? Colors.green
                              : null,
                        ),
                      ),
                    ),

                    if (!_isCurrentPhoneVerified)
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

                if (!_isCurrentPhoneVerified)
                  const Padding(
                    padding:
                    EdgeInsets.only(
                      top: 3,
                    ),
                    child: Text(
                      'Malaysia mobile numbers only.',
                      style:
                      TextStyle(
                        fontSize: 10,
                      ),
                    ),
                  ),

                const SizedBox(
                  height: 18,
                ),

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


                const Text(
                  'Account & Security',
                  style:
                  TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight
                        .bold,
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
                        subtitle:
                        Text(
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
                  height: 24,
                ),

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
                          'SafeZone uses your verified phone number '
                              'to support emergency identification and '
                              'account safety features.',
                          style:
                          TextStyle(
                            fontSize: 11,
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


class _PhoneOtpDialog
    extends StatefulWidget {
  final String phoneNumber;
  final String testingOtp;

  const _PhoneOtpDialog({
    required this.phoneNumber,
    required this.testingOtp,
  });

  @override
  State<_PhoneOtpDialog> createState() =>
      _PhoneOtpDialogState();
}

class _PhoneOtpDialogState
    extends State<_PhoneOtpDialog> {
  final _formKey =
  GlobalKey<FormState>();

  final TextEditingController
  _otpController =
  TextEditingController();

  int _remainingAttempts = 3;

  @override
  void dispose() {
    _otpController.dispose();

    super.dispose();
  }

  String _maskPhone(
      String phone,
      ) {
    if (phone.length <= 7) {
      return phone;
    }

    final first =
    phone.substring(
      0,
      5,
    );

    final last =
    phone.substring(
      phone.length - 4,
    );

    return '$first•••$last';
  }

  void _verifyOtp() {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final entered =
    _otpController.text.trim();

    if (entered ==
        widget.testingOtp) {
      Navigator.pop(
        context,
        true,
      );

      return;
    }

    setState(() {
      _remainingAttempts--;
    });

    _otpController.clear();

    if (_remainingAttempts <= 0) {
      Navigator.pop(
        context,
        false,
      );

      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          'Incorrect verification code. '
              '$_remainingAttempts attempt(s) remaining.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
      const Text(
        'Verify Phone Number',
      ),
      content:
      SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              const Icon(
                Icons
                    .sms_outlined,
                size: 46,
              ),

              const SizedBox(
                height: 16,
              ),

              const Text(
                'A 6-digit verification code has been sent to',
                textAlign:
                TextAlign.center,
              ),

              const SizedBox(
                height: 6,
              ),

              Text(
                _maskPhone(
                  widget.phoneNumber,
                ),
                textAlign:
                TextAlign.center,
                style:
                const TextStyle(
                  fontWeight:
                  FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              const SizedBox(
                height: 22,
              ),

              TextFormField(
                controller:
                _otpController,
                autofocus: true,
                keyboardType:
                TextInputType.number,
                textAlign:
                TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter
                      .digitsOnly,
                  LengthLimitingTextInputFormatter(
                    6,
                  ),
                ],
                decoration:
                const InputDecoration(
                  labelText:
                  'Verification Code',
                  hintText:
                  '6-digit code',
                  border:
                  OutlineInputBorder(),
                  prefixIcon:
                  Icon(
                    Icons
                        .lock_outline,
                  ),
                ),
                onFieldSubmitted: (_) {
                  _verifyOtp();
                },
                validator: (value) {
                  if (value == null ||
                      value.isEmpty) {
                    return 'Please enter the verification code';
                  }

                  if (!RegExp(
                    r'^\d{6}$',
                  ).hasMatch(
                    value,
                  )) {
                    return 'Enter a 6-digit code';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 12,
              ),

              Text(
                'Attempts remaining: $_remainingAttempts',
                style:
                const TextStyle(
                  fontSize: 11,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              const Text(
                'For prototype testing, SMS delivery is simulated.',
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  fontSize: 10,
                ),
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
              false,
            );
          },
          child:
          const Text(
            'Cancel',
          ),
        ),

        FilledButton(
          onPressed:
          _verifyOtp,
          child:
          const Text(
            'Verify',
          ),
        ),
      ],
    );
  }
}

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
    if (!_formKey.currentState!
        .validate()) {
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
      title:
      const Text(
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

              if (!RegExp(
                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
              ).hasMatch(
                email,
              )) {
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
          child:
          const Text(
            'Cancel',
          ),
        ),

        FilledButton(
          onPressed:
          _submit,
          child:
          const Text(
            'Continue',
          ),
        ),
      ],
    );
  }
}

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

  bool _obscurePassword =
  true;

  bool _obscureConfirmPassword =
  true;

  @override
  void dispose() {
    _passwordController.dispose();

    _confirmPasswordController.dispose();

    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!
        .validate()) {
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
      title:
      const Text(
        'Change Password',
      ),
      content:
      SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
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
                      _passwordController
                          .text) {
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
          child:
          const Text(
            'Cancel',
          ),
        ),

        FilledButton(
          onPressed:
          _submit,
          child:
          const Text(
            'Update',
          ),
        ),
      ],
    );
  }
}