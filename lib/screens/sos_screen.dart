import 'package:flutter/material.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  String? selectedEmergency;
  bool isConfirmed = false;

  final List<Map<String, dynamic>> emergencyTypes = [
    {
      'title': 'Kidnapping',
      'icon': Icons.person_off,
      'color': Colors.redAccent,
    },
    {
      'title': 'Robbery',
      'icon': Icons.warning_amber_rounded,
      'color': Colors.orangeAccent,
    },
    {
      'title': 'Assault',
      'icon': Icons.shield_outlined,
      'color': Colors.deepOrangeAccent,
    },
    {
      'title': 'Medical Emergency',
      'icon': Icons.medical_services_outlined,
      'color': Colors.cyanAccent,
    },
  ];

  void _confirmEmergency() {
    if (selectedEmergency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an emergency type first.'),
        ),
      );
      return;
    }

    setState(() {
      isConfirmed = true;
    });
  }

  void _sendSos() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'SOS activated: $selectedEmergency',
        ),
        backgroundColor: Colors.redAccent,
      ),
    );

    // 下一步我们会在这里接：
    // 1. Firebase Firestore
    // 2. Current GPS location
    // 3. Live tracking
    // 4. Nearby users within 1KM
  }

  void _resetFlow() {
    setState(() {
      selectedEmergency = null;
      isConfirmed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07111F),
        elevation: 0,
        title: const Text(
          'Emergency SOS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: !isConfirmed
                ? _buildStepOne()
                : _buildStepTwo(),
          ),
        ),
      ),
    );
  }

  Widget _buildStepOne() {
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STEP 1',
          style: TextStyle(
            color: Colors.cyanAccent,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'What is happening?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select the emergency type. Your location will be attached in the next step.',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),

        Expanded(
          child: GridView.builder(
            itemCount: emergencyTypes.length,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final item = emergencyTypes[index];
              final bool isSelected =
                  selectedEmergency == item['title'];

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedEmergency = item['title'];
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? item['color'].withOpacity(0.16)
                        : const Color(0xFF0D1B2C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? item['color']
                          : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item['icon'],
                          size: 42,
                          color: item['color'],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          item['title'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _confirmEmergency,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepTwo() {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STEP 2',
          style: TextStyle(
            color: Colors.orangeAccent,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Confirm SOS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2C),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.redAccent.withOpacity(0.5),
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.sos_rounded,
                color: Colors.redAccent,
                size: 70,
              ),
              const SizedBox(height: 14),
              Text(
                selectedEmergency ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your current location will be shared with nearby verified users.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton.icon(
            onPressed: _sendSos,
            icon: const Icon(
              Icons.sos_rounded,
              size: 28,
            ),
            label: const Text(
              'SEND SOS NOW',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _resetFlow,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(
                color: Colors.white24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Back'),
          ),
        ),
      ],
    );
  }
}