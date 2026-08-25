import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/data_gov_crime_service.dart';

class SafetyInsightsScreen extends StatefulWidget {
  const SafetyInsightsScreen({super.key});

  @override
  State<SafetyInsightsScreen> createState() => _SafetyInsightsScreenState();
}

class _SafetyInsightsScreenState extends State<SafetyInsightsScreen> {
  final DataGovCrimeService _crimeService = DataGovCrimeService();

  String _selectedState = 'W.P. Kuala Lumpur';

  String _selectedDistrict = 'All Districts';

  List<CrimeRecord> _records = [];

  List<String> _districts = ['All Districts'];

  CrimeInsight? _insight;

  bool _isLoading = true;

  String? _error;

  @override
  void initState() {
    super.initState();

    _loadGovernmentData();
  }

  // ============================================================
  // LOAD DATA.GOV.MY
  // ============================================================

  Future<void> _loadGovernmentData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final records = await _crimeService.getCrimeRecordsByState(
        _selectedState,
      );

      final districts = _crimeService.getDistricts(records);

      if (!mounted) return;

      setState(() {
        _records = records;

        _districts = ['All Districts', ...districts];

        if (!_districts.contains(_selectedDistrict)) {
          _selectedDistrict = 'All Districts';
        }

        _buildInsight();

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('DATA GOV ERROR: $e');

      if (!mounted) return;

      setState(() {
        _error = 'Unable to load data.gov.my crime data.';
        _isLoading = false;
      });
    }
  }

  void _buildInsight() {
    _insight = _crimeService.buildInsight(
      records: _records,
      state: _selectedState,
      district: _selectedDistrict,
    );
  }

  void _changeDistrict(String? value) {
    if (value == null) return;

    setState(() {
      _selectedDistrict = value;

      _buildInsight();
    });
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadGovernmentData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          children: [
            // ==================================================
            // TITLE
            // ==================================================
            const Text(
              'Safety Insights',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 5),

            const Text(
              'Historical government crime data '
              'and SafeZone community statistics.',
              style: TextStyle(fontSize: 12),
            ),

            const SizedBox(height: 26),

            // ==================================================
            // GOVERNMENT HEADER
            // ==================================================
            _sectionHeader(
              icon: Icons.account_balance_outlined,
              title: 'Government Crime Data',
              subtitle: 'Royal Malaysia Police • data.gov.my',
            ),

            const SizedBox(height: 14),

            // ==================================================
            // FILTER
            // ==================================================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Explore Area',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),

                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: _selectedState,
                    decoration: const InputDecoration(
                      labelText: 'State',
                      prefixIcon: Icon(Icons.map_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: DataGovCrimeService.states.map((state) {
                      return DropdownMenuItem(value: state, child: Text(state));
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _selectedState = value;

                        _selectedDistrict = 'All Districts';
                      });

                      _loadGovernmentData();
                    },
                  ),

                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: _selectedDistrict,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Police District',
                      prefixIcon: Icon(Icons.location_city_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: _districts.map((district) {
                      return DropdownMenuItem(
                        value: district,
                        child: Text(district, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: _isLoading ? null : _changeDistrict,
                  ),

                  const SizedBox(height: 10),

                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16),

                      SizedBox(width: 7),

                      Expanded(
                        child: Text(
                          'District refers to PDRM police district, '
                          'which may differ from an administrative district.',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 70),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _buildError()
            else if (_insight != null)
              ..._buildGovernmentContent(_insight!),

            const SizedBox(height: 34),

            // ==================================================
            // SAFEZONE SECTION
            // ==================================================
            _sectionHeader(
              icon: Icons.shield_outlined,
              title: 'SafeZone Community',
              subtitle: 'Live statistics generated by the SafeZone platform',
            ),

            const SizedBox(height: 14),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _safeZoneStat(
                  icon: Icons.sos_rounded,
                  value: '0',
                  label: 'Total SOS',
                ),

                _safeZoneStat(
                  icon: Icons.warning_amber_rounded,
                  value: '0',
                  label: 'Active Incidents',
                ),

                _safeZoneStat(
                  icon: Icons.check_circle_outline,
                  value: '0',
                  label: 'Resolved',
                ),

                _safeZoneStat(
                  icon: Icons.volunteer_activism_outlined,
                  value: '0',
                  label: 'Users Assisted',
                ),
              ],
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: _cardDecoration(),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.database_outlined, size: 21),

                  SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      'SafeZone community statistics will '
                      'automatically populate after the SOS '
                      'and response modules are connected to Supabase.',
                      style: TextStyle(fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // GOVERNMENT CONTENT
  // ============================================================

  List<Widget> _buildGovernmentContent(CrimeInsight insight) {
    if (insight.latestYear == 0) {
      return [
        Container(
          padding: const EdgeInsets.all(30),
          decoration: _cardDecoration(),
          child: const Center(
            child: Text(
              'No government crime data is available '
              'for this selection.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ];
    }

    return [
      // ========================================================
      // LAST AVAILABLE YEAR
      // ========================================================
      Row(
        children: [
          Expanded(
            child: _summaryCard(
              label: '${insight.latestYear} Crimes',
              value: _formatNumber(insight.latestTotal),
              icon: Icons.analytics_outlined,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: _summaryCard(
              label: 'Change vs Previous',
              value: _formatChange(insight),
              icon: _changeIcon(insight),
            ),
          ),
        ],
      ),

      const SizedBox(height: 12),

      Row(
        children: [
          Expanded(
            child: _summaryCard(
              label: 'Violent Crime',
              value: _formatNumber(insight.violentTotal),
              icon: Icons.warning_amber_rounded,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: _summaryCard(
              label: 'Property Crime',
              value: _formatNumber(insight.propertyTotal),
              icon: Icons.home_outlined,
            ),
          ),
        ],
      ),

      const SizedBox(height: 20),

      // ========================================================
      // TREND
      // ========================================================
      Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historical Crime Trend',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            Text(
              '${insight.district} • ${insight.state}',
              style: const TextStyle(fontSize: 11),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 220,
              child: CrimeTrendChart(yearlyTotals: insight.yearlyTotals),
            ),
          ],
        ),
      ),

      const SizedBox(height: 20),

      // ========================================================
      // CRIME TYPES
      // ========================================================
      Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${insight.latestYear} Crime Types',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            const Text(
              'Breakdown of recorded crimes in the latest available year.',
              style: TextStyle(fontSize: 11),
            ),

            const SizedBox(height: 18),

            ..._buildTypeRows(insight),
          ],
        ),
      ),

      const SizedBox(height: 20),

      // ========================================================
      // AUTOMATED INSIGHTS
      // ========================================================
      Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded),

                SizedBox(width: 9),

                Text(
                  'Key Insights',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _insightPoint(_trendInsight(insight)),

            _insightPoint(_categoryInsight(insight)),

            if (insight.topCrimeType != null)
              _insightPoint(
                '${_prettyType(insight.topCrimeType!)} was the largest recorded crime type '
                'for ${insight.latestYear}.',
              ),

            _insightPoint(
              'These statistics are historical and should '
              'support safety awareness rather than be treated '
              'as a prediction of future crime.',
            ),
          ],
        ),
      ),

      const SizedBox(height: 16),

      // ========================================================
      // SOURCE
      // ========================================================
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainer,
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data Source', style: TextStyle(fontWeight: FontWeight.bold)),

            SizedBox(height: 7),

            Text(
              'PDRM Crimes by District & Crime Type',
              style: TextStyle(fontSize: 12),
            ),

            SizedBox(height: 3),

            Text(
              'Source: Royal Malaysia Police (PDRM) '
              'and Department of Statistics Malaysia',
              style: TextStyle(fontSize: 10),
            ),

            SizedBox(height: 3),

            Text(
              'Available data: up to 31 December 2023',
              style: TextStyle(fontSize: 10),
            ),

            SizedBox(height: 7),

            Text(
              'Note: Unreported crimes are not included. '
              'Historical statistics do not indicate that '
              'an area is guaranteed to be safe or unsafe.',
              style: TextStyle(fontSize: 10, height: 1.4),
            ),
          ],
        ),
      ),
    ];
  }

  // ============================================================
  // TYPE ROWS
  // ============================================================

  List<Widget> _buildTypeRows(CrimeInsight insight) {
    final entries = insight.typeTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return [const Text('No crime type data available.')];
    }

    final maxValue = entries.first.value;

    return entries.map((entry) {
      final progress = maxValue == 0 ? 0.0 : entry.value / maxValue;

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _prettyType(entry.key),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                Text(
                  _formatNumber(entry.value),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 7),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: progress, minHeight: 7),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 45),

          const SizedBox(height: 12),

          Text(_error ?? 'Unable to load data.', textAlign: TextAlign.center),

          const SizedBox(height: 15),

          OutlinedButton.icon(
            onPressed: _loadGovernmentData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).colorScheme.primary.withOpacity(0.13),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Text(subtitle, style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 23),

          const SizedBox(height: 13),

          Text(
            value,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 3),

          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _safeZoneStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),

          const Spacer(),

          Text(
            value,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),

          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _insightPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 6),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).colorScheme.surfaceContainer,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    );
  }

  String _formatChange(CrimeInsight insight) {
    final change = insight.yearChangePercent;

    if (change == null) {
      return '-';
    }

    final sign = change > 0 ? '+' : '';

    return '$sign${change.toStringAsFixed(1)}%';
  }

  IconData _changeIcon(CrimeInsight insight) {
    final change = insight.yearChangePercent;

    if (change == null || change == 0) {
      return Icons.horizontal_rule_rounded;
    }

    return change > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded;
  }

  String _trendInsight(CrimeInsight insight) {
    final change = insight.yearChangePercent;

    if (change == null) {
      return 'There is not enough previous-year data '
          'to calculate an annual change.';
    }

    if (change > 0) {
      return 'Recorded crime increased by '
          '${change.abs().toStringAsFixed(1)}% '
          'in ${insight.latestYear} compared with the previous year.';
    }

    if (change < 0) {
      return 'Recorded crime decreased by '
          '${change.abs().toStringAsFixed(1)}% '
          'in ${insight.latestYear} compared with the previous year.';
    }

    return 'Recorded crime remained unchanged '
        'compared with the previous year.';
  }

  String _categoryInsight(CrimeInsight insight) {
    if (insight.propertyTotal > insight.violentTotal) {
      return 'Property crime accounted for more '
          'recorded cases than violent crime '
          'in ${insight.latestYear}.';
    }

    if (insight.violentTotal > insight.propertyTotal) {
      return 'Violent crime accounted for more '
          'recorded cases than property crime '
          'in ${insight.latestYear}.';
    }

    return 'Violent and property crime recorded '
        'the same total in ${insight.latestYear}.';
  }

  String _prettyType(String value) {
    if (value.isEmpty) {
      return 'Unknown';
    }

    return value
        .split('_')
        .map((word) {
          if (word.isEmpty) {
            return '';
          }

          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  String _formatNumber(int value) {
    final text = value.toString();

    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final position = text.length - i;

      buffer.write(text[i]);

      if (position > 1 && position % 3 == 1) {
        buffer.write(',');
      }
    }

    return buffer.toString();
  }
}

// ============================================================
// CRIME TREND CHART
// No extra chart package needed.
// ============================================================

class CrimeTrendChart extends StatelessWidget {
  final Map<int, int> yearlyTotals;

  const CrimeTrendChart({super.key, required this.yearlyTotals});

  @override
  Widget build(BuildContext context) {
    if (yearlyTotals.isEmpty) {
      return const Center(child: Text('No trend data available.'));
    }

    final entries = yearlyTotals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final maxValue = entries.map((entry) => entry.value).fold<int>(0, math.max);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: entries.map((entry) {
            final ratio = maxValue == 0 ? 0.0 : entry.value / maxValue;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      entry.value.toString(),
                      style: const TextStyle(fontSize: 8),
                    ),

                    const SizedBox(height: 5),

                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      height: math.max(5, 150 * ratio),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text('${entry.key}', style: const TextStyle(fontSize: 8)),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
