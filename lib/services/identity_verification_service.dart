import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IdentityScanResult {
  final String? fullName;
  final String? icNumber;
  final String rawText;

  const IdentityScanResult({
    required this.fullName,
    required this.icNumber,
    required this.rawText,
  });
}

class IdentityVerificationService {
  IdentityVerificationService._();

  static final IdentityVerificationService instance =
      IdentityVerificationService._();

  final SupabaseClient supabase = Supabase.instance.client;

  Future<IdentityScanResult> scanIdentityCard(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final result = await recognizer.processImage(inputImage);

      final rawText = result.text.trim();

      debugPrint('================ IDENTITY OCR ================');

      debugPrint(rawText);

      debugPrint('==============================================');

      final icNumber = _extractMalaysianIc(rawText);

      final fullName = _extractName(rawText, icNumber);

      return IdentityScanResult(
        fullName: fullName,

        icNumber: icNumber,

        rawText: rawText,
      );
    } finally {
      await recognizer.close();
    }
  }

  String? _extractMalaysianIc(String text) {
    final formatted = RegExp(r'\b\d{6}[-\s]?\d{2}[-\s]?\d{4}\b');

    final match = formatted.firstMatch(text);

    if (match == null) {
      return null;
    }

    final raw = match.group(0);

    if (raw == null) {
      return null;
    }

    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length != 12) {
      return null;
    }

    return '${digits.substring(0, 6)}-'
        '${digits.substring(6, 8)}-'
        '${digits.substring(8, 12)}';
  }


  String? _extractName(String text, String? icNumber) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return null;
    }

    final ignoreWords = <String>[
      'MALAYSIA',
      'KAD PENGENALAN',
      'IDENTITY CARD',
      'WARGANEGARA',
      'LELAKI',
      'PEREMPUAN',
    ];

    for (final line in lines) {
      final upper = line.toUpperCase();

      if (ignoreWords.any((word) => upper.contains(word))) {
        continue;
      }

      final digits = line.replaceAll(RegExp(r'[^0-9]'), '');

      if (digits.length >= 6) {
        continue;
      }

      final letters = line.replaceAll(RegExp(r'[^A-Za-z ]'), '');

      if (letters.trim().length < 4) {
        continue;
      }

      final letterCount = letters.replaceAll(' ', '').length;

      if (letterCount < 4) {
        continue;
      }

      return line;
    }

    return null;
  }


  Future<void> saveVerifiedIdentity({
    required String fullName,
    required String icNumber,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user.');
    }

    final normalizedName = fullName.trim();

    final normalizedIc = _normalizeIc(icNumber);

    if (normalizedName.isEmpty) {
      throw Exception('Full name is required.');
    }

    if (!_isValidIc(normalizedIc)) {
      throw Exception('Invalid Malaysian IC number.');
    }

    final now = DateTime.now().toUtc().toIso8601String();


    await supabase.from('identity_verifications').upsert({
      'user_id': user.id,

      'full_name': normalizedName,

      'ic_number': normalizedIc,

      'verification_status': 'verified',

      'verified_at': now,

      'updated_at': now,
    }, onConflict: 'user_id');

    await supabase
        .from('profiles')
        .update({
          'full_name': normalizedName,

          'identity_verified': true,

          'updated_at': now,
        })
        .eq('id', user.id);
  }


  Future<bool> isIdentityVerified() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return false;
    }

    final profile = await supabase
        .from('profiles')
        .select('identity_verified')
        .eq('id', user.id)
        .maybeSingle();

    return profile?['identity_verified'] == true;
  }

  Future<Map<String, dynamic>?> getVerification() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    return await supabase
        .from('identity_verifications')
        .select('full_name, ic_number, verification_status, verified_at')
        .eq('user_id', user.id)
        .maybeSingle();
  }

  String _normalizeIc(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length != 12) {
      return value.trim();
    }

    return '${digits.substring(0, 6)}-'
        '${digits.substring(6, 8)}-'
        '${digits.substring(8, 12)}';
  }

  bool _isValidIc(String value) {
    return RegExp(r'^\d{6}-\d{2}-\d{4}$').hasMatch(value);
  }
}
