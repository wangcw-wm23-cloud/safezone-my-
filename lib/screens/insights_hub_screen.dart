import 'package:flutter/material.dart';

import 'malaysia_overview_screen.dart';
import 'safety_insights_screen.dart';

class InsightsHubScreen extends StatefulWidget {
  const InsightsHubScreen({super.key});

  @override
  State<InsightsHubScreen> createState() => _InsightsHubScreenState();
}

class _InsightsHubScreenState extends State<InsightsHubScreen> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: colorScheme.surfaceContainer,
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _switchButton(
                      index: 0,
                      icon: Icons.bar_chart_rounded,
                      label: 'Data',
                    ),
                  ),

                  const SizedBox(width: 4),

                  Expanded(
                    child: _switchButton(
                      index: 1,
                      icon: Icons.public_rounded,
                      label: 'Overview',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        Expanded(
          child: IndexedStack(
            index: _currentPage,
            children: const [
              // =================================================
              // YOUR FRIEND'S EXISTING DATA.GOV.MY SCREEN
              // =================================================
              SafetyInsightsScreen(),

              // =================================================
              // NEW MALAYSIA OVERVIEW
              // =================================================
              MalaysiaOverviewScreen(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _switchButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _currentPage == index;

    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _currentPage = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? colorScheme.primary : Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
            ),

            const SizedBox(width: 7),

            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
