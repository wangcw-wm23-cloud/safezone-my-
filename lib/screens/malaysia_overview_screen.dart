import 'package:flutter/material.dart';

import '../services/state_risk_service.dart';
import '../widgets/cloud_malaysia_risk_map.dart';

class MalaysiaOverviewScreen extends StatefulWidget {
  const MalaysiaOverviewScreen({
    super.key,
  });

  @override
  State<MalaysiaOverviewScreen> createState() =>
      _MalaysiaOverviewScreenState();
}

class _MalaysiaOverviewScreenState
    extends State<MalaysiaOverviewScreen> {
  // ============================================================
  // LOADING STATUS
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
  // LOAD ALL STATE RISK DATA
  // ============================================================

  Future<void> _loadData({
    bool refresh = false,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final states =
      await StateRiskService.instance.loadStateRisks(
        refresh: refresh,
      );

      if (!mounted) return;

      setState(() {
        _states = states;
        _loading = false;
      });

      // ========================================================
      // IF USER ALREADY SELECTED A STATE
      // REFRESH ITS DISTRICT DATA TOO
      // ========================================================

      if (_selectedState != null) {
        await _loadDistricts(
          _selectedState!,
          refresh: refresh,
        );
      }
    } catch (e) {
      debugPrint(
        'MALAYSIA OVERVIEW LOAD ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;

        _error =
        'Unable to load Malaysia risk information.';
      });
    }
  }

  // ============================================================
  // LOAD POLICE DISTRICTS
  // ============================================================

  Future<void> _loadDistricts(
      String state, {
        bool refresh = false,
      }) async {
    if (!mounted) return;

    setState(() {
      _districtLoading = true;
      _districts = [];
    });

    try {
      final districts =
      await StateRiskService.instance
          .loadPoliceDistrictRanking(
        state,
        refresh: refresh,
      );

      if (!mounted) return;

      // ========================================================
      // USER MAY HAVE SELECTED ANOTHER STATE
      // WHILE DATA WAS LOADING
      // ========================================================

      if (_selectedState != state) {
        return;
      }

      setState(() {
        _districts = districts;
        _districtLoading = false;
      });
    } catch (e) {
      debugPrint(
        'DISTRICT RANKING LOAD ERROR: $e',
      );

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

  Future<void> _selectState(
      String? state,
      ) async {
    if (_selectedState == state) {
      return;
    }

    setState(() {
      _selectedState = state;
      _districts = [];
    });

    // ==========================================================
    // ALL MALAYSIA
    // ==========================================================

    if (state == null) {
      setState(() {
        _districtLoading = false;
      });

      return;
    }

    // ==========================================================
    // SELECTED STATE
    // ==========================================================

    await _loadDistricts(
      state,
    );
  }

  // ============================================================
  // SELECTED STATE DATA
  // ============================================================

  StateRiskData? get _selectedData {
    final selected =
        _selectedState;

    if (selected == null) {
      return null;
    }

    for (final state
    in _states) {
      if (state.state == selected) {
        return state;
      }
    }

    return null;
  }

  // ============================================================
  // STATE RANKING
  // ============================================================

  List<StateRiskData> get _stateRanking {
    final ranking =
    [..._states];

    ranking.sort(
          (a, b) =>
          b.riskScore.compareTo(
            a.riskScore,
          ),
    );

    return ranking;
  }

  // ============================================================
  // DIRECT STATES
  //
  // Remove inherited grouped territories from national
  // average / highest / lowest calculations.
  // ============================================================

  List<StateRiskData> get _directStates {
    return _states
        .where(
          (state) =>
      !state.isInherited,
    )
        .toList();
  }

  // ============================================================
  // HIGHEST RISK
  // ============================================================

  StateRiskData? get _highestRisk {
    if (_directStates.isEmpty) {
      return null;
    }

    final values =
    [..._directStates];

    values.sort(
          (a, b) =>
          b.riskScore.compareTo(
            a.riskScore,
          ),
    );

    return values.first;
  }

  // ============================================================
  // LOWEST RISK
  // ============================================================

  StateRiskData? get _lowestRisk {
    if (_directStates.isEmpty) {
      return null;
    }

    final values =
    [..._directStates];

    values.sort(
          (a, b) =>
          a.riskScore.compareTo(
            b.riskScore,
          ),
    );

    return values.first;
  }

  // ============================================================
  // AVERAGE RISK
  // ============================================================

  double get _averageRisk {
    if (_directStates.isEmpty) {
      return 0;
    }

    final total =
    _directStates.fold<int>(
      0,
          (
          total,
          state,
          ) =>
      total +
          state.riskScore,
    );

    return total /
        _directStates.length;
  }

  // ============================================================
  // RISK COLOUR
  // ============================================================

  Color _riskColor(
      String level,
      ) {
    switch (level.toUpperCase()) {
      case 'VERY HIGH':
        return Colors.red.shade500;

      case 'HIGH':
        return Colors.orange.shade600;

      case 'MODERATE':
        return Colors.amber.shade600;

      case 'LOW':
      default:
        return Colors.green.shade500;
    }
  }

  // ============================================================
  // MAIN
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () =>
            _loadData(
              refresh: true,
            ),
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
        physics:
        const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 220,
          ),
          Center(
            child:
            CircularProgressIndicator(),
          ),
        ],
      );
    }

    // ==========================================================
    // ERROR
    // ==========================================================

    if (_error != null) {
      return ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding:
        const EdgeInsets.all(
          20,
        ),
        children: [
          const SizedBox(
            height: 110,
          ),

          const Icon(
            Icons.cloud_off_outlined,
            size: 55,
          ),

          const SizedBox(
            height: 16,
          ),

          const Text(
            'Unable to Load Risk Overview',
            textAlign:
            TextAlign.center,
            style:
            TextStyle(
              fontSize: 18,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          Text(
            _error!,
            textAlign:
            TextAlign.center,
            style:
            const TextStyle(
              fontSize: 12,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          FilledButton.icon(
            onPressed: () =>
                _loadData(
                  refresh: true,
                ),
            icon:
            const Icon(
              Icons.refresh_rounded,
            ),
            label:
            const Text(
              'Try Again',
            ),
          ),
        ],
      );
    }

    // ==========================================================
    // NORMAL
    // ==========================================================

    return ListView(
      physics:
      const AlwaysScrollableScrollPhysics(),
      padding:
      const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        32,
      ),
      children: [
        // ======================================================
        // HEADER
        // ======================================================

        _buildHeader(),

        const SizedBox(
          height: 18,
        ),

        // ======================================================
        // STATE SELECTOR
        // ======================================================

        _buildStateSelector(),

        const SizedBox(
          height: 15,
        ),

        // ======================================================
        // REAL MALAYSIA MAP
        // ======================================================

        _buildMapCard(),

        const SizedBox(
          height: 24,
        ),

        // ======================================================
        // DYNAMIC CONTENT
        // ======================================================

        if (_selectedData ==
            null)
          _buildMalaysiaOverview()
        else
          _buildSelectedStateOverview(
            _selectedData!,
          ),
      ],
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,
            children: [
              const Text(
                'Malaysia Risk Overview',
                style:
                TextStyle(
                  fontSize: 23,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                _selectedState == null
                    ? 'Explore population-adjusted historical safety risk across Malaysia.'
                    : 'Viewing historical safety information for ${_shortStateName(_selectedState!)}.',
                style:
                const TextStyle(
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          width: 8,
        ),

        IconButton(
          tooltip:
          'Refresh',
          onPressed: () =>
              _loadData(
                refresh: true,
              ),
          icon:
          const Icon(
            Icons.refresh_rounded,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATE SELECTOR
  // ============================================================

  Widget _buildStateSelector() {
    final scheme =
        Theme.of(context)
            .colorScheme;

    final states = _states
        .map(
          (
          state,
          ) =>
      state.state,
    )
        .toList()
      ..sort();

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 3,
      ),
      decoration:
      BoxDecoration(
        color:
        scheme.surfaceContainer,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color:
          scheme.outlineVariant,
        ),
      ),
      child:
      DropdownButtonHideUnderline(
        child:
        DropdownButton<String>(
          value:
          _selectedState ??
              '__all__',
          isExpanded:
          true,
          borderRadius:
          BorderRadius.circular(
            16,
          ),
          icon:
          const Icon(
            Icons
                .keyboard_arrow_down_rounded,
          ),
          items: [
            const DropdownMenuItem(
              value:
              '__all__',
              child: Row(
                children: [
                  Icon(
                    Icons.public_rounded,
                    size: 20,
                  ),

                  SizedBox(
                    width: 10,
                  ),

                  Text(
                    'All Malaysia',
                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            ...states.map(
                  (
                  state,
                  ) {
                return DropdownMenuItem(
                  value:
                  state,
                  child:
                  Text(
                    _shortStateName(
                      state,
                    ),
                  ),
                );
              },
            ),
          ],
          onChanged: (
              value,
              ) {
            if (value == null) {
              return;
            }

            if (value ==
                '__all__') {
              _selectState(
                null,
              );
            } else {
              _selectState(
                value,
              );
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
    final scheme =
        Theme.of(context)
            .colorScheme;

    return Container(
      padding:
      const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        14,
      ),
      decoration:
      BoxDecoration(
        color:
        scheme.surfaceContainer,
        borderRadius:
        BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color:
          scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          // ====================================================
          // MAP TITLE
          // ====================================================

          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration:
                BoxDecoration(
                  color: scheme.primary
                      .withOpacity(
                    0.10,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    11,
                  ),
                ),
                child: Icon(
                  Icons.map_outlined,
                  size: 20,
                  color:
                  scheme.primary,
                ),
              ),

              const SizedBox(
                width: 11,
              ),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'State Risk Map',
                      style:
                      TextStyle(
                        fontSize: 16,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    SizedBox(
                      height: 2,
                    ),

                    Text(
                      'Population-adjusted historical risk',
                      style:
                      TextStyle(
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),

              if (_selectedState !=
                  null)
                TextButton(
                  onPressed: () =>
                      _selectState(
                        null,
                      ),
                  child:
                  const Text(
                    'View All',
                  ),
                ),
            ],
          ),

          const SizedBox(
            height: 15,
          ),

          // ====================================================
          // CLOUD GEOJSON MALAYSIA MAP
          // ====================================================

          CloudMalaysiaRiskMap(
            stateData:
            _states,
            selectedState:
            _selectedState,
            onStateSelected: (
                state,
                ) {
              _selectState(
                state,
              );
            },
          ),

          const SizedBox(
            height: 15,
          ),

          // ====================================================
          // LEGEND
          // ====================================================

          const Center(
            child: Wrap(
              alignment:
              WrapAlignment.center,
              spacing: 15,
              runSpacing: 7,
              children: [
                _LegendItem(
                  color:
                  Colors.green,
                  text: 'Low',
                ),

                _LegendItem(
                  color:
                  Colors.amber,
                  text:
                  'Moderate',
                ),

                _LegendItem(
                  color:
                  Colors.orange,
                  text: 'High',
                ),

                _LegendItem(
                  color:
                  Colors.red,
                  text:
                  'Very High',
                ),
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
      crossAxisAlignment:
      CrossAxisAlignment
          .start,
      children: [
        // ======================================================
        // TITLE
        // ======================================================

        const Text(
          'Malaysia Overview',
          style:
          TextStyle(
            fontSize: 18,
            fontWeight:
            FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 5,
        ),

        const Text(
          'A national comparison based on population-adjusted historical crime data.',
          style:
          TextStyle(
            fontSize: 10,
            height: 1.4,
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        // ======================================================
        // HIGHEST + LOWEST
        // ======================================================

        Row(
          children: [
            Expanded(
              child:
              _summaryCard(
                icon: Icons
                    .trending_up_rounded,
                title:
                'Highest Risk',
                value:
                _shortStateName(
                  _highestRisk
                      ?.state ??
                      '-',
                ),
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child:
              _summaryCard(
                icon: Icons
                    .trending_down_rounded,
                title:
                'Lowest Risk',
                value:
                _shortStateName(
                  _lowestRisk
                      ?.state ??
                      '-',
                ),
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 12,
        ),

        // ======================================================
        // AVERAGE + MONITORED
        // ======================================================

        Row(
          children: [
            Expanded(
              child:
              _summaryCard(
                icon: Icons
                    .analytics_outlined,
                title:
                'Average Score',
                value:
                '${_averageRisk.toStringAsFixed(0)} / 100',
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child:
              _summaryCard(
                icon: Icons
                    .location_on_outlined,
                title:
                'Areas Monitored',
                value:
                '${_states.length}',
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 28,
        ),

        // ======================================================
        // STATE RANKING
        // ======================================================

        Row(
          children: [
            const Expanded(
              child: Text(
                'State Risk Ranking',
                style:
                TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),

            Icon(
              Icons
                  .leaderboard_outlined,
              size: 20,
              color:
              Theme.of(context)
                  .colorScheme
                  .primary,
            ),
          ],
        ),

        const SizedBox(
          height: 5,
        ),

        const Text(
          'Select a state to view its detailed statistics and police district ranking.',
          style:
          TextStyle(
            fontSize: 10,
            height: 1.4,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        _buildStateRanking(),

        const SizedBox(
          height: 18,
        ),

        _buildNationalSourceCard(),
      ],
    );
  }

  // ============================================================
  // STATE RANKING
  // ============================================================

  Widget _buildStateRanking() {
    final ranking =
        _stateRanking;

    return Container(
      decoration:
      _cardDecoration(),
      child: Column(
        children: [
          for (
          int index = 0;
          index < ranking.length;
          index++
          ) ...[
            InkWell(
              borderRadius:
              index == 0
                  ? const BorderRadius.vertical(
                top:
                Radius.circular(
                  18,
                ),
              )
                  : index ==
                  ranking.length -
                      1
                  ? const BorderRadius.vertical(
                bottom:
                Radius.circular(
                  18,
                ),
              )
                  : BorderRadius.zero,
              onTap: () =>
                  _selectState(
                    ranking[index]
                        .state,
                  ),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    // ===========================================
                    // RANK
                    // ===========================================

                    Container(
                      width: 30,
                      height: 30,
                      alignment:
                      Alignment.center,
                      decoration:
                      BoxDecoration(
                        shape:
                        BoxShape.circle,
                        color:
                        _rankingBackground(
                          index,
                        ),
                      ),
                      child: Text(
                        '${index + 1}',
                        style:
                        TextStyle(
                          fontSize: 11,
                          fontWeight:
                          FontWeight.bold,
                          color:
                          _rankingForeground(
                            index,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 11,
                    ),

                    // ===========================================
                    // RISK DOT
                    // ===========================================

                    Container(
                      width: 9,
                      height: 9,
                      decoration:
                      BoxDecoration(
                        shape:
                        BoxShape.circle,
                        color:
                        _riskColor(
                          ranking[index]
                              .riskLevel,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    // ===========================================
                    // STATE
                    // ===========================================

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            _shortStateName(
                              ranking[index]
                                  .state,
                            ),
                            style:
                            const TextStyle(
                              fontWeight:
                              FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(
                            height: 2,
                          ),

                          Text(
                            ranking[index]
                                .riskLevel,
                            style:
                            TextStyle(
                              fontSize: 9,
                              fontWeight:
                              FontWeight.w600,
                              color:
                              _riskColor(
                                ranking[index]
                                    .riskLevel,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ===========================================
                    // SCORE
                    // ===========================================

                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${ranking[index].riskScore}',
                          style:
                          TextStyle(
                            fontSize: 17,
                            fontWeight:
                            FontWeight.bold,
                            color:
                            _riskColor(
                              ranking[index]
                                  .riskLevel,
                            ),
                          ),
                        ),

                        const Text(
                          '/ 100',
                          style:
                          TextStyle(
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      width: 3,
                    ),

                    const Icon(
                      Icons
                          .chevron_right_rounded,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            if (index <
                ranking.length -
                    1)
              const Divider(
                height: 1,
              ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // SELECTED STATE OVERVIEW
  // ============================================================

  Widget _buildSelectedStateOverview(
      StateRiskData data,
      ) {
    final riskColor =
    _riskColor(
      data.riskLevel,
    );

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment
          .start,
      children: [
        // ======================================================
        // STATE HEADER
        // ======================================================

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    _shortStateName(
                      data.state,
                    ),
                    style:
                    const TextStyle(
                      fontSize: 22,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 3,
                  ),

                  const Text(
                    'Historical safety profile',
                    style:
                    TextStyle(
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration:
              BoxDecoration(
                color: riskColor
                    .withOpacity(
                  0.12,
                ),
                borderRadius:
                BorderRadius.circular(
                  20,
                ),
                border: Border.all(
                  color: riskColor
                      .withOpacity(
                    0.30,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize:
                MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                    BoxDecoration(
                      shape:
                      BoxShape.circle,
                      color:
                      riskColor,
                    ),
                  ),

                  const SizedBox(
                    width: 6,
                  ),

                  Text(
                    data.riskLevel,
                    style:
                    TextStyle(
                      fontSize: 10,
                      fontWeight:
                      FontWeight.bold,
                      color:
                      riskColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 15,
        ),

        // ======================================================
        // MAIN RISK CARD
        // ======================================================

        _buildRiskScoreCard(
          data,
          riskColor,
        ),

        const SizedBox(
          height: 12,
        ),

        // ======================================================
        // CRIME RATE + CASES
        // ======================================================

        Row(
          children: [
            Expanded(
              child:
              _statCard(
                icon: Icons
                    .speed_outlined,
                title:
                'Crime Rate',
                value:
                data.crimeRatePer100k
                    .toStringAsFixed(
                  1,
                ),
                subtitle:
                'per 100,000 people',
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child:
              _statCard(
                icon: Icons
                    .history_rounded,
                title:
                'Historical Cases',
                value:
                _formatNumber(
                  data.totalCases,
                ),
                subtitle:
                '${data.crimeYear} official data',
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 12,
        ),

        // ======================================================
        // ASSAULT + PROPERTY
        // ======================================================

        Row(
          children: [
            Expanded(
              child:
              _statCard(
                icon: Icons
                    .shield_outlined,
                title:
                'Violent Crime',
                value:
                _formatNumber(
                  data.assaultCases,
                ),
                subtitle:
                'Assault category',
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child:
              _statCard(
                icon: Icons
                    .home_work_outlined,
                title:
                'Property Crime',
                value:
                _formatNumber(
                  data.propertyCases,
                ),
                subtitle:
                'Property category',
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 12,
        ),

        // ======================================================
        // POPULATION
        // ======================================================

        _statCard(
          icon:
          Icons.people_outline,
          title:
          'Population Baseline',
          value:
          _formatPopulation(
            data.population2025,
          ),
          subtitle:
          'DOSM 2025 population estimate',
        ),

        // ======================================================
        // GROUPING INFORMATION
        // ======================================================

        if (data.groupedWith !=
            null) ...[
          const SizedBox(
            height: 14,
          ),

          _buildGroupingCard(
            data,
          ),
        ],

        const SizedBox(
          height: 28,
        ),

        // ======================================================
        // DISTRICT RANKING
        // ======================================================

        Row(
          children: [
            const Expanded(
              child: Text(
                'Police District Ranking',
                style:
                TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),

            Icon(
              Icons
                  .location_city_outlined,
              size: 20,
              color:
              Theme.of(context)
                  .colorScheme
                  .primary,
            ),
          ],
        ),

        const SizedBox(
          height: 5,
        ),

        Text(
          'Police districts within ${_shortStateName(data.state)} ranked by historical crime cases.',
          style:
          const TextStyle(
            fontSize: 10,
            height: 1.4,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        _buildDistrictRanking(),

        const SizedBox(
          height: 20,
        ),

        // ======================================================
        // SOURCE
        // ======================================================

        _buildStateSourceCard(),
      ],
    );
  }

  // ============================================================
  // RISK SCORE CARD
  // ============================================================

  Widget _buildRiskScoreCard(
      StateRiskData data,
      Color riskColor,
      ) {
    final scheme =
        Theme.of(context)
            .colorScheme;

    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(
        20,
      ),
      decoration:
      BoxDecoration(
        color:
        scheme.surfaceContainer,
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: riskColor
              .withOpacity(
            0.25,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,
        children: [
          // ====================================================
          // LABEL
          // ====================================================

          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                BoxDecoration(
                  color: riskColor
                      .withOpacity(
                    0.10,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
                child: Icon(
                  Icons
                      .analytics_outlined,
                  size: 21,
                  color:
                  riskColor,
                ),
              ),

              const SizedBox(
                width: 11,
              ),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Population-Adjusted Risk',
                      style:
                      TextStyle(
                        fontSize: 13,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    SizedBox(
                      height: 2,
                    ),

                    Text(
                      'Relative historical risk score',
                      style:
                      TextStyle(
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          // ====================================================
          // SCORE
          // ====================================================

          Row(
            crossAxisAlignment:
            CrossAxisAlignment.end,
            children: [
              Text(
                '${data.riskScore}',
                style:
                TextStyle(
                  fontSize: 42,
                  height: 1,
                  fontWeight:
                  FontWeight.bold,
                  color:
                  riskColor,
                ),
              ),

              const Padding(
                padding:
                EdgeInsets.only(
                  left: 4,
                  bottom: 4,
                ),
                child: Text(
                  '/ 100',
                  style:
                  TextStyle(
                    fontSize: 14,
                    fontWeight:
                    FontWeight.w500,
                  ),
                ),
              ),

              const Spacer(),

              Text(
                data.riskLevel,
                style:
                TextStyle(
                  fontSize: 12,
                  fontWeight:
                  FontWeight.bold,
                  color:
                  riskColor,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          // ====================================================
          // BAR
          // ====================================================

          ClipRRect(
            borderRadius:
            BorderRadius.circular(
              20,
            ),
            child:
            LinearProgressIndicator(
              value:
              data.riskScore /
                  100,
              minHeight:
              8,
              color:
              riskColor,
              backgroundColor:
              riskColor.withOpacity(
                0.12,
              ),
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            _riskDescription(
              data.riskLevel,
            ),
            style:
            const TextStyle(
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISTRICT RANKING
  // ============================================================

  Widget _buildDistrictRanking() {
    // ==========================================================
    // LOADING
    // ==========================================================

    if (_districtLoading) {
      return Container(
        width:
        double.infinity,
        padding:
        const EdgeInsets.symmetric(
          vertical: 35,
        ),
        decoration:
        _cardDecoration(),
        child:
        const Column(
          children: [
            SizedBox(
              width: 25,
              height: 25,
              child:
              CircularProgressIndicator(
                strokeWidth:
                2.5,
              ),
            ),

            SizedBox(
              height: 10,
            ),

            Text(
              'Loading police districts...',
              style:
              TextStyle(
                fontSize: 10,
              ),
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
        width:
        double.infinity,
        padding:
        const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 28,
        ),
        decoration:
        _cardDecoration(),
        child:
        const Column(
          children: [
            Icon(
              Icons
                  .location_off_outlined,
              size: 35,
            ),

            SizedBox(
              height: 9,
            ),

            Text(
              'No police district data available',
              textAlign:
              TextAlign.center,
              style:
              TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // ==========================================================
    // RANKING
    // ==========================================================

    final highestCases =
        _districts.first
            .totalCases;

    return Container(
      decoration:
      _cardDecoration(),
      child: Column(
        children: [
          for (
          int index = 0;
          index < _districts.length;
          index++
          ) ...[
            Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 13,
              ),
              child: Row(
                children: [
                  // =============================================
                  // NUMBER
                  // =============================================

                  Container(
                    width: 31,
                    height: 31,
                    alignment:
                    Alignment.center,
                    decoration:
                    BoxDecoration(
                      shape:
                      BoxShape.circle,
                      color:
                      _rankingBackground(
                        index,
                      ),
                    ),
                    child: Text(
                      '${index + 1}',
                      style:
                      TextStyle(
                        fontSize: 11,
                        fontWeight:
                        FontWeight.bold,
                        color:
                        _rankingForeground(
                          index,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  // =============================================
                  // DISTRICT + BAR
                  // =============================================

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          _districts[
                          index]
                              .district,
                          style:
                          const TextStyle(
                            fontSize: 12,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),

                        const SizedBox(
                          height: 7,
                        ),

                        ClipRRect(
                          borderRadius:
                          BorderRadius.circular(
                            20,
                          ),
                          child:
                          LinearProgressIndicator(
                            value: highestCases ==
                                0
                                ? 0
                                : _districts[
                            index]
                                .totalCases /
                                highestCases,
                            minHeight:
                            4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    width: 15,
                  ),

                  // =============================================
                  // CASES
                  // =============================================

                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .end,
                    children: [
                      Text(
                        _formatNumber(
                          _districts[
                          index]
                              .totalCases,
                        ),
                        style:
                        const TextStyle(
                          fontSize: 14,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 1,
                      ),

                      const Text(
                        'cases',
                        style:
                        TextStyle(
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (index <
                _districts.length -
                    1)
              const Divider(
                height: 1,
              ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // GROUPING INFORMATION
  // ============================================================

  Widget _buildGroupingCard(
      StateRiskData data,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        15,
      ),
      decoration:
      BoxDecoration(
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        color: Colors.blue
            .withOpacity(
          0.07,
        ),
        border: Border.all(
          color: Colors.blue
              .withOpacity(
            0.22,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 20,
            color:
            Colors.blue,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              data.isInherited
                  ? 'The official PDRM crime dataset groups ${_shortStateName(data.state)} with ${_shortStateName(data.groupedWith!)}. The historical risk therefore uses the grouped crime data.'
                  : '${_shortStateName(data.groupedWith!)} is included under ${_shortStateName(data.state)} in the official PDRM crime dataset.',
              style:
              const TextStyle(
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NATIONAL SOURCE
  // ============================================================

  Widget _buildNationalSourceCard() {
    return Container(
      padding:
      const EdgeInsets.all(
        15,
      ),
      decoration:
      _cardDecoration(),
      child:
      const Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons
                .account_balance_outlined,
            size: 20,
          ),

          SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              'Historical crime data is sourced from data.gov.my / PDRM. '
                  'Population adjustment uses the DOSM 2025 population baseline.',
              style:
              TextStyle(
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATE SOURCE
  // ============================================================

  Widget _buildStateSourceCard() {
    return Container(
      padding:
      const EdgeInsets.all(
        15,
      ),
      decoration:
      _cardDecoration(),
      child:
      const Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons
                .account_balance_outlined,
            size: 20,
          ),

          SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              'Crime source: data.gov.my / PDRM. '
                  'Population source: DOSM 2025. '
                  'Police district ranking is based on historical crime cases because PDRM police districts and DOSM administrative districts are not directly equivalent.',
              style:
              TextStyle(
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final scheme =
        Theme.of(context)
            .colorScheme;

    return Container(
      height: 112,
      padding:
      const EdgeInsets.all(
        15,
      ),
      decoration:
      _cardDecoration(),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color:
            scheme.primary,
          ),

          const Spacer(),

          Text(
            value,
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            style:
            const TextStyle(
              fontSize: 16,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 2,
          ),

          Text(
            title,
            style:
            const TextStyle(
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    final scheme =
        Theme.of(context)
            .colorScheme;

    return Container(
      padding:
      const EdgeInsets.all(
        16,
      ),
      decoration:
      _cardDecoration(),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration:
            BoxDecoration(
              borderRadius:
              BorderRadius.circular(
                11,
              ),
              color: scheme.primary
                  .withOpacity(
                0.08,
              ),
            ),
            child: Icon(
              icon,
              size: 19,
              color:
              scheme.primary,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Text(
            value,
            style:
            const TextStyle(
              fontSize: 20,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 3,
          ),

          Text(
            title,
            style:
            const TextStyle(
              fontSize: 11,
              fontWeight:
              FontWeight.w600,
            ),
          ),

          const SizedBox(
            height: 2,
          ),

          Text(
            subtitle,
            style:
            const TextStyle(
              fontSize: 8.5,
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
    final scheme =
        Theme.of(context)
            .colorScheme;

    return BoxDecoration(
      borderRadius:
      BorderRadius.circular(
        18,
      ),
      color:
      scheme.surfaceContainer,
      border: Border.all(
        color:
        scheme.outlineVariant,
      ),
    );
  }

  // ============================================================
  // RANK COLOUR
  // ============================================================

  Color _rankingBackground(
      int index,
      ) {
    if (index == 0) {
      return Colors.amber
          .withOpacity(
        0.18,
      );
    }

    if (index == 1) {
      return Colors.blueGrey
          .withOpacity(
        0.14,
      );
    }

    if (index == 2) {
      return Colors.brown
          .withOpacity(
        0.14,
      );
    }

    return Theme.of(context)
        .colorScheme
        .surfaceContainerHighest;
  }

  Color _rankingForeground(
      int index,
      ) {
    if (index == 0) {
      return Colors
          .amber.shade800;
    }

    if (index == 1) {
      return Colors
          .blueGrey.shade700;
    }

    if (index == 2) {
      return Colors
          .brown.shade600;
    }

    return Theme.of(context)
        .colorScheme
        .onSurface;
  }

  // ============================================================
  // RISK DESCRIPTION
  // ============================================================

  String _riskDescription(
      String level,
      ) {
    switch (level.toUpperCase()) {
      case 'VERY HIGH':
        return 'This area ranks among the higher historical crime-rate areas after adjusting for population.';

      case 'HIGH':
        return 'Historical crime data indicates a relatively elevated population-adjusted risk.';

      case 'MODERATE':
        return 'Historical crime data indicates a moderate population-adjusted risk.';

      case 'LOW':
      default:
        return 'Historical crime data indicates a comparatively lower population-adjusted risk.';
    }
  }

  // ============================================================
  // SHORT STATE NAME
  // ============================================================

  String _shortStateName(
      String state,
      ) {
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

  String _formatPopulation(
      int value,
      ) {
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

  String _formatNumber(
      int value,
      ) {
    return value
        .toString()
        .replaceAllMapped(
      RegExp(
        r'\B(?=(\d{3})+(?!\d))',
      ),
          (
          match,
          ) =>
      ',',
    );
  }
}

// ============================================================
// LEGEND
// ============================================================

class _LegendItem extends StatelessWidget {
  final Color color;

  final String text;

  const _LegendItem({
    required this.color,
    required this.text,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      mainAxisSize:
      MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration:
          BoxDecoration(
            shape:
            BoxShape.circle,
            color:
            color,
          ),
        ),

        const SizedBox(
          width: 5,
        ),

        Text(
          text,
          style:
          const TextStyle(
            fontSize: 9,
            fontWeight:
            FontWeight.w500,
          ),
        ),
      ],
    );
  }
}