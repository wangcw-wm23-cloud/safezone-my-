import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// ============================================================
// STATE RISK MODEL
// ============================================================

class StateRiskData {
  final String state;

  // Population of this state / FT itself
  final int population2025;

  // Population denominator actually used for crime rate.
  // Example:
  // Kuala Lumpur + Putrajaya are grouped by the crime dataset.
  final int populationUsedForRate;

  final int assaultCases;
  final int propertyCases;

  final double crimeRatePer100k;

  final int riskScore;

  final String riskLevel;

  final int crimeYear;

  // Example:
  // Putrajaya -> W.P. Kuala Lumpur
  // Labuan -> Sabah
  final String? groupedWith;

  // True when this state does not have an independent
  // crime record and inherits the grouped score.
  final bool isInherited;

  final DateTime updatedAt;

  const StateRiskData({
    required this.state,
    required this.population2025,
    required this.populationUsedForRate,
    required this.assaultCases,
    required this.propertyCases,
    required this.crimeRatePer100k,
    required this.riskScore,
    required this.riskLevel,
    required this.crimeYear,
    required this.groupedWith,
    required this.isInherited,
    required this.updatedAt,
  });

  int get totalCases => assaultCases + propertyCases;

  Map<String, dynamic> toMap() {
    return {
      'state': state,
      'population_2025': population2025,
      'population_used_for_rate': populationUsedForRate,
      'assault_cases': assaultCases,
      'property_cases': propertyCases,
      'crime_rate': crimeRatePer100k,
      'risk_score': riskScore,
      'risk_level': riskLevel,
      'crime_year': crimeYear,
      'grouped_with': groupedWith,
      'is_inherited': isInherited ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StateRiskData.fromMap(Map<String, dynamic> map) {
    return StateRiskData(
      state: map['state'].toString(),
      population2025: (map['population_2025'] as num).toInt(),
      populationUsedForRate: (map['population_used_for_rate'] as num).toInt(),
      assaultCases: (map['assault_cases'] as num).toInt(),
      propertyCases: (map['property_cases'] as num).toInt(),
      crimeRatePer100k: (map['crime_rate'] as num).toDouble(),
      riskScore: (map['risk_score'] as num).toInt(),
      riskLevel: map['risk_level'].toString(),
      crimeYear: (map['crime_year'] as num).toInt(),
      groupedWith: map['grouped_with']?.toString(),
      isInherited: (map['is_inherited'] as num).toInt() == 1,
      updatedAt: DateTime.parse(map['updated_at'].toString()),
    );
  }
}

// ============================================================
// STATE RISK SERVICE
// ============================================================

class StateRiskService {
  StateRiskService._();

  static final StateRiskService instance = StateRiskService._();

  static const int crimeYear = 2023;

  // ============================================================
  // OFFICIAL DOSM 2025 POPULATION BASELINE
  //
  // Source:
  // Current Population Estimates, Malaysia, 2025
  //
  // Official dataset unit = '000
  // Values below already converted to actual people.
  // ============================================================

  static const Map<String, int> population2025 = {
    'Johor': 4205900,
    'Kedah': 2228000,
    'Kelantan': 1907700,
    'Melaka': 1052500,
    'Negeri Sembilan': 1244600,
    'Pahang': 1678200,
    'Perak': 2574900,
    'Perlis': 297800,
    'Pulau Pinang': 1803300,
    'Sabah': 3759600,
    'Sarawak': 2529800,
    'Selangor': 7406800,
    'Terengganu': 1246900,
    'W.P. Kuala Lumpur': 2074100,
    'W.P. Labuan': 100900,
    'W.P. Putrajaya': 120800,
  };

  Database? _database;

  // ============================================================
  // DATABASE
  // ============================================================

  Future<Database> _getDatabase() async {
    if (_database != null) {
      return _database!;
    }

    final databasePath = await getDatabasesPath();

    final path = p.join(databasePath, 'safezone_state_risk.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE state_risk_cache (
            state TEXT PRIMARY KEY,
            population_2025 INTEGER NOT NULL,
            population_used_for_rate INTEGER NOT NULL,
            assault_cases INTEGER NOT NULL,
            property_cases INTEGER NOT NULL,
            crime_rate REAL NOT NULL,
            risk_score INTEGER NOT NULL,
            risk_level TEXT NOT NULL,
            crime_year INTEGER NOT NULL,
            grouped_with TEXT,
            is_inherited INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL
          )
          ''');
      },
    );

    return _database!;
  }

  // ============================================================
  // PUBLIC LOAD
  // ============================================================

  Future<List<StateRiskData>> loadStateRisks({bool refresh = false}) async {
    if (!refresh) {
      final cached = await _readCache();

      if (cached.isNotEmpty) {
        return cached;
      }
    }

    try {
      final fresh = await _fetchAndCalculate();

      await _saveCache(fresh);

      return fresh;
    } catch (e) {
      final cached = await _readCache();

      if (cached.isNotEmpty) {
        return cached;
      }

      rethrow;
    }
  }

  // ============================================================
  // DATA.GOV.MY
  //
  // We request:
  // - 2023
  // - state totals
  // - type = all
  //
  // This returns assault + property totals.
  // ============================================================

  Future<List<StateRiskData>> _fetchAndCalculate() async {
    final uri = Uri.https('api.data.gov.my', '/data-catalogue', {
      'id': 'crime_district',
      'filter': '$crimeYear-01-01@date,All@district,all@type',
      'limit': '100',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to load crime data. '
        'HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw Exception('Unexpected data.gov.my response.');
    }

    // ==========================================================
    // state -> category -> cases
    // ==========================================================

    final Map<String, Map<String, int>> crimeByState = {};

    for (final raw in decoded) {
      if (raw is! Map) {
        continue;
      }

      final row = Map<String, dynamic>.from(raw);

      final state = row['state']?.toString();

      final category = row['category']?.toString();

      final crimesRaw = row['crimes'];

      if (state == null || category == null || crimesRaw == null) {
        continue;
      }

      if (state == 'Malaysia') {
        continue;
      }

      final crimes = crimesRaw is num
          ? crimesRaw.toInt()
          : int.tryParse(crimesRaw.toString()) ?? 0;

      crimeByState.putIfAbsent(state, () => {'assault': 0, 'property': 0});

      if (category == 'assault' || category == 'property') {
        crimeByState[state]![category] = crimes;
      }
    }

    // ==========================================================
    // DIRECT COMPARABLE STATE GROUPS
    //
    // Putrajaya is included in KL crime data.
    // Labuan is included in Sabah crime data.
    //
    // Therefore:
    //
    // KL crime rate denominator
    // = KL population + Putrajaya population
    //
    // Sabah crime rate denominator
    // = Sabah population + Labuan population
    // ==========================================================

    final directStates = population2025.keys.where((state) {
      return state != 'W.P. Putrajaya' && state != 'W.P. Labuan';
    }).toList();

    final List<_RawRisk> rawRisks = [];

    for (final state in directStates) {
      final categoryData = crimeByState[state];

      if (categoryData == null) {
        continue;
      }

      final assault = categoryData['assault'] ?? 0;

      final property = categoryData['property'] ?? 0;

      final total = assault + property;

      final populationForRate = _populationForCrimeGroup(state);

      if (populationForRate <= 0) {
        continue;
      }

      final rate = total / populationForRate * 100000;

      rawRisks.add(
        _RawRisk(
          state: state,
          populationForRate: populationForRate,
          assaultCases: assault,
          propertyCases: property,
          crimeRate: rate,
        ),
      );
    }

    if (rawRisks.isEmpty) {
      throw Exception('No state crime records returned.');
    }

    // ==========================================================
    // PERCENTILE NORMALISATION
    //
    // Lowest crime rate -> lower score
    // Highest crime rate -> higher score
    //
    // Score range will normally be around 0-100.
    // ==========================================================

    final sortedRates = rawRisks.map((item) => item.crimeRate).toList()..sort();

    final now = DateTime.now();

    final List<StateRiskData> results = [];

    for (final raw in rawRisks) {
      final score = _percentileScore(raw.crimeRate, sortedRates);

      results.add(
        StateRiskData(
          state: raw.state,
          population2025: population2025[raw.state]!,
          populationUsedForRate: raw.populationForRate,
          assaultCases: raw.assaultCases,
          propertyCases: raw.propertyCases,
          crimeRatePer100k: raw.crimeRate,
          riskScore: score,
          riskLevel: _riskLevel(score),
          crimeYear: crimeYear,
          groupedWith: _groupedWith(raw.state),
          isInherited: false,
          updatedAt: now,
        ),
      );
    }

    // ==========================================================
    // PUTRAJAYA
    //
    // Crime data is included under W.P. Kuala Lumpur.
    // It therefore inherits the KL grouped risk score.
    // ==========================================================

    final kl = results
        .where((item) => item.state == 'W.P. Kuala Lumpur')
        .firstOrNull;

    if (kl != null) {
      results.add(
        StateRiskData(
          state: 'W.P. Putrajaya',
          population2025: population2025['W.P. Putrajaya']!,
          populationUsedForRate: kl.populationUsedForRate,
          assaultCases: kl.assaultCases,
          propertyCases: kl.propertyCases,
          crimeRatePer100k: kl.crimeRatePer100k,
          riskScore: kl.riskScore,
          riskLevel: kl.riskLevel,
          crimeYear: crimeYear,
          groupedWith: 'W.P. Kuala Lumpur',
          isInherited: true,
          updatedAt: now,
        ),
      );
    }

    // ==========================================================
    // LABUAN
    //
    // Crime data is included under Sabah.
    // ==========================================================

    final sabah = results.where((item) => item.state == 'Sabah').firstOrNull;

    if (sabah != null) {
      results.add(
        StateRiskData(
          state: 'W.P. Labuan',
          population2025: population2025['W.P. Labuan']!,
          populationUsedForRate: sabah.populationUsedForRate,
          assaultCases: sabah.assaultCases,
          propertyCases: sabah.propertyCases,
          crimeRatePer100k: sabah.crimeRatePer100k,
          riskScore: sabah.riskScore,
          riskLevel: sabah.riskLevel,
          crimeYear: crimeYear,
          groupedWith: 'Sabah',
          isInherited: true,
          updatedAt: now,
        ),
      );
    }

    results.sort((a, b) => a.state.compareTo(b.state));

    return results;
  }

  // ============================================================
  // POPULATION USED FOR CRIME RATE
  // ============================================================

  int _populationForCrimeGroup(String state) {
    if (state == 'W.P. Kuala Lumpur') {
      return population2025['W.P. Kuala Lumpur']! +
          population2025['W.P. Putrajaya']!;
    }

    if (state == 'Sabah') {
      return population2025['Sabah']! + population2025['W.P. Labuan']!;
    }

    return population2025[state] ?? 0;
  }

  // ============================================================
  // GROUPING NOTE
  // ============================================================

  String? _groupedWith(String state) {
    if (state == 'W.P. Kuala Lumpur') {
      return 'W.P. Putrajaya';
    }

    if (state == 'Sabah') {
      return 'W.P. Labuan';
    }

    return null;
  }

  // ============================================================
  // RISK SCORE
  // ============================================================

  int _percentileScore(double rate, List<double> sortedRates) {
    if (sortedRates.isEmpty) {
      return 0;
    }

    final first = sortedRates.indexWhere((value) => value == rate);

    final last = sortedRates.lastIndexWhere((value) => value == rate);

    if (first == -1 || last == -1) {
      return 0;
    }

    final averageIndex = (first + last) / 2.0;

    final percentile = ((averageIndex + 0.5) / sortedRates.length) * 100;

    return percentile.round().clamp(0, 100);
  }

  String _riskLevel(int score) {
    if (score <= 29) {
      return 'LOW';
    }

    if (score <= 59) {
      return 'MODERATE';
    }

    if (score <= 79) {
      return 'HIGH';
    }

    return 'VERY HIGH';
  }

  // ============================================================
  // SAVE CACHE
  // ============================================================

  Future<void> _saveCache(List<StateRiskData> data) async {
    final db = await _getDatabase();

    final batch = db.batch();

    batch.delete('state_risk_cache');

    for (final item in data) {
      batch.insert(
        'state_risk_cache',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // ============================================================
  // READ CACHE
  // ============================================================

  Future<List<StateRiskData>> _readCache() async {
    final db = await _getDatabase();

    final rows = await db.query('state_risk_cache', orderBy: 'state ASC');

    return rows.map(StateRiskData.fromMap).toList();
  }
}

// ============================================================
// INTERNAL RAW MODEL
// ============================================================

class _RawRisk {
  final String state;

  final int populationForRate;

  final int assaultCases;

  final int propertyCases;

  final double crimeRate;

  const _RawRisk({
    required this.state,
    required this.populationForRate,
    required this.assaultCases,
    required this.propertyCases,
    required this.crimeRate,
  });
}

// ============================================================
// FIRST OR NULL
// ============================================================

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }

    return first;
  }
}
