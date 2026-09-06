import 'package:flutter/material.dart';

import 'malaysia_overview_screen.dart';
import 'safety_insights_screen.dart';



class InsightsHubScreen extends StatefulWidget {
  const InsightsHubScreen({super.key});

  @override
  State<InsightsHubScreen> createState() => _InsightsHubScreenState();
}

class _InsightsHubScreenState extends State<InsightsHubScreen> {


  int _selectedIndex = 0;



  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,

      body: SafeArea(
        child: Column(
          children: [

            _buildHeader(),


            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: _buildSegmentedControl(),
            ),


            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: const [

                  SafetyInsightsScreen(),


                  MalaysiaOverviewScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildHeader() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: scheme.primary.withOpacity(0.12),
            ),
            child: Icon(
              Icons.analytics_outlined,
              color: scheme.primary,
              size: 24,
            ),
          ),

          const SizedBox(width: 13),


          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insights',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                SizedBox(height: 3),

                Text(
                  'Explore official Malaysian safety data and risk trends.',
                  style: TextStyle(fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),


          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: scheme.surfaceContainer,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: IconButton(
              tooltip: 'About Insights',
              padding: EdgeInsets.zero,
              onPressed: _showInsightsInfo,
              icon: const Icon(Icons.info_outline_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildSegmentedControl() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 54,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [

          Expanded(
            child: _buildSegmentButton(
              index: 0,
              icon: Icons.bar_chart_rounded,
              label: 'Data',
            ),
          ),

          const SizedBox(width: 5),


          Expanded(
            child: _buildSegmentButton(
              index: 1,
              icon: Icons.public_rounded,
              label: 'Overview',
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildSegmentButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final scheme = Theme.of(context).colorScheme;

    final selected = _selectedIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () {
          if (_selectedIndex == index) {
            return;
          }

          setState(() {
            _selectedIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: selected ? scheme.primary : Colors.transparent,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),

              const SizedBox(width: 7),

              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Future<void> _showInsightsInfo() async {
    final scheme = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        color: scheme.primary.withOpacity(0.12),
                      ),
                      child: Icon(
                        Icons.insights_rounded,
                        color: scheme.primary,
                      ),
                    ),

                    const SizedBox(width: 12),

                    const Expanded(
                      child: Text(
                        'About Safety Insights',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),


                _buildInfoRow(
                  icon: Icons.bar_chart_rounded,
                  title: 'Data',
                  description:
                      'Explore detailed historical crime statistics and official safety data.',
                ),

                const SizedBox(height: 14),


                _buildInfoRow(
                  icon: Icons.public_rounded,
                  title: 'Overview',
                  description:
                      'Compare population-adjusted historical risk across Malaysian states and police districts.',
                ),

                const SizedBox(height: 18),


                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: scheme.surfaceContainer,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified_outlined, size: 19),

                      SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          'Insights uses official Malaysian public datasets. Historical risk is informational and does not represent a live emergency prediction.',
                          style: TextStyle(fontSize: 10, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }



  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: scheme.primary.withOpacity(0.10),
          ),
          child: Icon(icon, size: 20, color: scheme.primary),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                description,
                style: const TextStyle(fontSize: 10, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
