import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.support_agent_rounded, size: 70),

            const SizedBox(height: 15),

            const Text(
              'How Can We Help?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              'Find information about SafeZone features and emergency use.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 25),

            _faq(
              context,
              question: 'How does SOS work?',
              answer:
                  'When SOS is activated and confirmed, SafeZone creates an emergency incident and shares your live location with eligible nearby users.',
            ),

            _faq(
              context,
              question: 'Who can see my SOS?',
              answer:
                  'SafeZone is designed to surface active emergency incidents to verified users within the supported nearby range.',
            ),

            _faq(
              context,
              question: 'Why do I need to bind my device?',
              answer:
                  'Device binding improves account security and helps prevent unauthorised use of emergency functions.',
            ),

            _faq(
              context,
              question: 'Why is my phone number required?',
              answer:
                  'Your phone number provides additional contact information that may be useful for emergency identification and communication.',
            ),

            _faq(
              context,
              question: 'What does the Safety Risk level mean?',
              answer:
                  'The Safety Risk level is based on historical information for the selected area. It is intended for awareness and is not a prediction that an incident will occur.',
            ),

            _faq(
              context,
              question: 'Where does historical crime data come from?',
              answer:
                  'SafeZone uses available Malaysian government open data from data.gov.my for historical safety analysis.',
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Theme.of(context).colorScheme.surfaceContainer,
              ),
              child: const Column(
                children: [
                  Icon(Icons.info_outline_rounded, size: 32),

                  SizedBox(height: 10),

                  Text(
                    'About SafeZone MY',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 8),

                  Text(
                    'SafeZone MY is a mobile safety platform '
                    'designed to improve safety awareness and '
                    'support nearby emergency assistance.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _faq(
    BuildContext context, {
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: [
          Text(answer, style: const TextStyle(height: 1.5, fontSize: 13)),
        ],
      ),
    );
  }
}
