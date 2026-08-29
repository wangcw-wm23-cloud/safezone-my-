import 'package:flutter/material.dart';

import '../services/state_risk_service.dart';
import '../widgets/cloud_malaysia_risk_map.dart';

// ============================================================
// MALAYSIA OVERVIEW SCREEN
//
// UI POLISH ONLY
//
// DATA / CALCULATION REMAINS INSIDE:
// StateRiskService
//
// MAP REMAINS INSIDE:
// CloudMalaysiaRiskMap
// ============================================================

class MalaysiaOverviewScreen extends StatefulWidget {
  const MalaysiaOverviewScreen({super.key});

  @override
  State<MalaysiaOverviewScreen> createState() => _MalaysiaOverviewScreenState();
}

class _MalaysiaOverviewScreenState extends State<MalaysiaOverviewScreen> {
  // ============================================================
  // STATUS
  // ============================================================

  bool _loading = true;
  bool _districtLoading = false;

  String? _error;

  // ============================================================
  // DATA
  // ============================================================

  List<StateRiskData> _states = [];

  List<PoliceDistrictData> _districts = [];

  String? _selectedState;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  // ============================================================
  // LOAD STATE DATA
  // ============================================================

  Future<void> _loadData({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final states = await StateRiskService.instance.loadStateRisks(
        refresh: refresh,
      );

      if (!mounted) return;

      setState(() {
        _states = states;
        _loading = false;
      });

      if (_selectedState != null) {
        await _loadDistricts(_selectedState!, refresh: refresh);
      }
    } catch (e) {
      debugPrint('MALAYSIA OVERVIEW LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;

        _error = 'Unable to load Malaysia safety risk information.';
      });
    }
  }

  // ============================================================
  // LOAD POLICE DISTRICT DATA
  // ============================================================

  Future<void> _loadDistricts(String state, {bool refresh = false}) async {
    if (!mounted) return;

    setState(() {
      _districtLoading = true;
      _districts = [];
    });

    try {
      final districts = await StateRiskService.instance
          .loadPoliceDistrictRanking(state, refresh: refresh);

      if (!mounted) return;

      // User may already select another state.
      if (_selectedState != state) {
        return;
      }

      setState(() {
        _districts = districts;
        _districtLoading = false;
      });
    } catch (e) {
      debugPrint('POLICE DISTRICT LOAD ERROR: $e');

      if (!mounted) return;

      if (_selectedState != state) {
        return;
      }

      setState(() {
        _districtLoading = false;
        _districts = [];
      });
    }
  }

  // ============================================================
  // SELECT STATE
  // ============================================================

  Future<void> _selectState(String? state) async {
    if (_selectedState == state) {
      return;
    }

    setState(() {
      _selectedState = state;
      _districts = [];
      _districtLoading = state != null;
    });

    if (state == null) {
      setState(() {
        _districtLoading = false;
      });

      return;
    }

    await _loadDistricts(state);
  }

  // ============================================================
  // SELECTED DATA
  // ============================================================

  StateRiskData? get _selectedData {
    if (_selectedState == null) {
      return null;
    }

    for (final state in _states) {
      if (state.state == _selectedState) {
        return state;
      }
    }

    return null;
  }

  // ============================================================
  // NATIONAL RANKING
  // ============================================================

  List<StateRiskData> get _ranking {
    final values = [..._states];

    values.sort((a, b) => b.riskScore.compareTo(a.riskScore));

    return values;
  }

  // ============================================================
  // DIRECT STATES
  //
  // Excludes inherited Putrajaya / Labuan values from
  // national summary calculations.
  // ============================================================

  List<StateRiskData> get _directStates {
    return _states.where((state) => !state.isInherited).toList();
  }

  // ============================================================
  // HIGHEST RISK
  // ============================================================

  StateRiskData? get _highestRisk {
    if (_directStates.isEmpty) {
      return null;
    }

    final values = [..._directStates];

    values.sort((a, b) => b.riskScore.compareTo(a.riskScore));

    return values.first;
  }

  // ============================================================
  // LOWEST RISK
  // ============================================================

  StateRiskData? get _lowestRisk {
    if (_directStates.isEmpty) {
      return null;
    }

    final values = [..._directStates];

    values.sort((a, b) => a.riskScore.compareTo(b.riskScore));

    return values.first;
  }

  // ============================================================
  // AVERAGE SCORE
  // ============================================================

  double get _averageRisk {
    if (_directStates.isEmpty) {
      return 0;
    }

    final total = _directStates.fold<int>(
      0,
      (sum, state) => sum + state.riskScore,
    );

    return total / _directStates.length;
  }

  // ============================================================
  // MAIN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _loadData(refresh: true),
        child: _buildBody(),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    // ==========================================================
    // LOADING
    // ==========================================================

    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: const [
          SizedBox(height: 150),

          Center(
            child: Column(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),

                SizedBox(height: 14),

                Text(
                  'Loading Malaysia risk overview...',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // ==========================================================
    // ERROR
    // ==========================================================

    if (_error != null) {
      return _buildErrorState();
    }

    // ==========================================================
    // NORMAL
    // ==========================================================

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
      children: [
        // ======================================================
        // PAGE INTRO
        // ======================================================
        _buildPageIntro(),

        const SizedBox(height: 16),

        // ======================================================
        // STATE SELECTOR
        // ======================================================
        _buildStateSelector(),

        const SizedBox(height: 14),

        // ======================================================
        // MAP
        // ======================================================
        _buildMapCard(),

        const SizedBox(height: 24),

        // ======================================================
        // DYNAMIC CONTENT
        // ======================================================
        if (_selectedData == null)
          _buildMalaysiaOverview()
        else
          _buildSelectedState(_selectedData!),
      ],
    );
  }

  // ============================================================
  // PAGE INTRO
  // ============================================================

  Widget _buildPageIntro() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: scheme.primary.withOpacity(0.12),
            ),
            child: Icon(Icons.public_rounded, color: scheme.primary, size: 22),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedState == null
                      ? 'Malaysia Safety Overview'
                      : _shortStateName(_selectedState!),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  _selectedState == null
                      ? 'Compare population-adjusted historical risk across Malaysia.'
                      : 'Viewing historical safety statistics and police district data.',
                  style: const TextStyle(fontSize: 9.5, height: 1.4),
                ),
              ],
            ),
          ),

          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _loadData(refresh: true),
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATE SELECTOR
  // ============================================================

  Widget _buildStateSelector() {
    final scheme = Theme.of(context).colorScheme;

    final stateNames = _states.map((state) => state.state).toList()..sort();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedState ?? '__all__',
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: [
            const DropdownMenuItem(
              value: '__all__',
              child: Row(
                children: [
                  Icon(Icons.language_rounded, size: 19),

                  SizedBox(width: 9),

                  Text(
                    'All Malaysia',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            ...stateNames.map((state) {
              return DropdownMenuItem(
                value: state,
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18),

                    const SizedBox(width: 9),

                    Text(_shortStateName(state)),
                  ],
                ),
              );
            }),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }

            if (value == '__all__') {
              _selectState(null);
            } else {
              _selectState(value);
            }
          },
        ),
      ),
    );
  }

  // ============================================================
  // MAP CARD
  // ============================================================

  Widget _buildMapCard() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ====================================================
          // MAP HEADER
          // ====================================================
          Row(
            children: [
              Container(
                width: 37,
                height: 37,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.blue.withOpacity(0.10),
                ),
                child: const Icon(
                  Icons.map_outlined,
                  size: 20,
                  color: Colors.blue,
                ),
              ),

              const SizedBox(width: 11),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interactive Risk Map',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 2),

                    Text(
                      'Tap a state or use the selector above',
                      style: TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),

              if (_selectedState != null)
                TextButton.icon(
                  onPressed: () => _selectState(null),
                  icon: const Icon(Icons.zoom_out_map_rounded, size: 16),
                  label: const Text('All'),
                ),
            ],
          ),

          const SizedBox(height: 13),

          // ====================================================
          // REAL CLOUD GEOJSON MAP
          // ====================================================
          CloudMalaysiaRiskMap(
            stateData: _states,
            selectedState: _selectedState,
            onStateSelected: (state) {
              _selectState(state);
            },
          ),

          const SizedBox(height: 14),

          // ====================================================
          // LEGEND
          // ====================================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withOpacity(0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 7,
              children: [
                _LegendItem(color: Colors.green, text: 'Low'),

                _LegendItem(color: Colors.amber, text: 'Moderate'),

                _LegendItem(color: Colors.orange, text: 'High'),

                _LegendItem(color: Colors.red, text: 'Very High'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NATIONAL OVERVIEW
  // ============================================================

  Widget _buildMalaysiaOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ======================================================
        // SECTION HEADER
        // ======================================================
        _sectionHeader(
          icon: Icons.analytics_outlined,
          title: 'National Snapshot',
          subtitle:
              'Quick comparison of historical risk across Malaysian states.',
        ),

        const SizedBox(height: 12),

        // ======================================================
        // SUMMARY ROW 1
        // ======================================================
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                icon: Icons.trending_up_rounded,
                title: 'Highest Risk',
                value: _shortStateName(_highestRisk?.state ?? '-'),
                detail: _highestRisk != null
                    ? '${_highestRisk!.riskScore} / 100'
                    : '--',
                accent: Colors.redAccent,
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: _summaryCard(
                icon: Icons.trending_down_rounded,
                title: 'Lowest Risk',
                value: _shortStateName(_lowestRisk?.state ?? '-'),
                detail: _lowestRisk != null
                    ? '${_lowestRisk!.riskScore} / 100'
                    : '--',
                accent: Colors.green,
              ),
            ),
          ],
        ),

        const SizedBox(height: 11),

        // ======================================================
        // SUMMARY ROW 2
        // ======================================================
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                icon: Icons.monitor_heart_outlined,
                title: 'Average Score',
                value: _averageRisk.toStringAsFixed(0),
                detail: '/ 100',
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: _summaryCard(
                icon: Icons.location_city_outlined,
                title: 'Areas Monitored',
                value: '${_states.length}',
                detail: 'states & territories',
              ),
            ),
          ],
        ),

        const SizedBox(height: 26),

        // ======================================================
        // RANKING HEADER
        // ======================================================
        _sectionHeader(
          icon: Icons.leaderboard_outlined,
          title: 'State Risk Ranking',
          subtitle:
              'Higher scores indicate a higher historical crime rate relative to the Malaysia benchmark.',
        ),

        const SizedBox(height: 12),

        _buildStateRanking(),

        const SizedBox(height: 18),

        _buildMethodologyNote(),
      ],
    );
  }

  // ============================================================
  // STATE RANKING
  // ============================================================

  Widget _buildStateRanking() {
    final scheme = Theme.of(context).colorScheme;

    final ranking = _ranking;

    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (int index = 0; index < ranking.length; index++) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _selectState(ranking[index].state),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // =========================================
                      // RANK
                      // =========================================
                      _rankingNumber(index),

                      const SizedBox(width: 11),

                      // =========================================
                      // STATE DETAILS
                      // =========================================
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _shortStateName(ranking[index].state),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),

                                if (ranking[index].isInherited) ...[
                                  const SizedBox(width: 5),

                                  Icon(
                                    Icons.link_rounded,
                                    size: 13,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 6),

                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: ranking[index].riskScore / 100,
                                minHeight: 4,
                                color: _riskColor(ranking[index].riskLevel),
                                backgroundColor: scheme.surfaceContainerHighest,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // =========================================
                      // LEVEL + SCORE
                      // =========================================
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${ranking[index].riskScore}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _riskColor(ranking[index].riskLevel),
                            ),
                          ),

                          const SizedBox(height: 3),

                          _riskBadge(ranking[index].riskLevel, compact: true),
                        ],
                      ),

                      const SizedBox(width: 3),

                      const Icon(Icons.chevron_right_rounded, size: 19),
                    ],
                  ),
                ),
              ),
            ),

            if (index < ranking.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // SELECTED STATE
  // ============================================================

  Widget _buildSelectedState(StateRiskData data) {
    final riskColor = _riskColor(data.riskLevel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ======================================================
        // STATE HERO
        // ======================================================
        _buildStateHero(data, riskColor),

        const SizedBox(height: 14),

        // ======================================================
        // PRIMARY METRICS
        // ======================================================
        Row(
          children: [
            Expanded(
              child: _metricCard(
                icon: Icons.speed_rounded,
                title: 'Crime Rate',
                value: data.crimeRatePer100k.toStringAsFixed(1),
                subtitle: 'per 100,000',
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: _metricCard(
                icon: Icons.history_rounded,
                title: 'Historical Cases',
                value: _formatNumber(data.totalCases),
                subtitle: '${data.crimeYear} crime data',
              ),
            ),
          ],
        ),

        const SizedBox(height: 11),

        // ======================================================
        // CRIME CATEGORY
        // ======================================================
        Row(
          children: [
            Expanded(
              child: _metricCard(
                icon: Icons.shield_outlined,
                title: 'Assault',
                value: _formatNumber(data.assaultCases),
                subtitle: 'violent crime category',
                accent: Colors.orange,
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: _metricCard(
                icon: Icons.home_work_outlined,
                title: 'Property',
                value: _formatNumber(data.propertyCases),
                subtitle: 'property crime category',
                accent: Colors.blue,
              ),
            ),
          ],
        ),

        const SizedBox(height: 11),

        // ======================================================
        // POPULATION
        // ======================================================
        _buildPopulationCard(data),

        // ======================================================
        // GROUPING NOTE
        // ======================================================
        if (data.groupedWith != null) ...[
          const SizedBox(height: 12),

          _buildGroupingCard(data),
        ],

        const SizedBox(height: 26),

        // ======================================================
        // DISTRICT RANKING
        // ======================================================
        _sectionHeader(
          icon: Icons.location_city_outlined,
          title: 'Police District Ranking',
          subtitle:
              'Ranked by total historical crime cases within the selected state.',
        ),

        const SizedBox(height: 12),

        _buildDistrictRanking(),

        const SizedBox(height: 18),

        _buildMethodologyNote(stateDetail: true),
      ],
    );
  }

  // ============================================================
  // STATE HERO
  // ============================================================

  Widget _buildStateHero(StateRiskData data, Color riskColor) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: riskColor.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ====================================================
          // TITLE
          // ====================================================
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: riskColor.withOpacity(0.11),
                ),
                child: Icon(Icons.location_on_rounded, color: riskColor),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _shortStateName(data.state),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      data.isInherited
                          ? 'Grouped historical crime data'
                          : 'Population-adjusted historical risk',
                      style: const TextStyle(fontSize: 9.5),
                    ),
                  ],
                ),
              ),

              _riskBadge(data.riskLevel),
            ],
          ),

          const SizedBox(height: 20),

          // ====================================================
          // SCORE
          // ====================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${data.riskScore}',
                style: TextStyle(
                  fontSize: 44,
                  height: 1,
                  fontWeight: FontWeight.bold,
                  color: riskColor,
                ),
              ),

              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  '/ 100',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),

              const Spacer(),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Risk Level', style: TextStyle(fontSize: 8.5)),

                  const SizedBox(height: 2),

                  Text(
                    data.riskLevel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: riskColor,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 13),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: data.riskScore / 100,
              minHeight: 8,
              color: riskColor,
              backgroundColor: riskColor.withOpacity(0.10),
            ),
          ),

          const SizedBox(height: 13),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: riskColor.withOpacity(0.07),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 17, color: riskColor),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    _riskDescription(data.riskLevel),
                    style: const TextStyle(fontSize: 9.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // POPULATION CARD
  // ============================================================

  Widget _buildPopulationCard(StateRiskData data) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: scheme.primary.withOpacity(0.10),
            ),
            child: Icon(Icons.groups_2_outlined, color: scheme.primary),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Population Baseline',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),

                SizedBox(height: 3),

                Text('DOSM 2025 estimate', style: TextStyle(fontSize: 8.5)),
              ],
            ),
          ),

          Text(
            _formatPopulation(data.population2025),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISTRICT RANKING
  // ============================================================

  Widget _buildDistrictRanking() {
    final scheme = Theme.of(context).colorScheme;

    // ==========================================================
    // LOADING
    // ==========================================================

    if (_districtLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30),
        decoration: _cardDecoration(),
        child: const Column(
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),

            SizedBox(height: 10),

            Text(
              'Loading police district data...',
              style: TextStyle(fontSize: 10),
            ),
          ],
        ),
      );
    }

    // ==========================================================
    // EMPTY
    // ==========================================================

    if (_districts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: _cardDecoration(),
        child: const Column(
          children: [
            Icon(Icons.location_off_outlined, size: 36),

            SizedBox(height: 9),

            Text(
              'No police district data available',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),

            SizedBox(height: 4),

            Text(
              'District statistics are unavailable for this selection.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9),
            ),
          ],
        ),
      );
    }

    final highestCases = _districts.first.totalCases;

    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (int index = 0; index < _districts.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // =============================================
                  // RANK
                  // =============================================
                  _rankingNumber(index),

                  const SizedBox(width: 11),

                  // =============================================
                  // NAME + BAR
                  // =============================================
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _districts[index].district,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 7),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: highestCases == 0
                                ? 0
                                : _districts[index].totalCases / highestCases,
                            minHeight: 4,
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  // =============================================
                  // CASES
                  // =============================================
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatNumber(_districts[index].totalCases),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 1),

                      const Text('cases', style: TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),

            if (index < _districts.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // GROUPING NOTE
  // ============================================================

  Widget _buildGroupingCard(StateRiskData data) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.blue.withOpacity(0.07),
        border: Border.all(color: Colors.blue.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 19, color: Colors.blue),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              data.isInherited
                  ? 'The official PDRM dataset groups ${_shortStateName(data.state)} with ${_shortStateName(data.groupedWith!)}. The displayed historical risk therefore uses the grouped crime data.'
                  : '${_shortStateName(data.groupedWith!)} is included under ${_shortStateName(data.state)} in the official PDRM crime dataset.',
              style: const TextStyle(fontSize: 9.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // METHODOLOGY NOTE
  // ============================================================

  Widget _buildMethodologyNote({bool stateDetail = false}) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: scheme.primary.withOpacity(0.10),
            ),
            child: Icon(
              Icons.verified_outlined,
              size: 18,
              color: scheme.primary,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Data & Methodology',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 4),

                Text(
                  stateDetail
                      ? 'Crime data is sourced from data.gov.my / PDRM. State risk uses historical crime rate relative to the Malaysia benchmark. Police district ranking uses total crime cases because PDRM police districts and DOSM administrative districts are not directly equivalent.'
                      : 'Historical crime data is sourced from data.gov.my / PDRM. Population data is sourced from DOSM. Risk scores compare population-adjusted historical crime rates against the Malaysia benchmark.',
                  style: const TextStyle(fontSize: 9, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 90),

        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.redAccent.withOpacity(0.10),
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              size: 34,
              color: Colors.redAccent,
            ),
          ),
        ),

        const SizedBox(height: 18),

        const Text(
          'Unable to Load Overview',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 6),

        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10),
        ),

        const SizedBox(height: 18),

        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: () => _loadData(refresh: true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ),

        const SizedBox(height: 10),

        Text(
          'Pull down to retry if cached information is available.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 8.5, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            color: scheme.primary.withOpacity(0.10),
          ),
          child: Icon(icon, size: 19, color: scheme.primary),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 2),

              Text(subtitle, style: const TextStyle(fontSize: 9, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String detail,
    Color? accent,
  }) {
    final scheme = Theme.of(context).colorScheme;

    final color = accent ?? scheme.primary;

    return Container(
      height: 122,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 33,
                height: 33,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: color.withOpacity(0.10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),

              const Spacer(),

              Icon(
                Icons.arrow_outward_rounded,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),

          const Spacer(),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 2),

          Text(
            title,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
          ),

          const SizedBox(height: 2),

          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 8, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // METRIC CARD
  // ============================================================

  Widget _metricCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    Color? accent,
  }) {
    final scheme = Theme.of(context).colorScheme;

    final color = accent ?? scheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: color.withOpacity(0.10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),

          const SizedBox(height: 11),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 3),

          Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 2),

          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 7.8),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RANK NUMBER
  // ============================================================

  Widget _rankingNumber(int index) {
    Color background;
    Color foreground;

    if (index == 0) {
      background = Colors.amber.withOpacity(0.18);

      foreground = Colors.amber.shade800;
    } else if (index == 1) {
      background = Colors.blueGrey.withOpacity(0.15);

      foreground = Colors.blueGrey.shade600;
    } else if (index == 2) {
      background = Colors.brown.withOpacity(0.14);

      foreground = Colors.brown.shade500;
    } else {
      background = Theme.of(context).colorScheme.surfaceContainerHighest;

      foreground = Theme.of(context).colorScheme.onSurface;
    }

    return Container(
      width: 31,
      height: 31,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: background),
      child: Text(
        '${index + 1}',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: foreground,
        ),
      ),
    );
  }

  // ============================================================
  // RISK BADGE
  // ============================================================

  Widget _riskBadge(String level, {bool compact = false}) {
    final color = _riskColor(level);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 5 : 6,
            height: compact ? 5 : 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),

          const SizedBox(width: 5),

          Text(
            level,
            style: TextStyle(
              fontSize: compact ? 7 : 8.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD DECORATION
  // ============================================================

  BoxDecoration _cardDecoration() {
    final scheme = Theme.of(context).colorScheme;

    return BoxDecoration(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: scheme.outlineVariant),
    );
  }

  // ============================================================
  // RISK COLOUR
  // ============================================================

  Color _riskColor(String level) {
    switch (level.toUpperCase()) {
      case 'VERY HIGH':
        return Colors.red.shade500;

      case 'HIGH':
        return Colors.orange.shade600;

      case 'MODERATE':
      case 'MEDIUM':
        return Colors.amber.shade600;

      case 'LOW':
        return Colors.green.shade500;

      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // RISK DESCRIPTION
  // ============================================================

  String _riskDescription(String level) {
    switch (level.toUpperCase()) {
      case 'VERY HIGH':
        return 'Historical crime rate is significantly above the Malaysia benchmark after population adjustment.';

      case 'HIGH':
        return 'Historical crime rate is above the Malaysia benchmark after population adjustment.';

      case 'MODERATE':
      case 'MEDIUM':
        return 'Historical crime rate is around the moderate range compared with the Malaysia benchmark.';

      case 'LOW':
      default:
        return 'Historical crime rate is comparatively lower than the Malaysia benchmark.';
    }
  }

  // ============================================================
  // SHORT STATE NAME
  // ============================================================

  String _shortStateName(String state) {
    switch (state) {
      case 'W.P. Kuala Lumpur':
        return 'Kuala Lumpur';

      case 'W.P. Putrajaya':
        return 'Putrajaya';

      case 'W.P. Labuan':
        return 'Labuan';

      default:
        return state;
    }
  }

  // ============================================================
  // FORMAT POPULATION
  // ============================================================

  String _formatPopulation(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return '$value';
  }

  // ============================================================
  // FORMAT NUMBER
  // ============================================================

  String _formatNumber(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }
}

// ============================================================
// LEGEND ITEM
// ============================================================

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),

        const SizedBox(width: 5),

        Text(
          text,
          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
