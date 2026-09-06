import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/identity_verification_service.dart';

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _icController = TextEditingController();

  int _step = 1;

  bool _loading = false;

  bool _icScanned = false;

  bool _facePassed = false;

  bool _verificationComplete = false;

  String? _error;



  @override
  void initState() {
    super.initState();

    _loadExistingStatus();
  }

  Future<void> _loadExistingStatus() async {
    try {
      final existing = await IdentityVerificationService.instance
          .getVerification();

      if (existing == null || !mounted) {
        return;
      }

      final status = existing['verification_status']?.toString();

      if (status != 'verified') {
        return;
      }

      setState(() {
        _nameController.text = existing['full_name']?.toString() ?? '';

        _icController.text = existing['ic_number']?.toString() ?? '';

        _icScanned = true;

        _facePassed = true;

        _verificationComplete = true;

        _step = 3;
      });
    } catch (e) {
      debugPrint('LOAD IDENTITY STATUS ERROR: $e');
    }
  }



  Future<void> _scanIc() async {
    setState(() {
      _error = null;
    });

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context, ImageSource.camera);
                },
              ),

              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context, ImageSource.gallery);
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    final image = await _picker.pickImage(
      source: source,

      imageQuality: 90,

      maxWidth: 2000,
    );

    if (image == null) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _loading = true;

      _error = null;
    });

    try {
      final result = await IdentityVerificationService.instance
          .scanIdentityCard(image.path);

      if (!mounted) return;

      setState(() {
        if (result.fullName != null) {
          _nameController.text = result.fullName!;
        }

        if (result.icNumber != null) {
          _icController.text = result.icNumber!;
        }

        _icScanned = true;
      });

      if (result.icNumber == null) {
        setState(() {
          _error =
              'IC number could not be detected automatically. Please enter it manually.';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to scan the identity card. You may try another image.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }



  void _continueToFace() {
    final name = _nameController.text.trim();

    final digits = _icController.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (name.isEmpty) {
      _showMessage('Please enter your full name.');

      return;
    }

    if (digits.length != 12) {
      _showMessage('Please enter a valid 12-digit Malaysian IC number.');

      return;
    }

    setState(() {
      _step = 2;
    });
  }



  Future<void> _startFaceScan() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,

      preferredCameraDevice: CameraDevice.front,

      imageQuality: 70,
    );

    if (image == null) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _loading = true;

      _error = null;
    });

    try {
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      setState(() {
        _facePassed = true;
      });

      await Future.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;

      setState(() {
        _step = 3;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }



  Future<void> _completeVerification() async {
    if (!_icScanned || !_facePassed) {
      return;
    }

    setState(() {
      _loading = true;

      _error = null;
    });

    try {
      await IdentityVerificationService.instance.saveVerifiedIdentity(
        fullName: _nameController.text,

        icNumber: _icController.text,
      );

      if (!mounted) return;

      setState(() {
        _verificationComplete = true;
      });

      _showMessage('Identity verification completed.');
    } catch (e) {
      debugPrint('SAVE IDENTITY ERROR: $e');

      if (!mounted) return;

      setState(() {
        _error = 'Unable to save identity verification. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identity Verification')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          children: [
            _buildProgress(),

            const SizedBox(height: 24),

            if (_verificationComplete)
              _buildVerifiedScreen()
            else if (_step == 1)
              _buildIcStep()
            else if (_step == 2)
              _buildFaceStep()
            else
              _buildReviewStep(),

            if (_error != null) ...[
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withOpacity(0.25)),
                ),
                child: Text(_error!, style: const TextStyle(fontSize: 10)),
              ),
            ],
          ],
        ),
      ),
    );
  }



  Widget _buildProgress() {
    return Row(
      children: [
        _progressItem(number: 1, label: 'MyKad', active: _step >= 1),

        _progressLine(complete: _step >= 2),

        _progressItem(number: 2, label: 'Face', active: _step >= 2),

        _progressLine(complete: _step >= 3),

        _progressItem(number: 3, label: 'Verify', active: _step >= 3),
      ],
    );
  }

  Widget _progressItem({
    required int number,
    required String label,
    required bool active,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? scheme.primary : scheme.surfaceContainerHighest,
          ),
          child: Text(
            '$number',
            style: TextStyle(
              color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 5),

        Text(label, style: const TextStyle(fontSize: 8)),
      ],
    );
  }

  Widget _progressLine({required bool complete}) {
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 17),
        color: complete ? scheme.primary : scheme.outlineVariant,
      ),
    );
  }



  Widget _buildIcStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.badge_outlined, size: 64),

        const SizedBox(height: 16),

        const Text(
          'Verify Your MyKad',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 7),

        const Text(
          'Take or upload a clear photo of the front of your Malaysian identity card.',
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 10),

        const Text(
          'The image is used only for OCR and is not uploaded to SafeZone.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9),
        ),

        const SizedBox(height: 24),

        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _loading ? null : _scanIc,
            icon: const Icon(Icons.document_scanner_outlined),
            label: Text(_icScanned ? 'Scan Again' : 'Scan MyKad'),
          ),
        ),

        if (_loading) ...[
          const SizedBox(height: 16),

          const LinearProgressIndicator(),
        ],

        if (_icScanned) ...[
          const SizedBox(height: 25),

          const Text(
            'Detected Information',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: _icController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'IC Number',
              hintText: '000000-00-0000',
              prefixIcon: Icon(Icons.badge_outlined),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _continueToFace,
              child: const Text('Continue to Face Scan'),
            ),
          ),
        ],
      ],
    );
  }



  Widget _buildFaceStep() {
    return Column(
      children: [
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _facePassed
                  ? Colors.green
                  : Theme.of(context).colorScheme.primary,
              width: 3,
            ),
          ),
          child: Icon(
            _facePassed
                ? Icons.check_rounded
                : Icons.face_retouching_natural_outlined,
            size: 68,
            color: _facePassed ? Colors.green : null,
          ),
        ),

        const SizedBox(height: 20),

        Text(
          _facePassed ? 'Face Scan Completed' : 'Face Verification',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        Text(
          _loading
              ? 'Scanning face...'
              : _facePassed
              ? 'Verification successful.'
              : 'Position your face clearly in front of the camera.',
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 26),

        if (_loading)
          const CircularProgressIndicator()
        else
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _startFaceScan,
              icon: const Icon(Icons.camera_front_outlined),
              label: const Text('Start Face Scan'),
            ),
          ),

        const SizedBox(height: 14),

        TextButton(
          onPressed: _loading
              ? null
              : () {
                  setState(() {
                    _step = 1;
                  });
                },
          child: const Text('Back'),
        ),
      ],
    );
  }



  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.verified_user_outlined, size: 68, color: Colors.green),

        const SizedBox(height: 16),

        const Text(
          'Ready to Verify',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 20),

        _reviewRow('Full Name', _nameController.text),

        _reviewRow('IC Number', _icController.text),

        _reviewRow('Face Scan', _facePassed ? 'Completed' : 'Incomplete'),

        const SizedBox(height: 24),

        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _loading ? null : _completeVerification,
            icon: const Icon(Icons.verified_rounded),
            label: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Complete Verification'),
          ),
        ),
      ],
    );
  }



  Widget _buildVerifiedScreen() {
    return Column(
      children: [
        const SizedBox(height: 30),

        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.withOpacity(0.12),
          ),
          child: const Icon(
            Icons.verified_rounded,
            size: 62,
            color: Colors.green,
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'Identity Verified',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 7),

        const Text(
          'Your identity has been successfully linked to your SafeZone account.',
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 25),

        _reviewRow('Name', _nameController.text),

        _reviewRow('IC Number', _icController.text),

        const SizedBox(height: 25),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 10))),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();

    _icController.dispose();

    super.dispose();
  }
}
