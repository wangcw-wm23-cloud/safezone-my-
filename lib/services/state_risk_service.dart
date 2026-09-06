import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';


class StateRiskData {
  final String state;

  final int population2025;

  final int populationUsedForRate;

  final int assaultCases;
  final int propertyCases;

  final double crimeRatePer100k;

  final int riskScore;
  final String riskLevel;

  final int crimeYear;

  final String? groupedWith;
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

  int get totalCases =>
      assaultCases + propertyCases;

  Map<String, dynamic> toMap() {
    return {
      'state': state,
      'population_2025': population2025,
      'population_used_for_rate':
      populationUsedForRate,
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

  factory StateRiskData.fromMap(
      Map<String, dynamic> map,
      ) {
    return StateRiskData(
      state: map['state'].toString(),
      population2025:
      (map['population_2025'] as num).toInt(),
      populationUsedForRate:
      (map['population_used_for_rate'] as num)
          .toInt(),
      assaultCases:
      (map['assault_cases'] as num).toInt(),
      propertyCases:
      (map['property_cases'] as num).toInt(),
      crimeRatePer100k:
      (map['crime_rate'] as num).toDouble(),
      riskScore:
      (map['risk_score'] as num).toInt(),
      riskLevel:
      map['risk_level'].toString(),
      crimeYear:
      (map['crime_year'] as num).toInt(),
      groupedWith:
      map['grouped_with']?.toString(),
      isInherited:
      (map['is_inherited'] as num).toInt() == 1,
      updatedAt: DateTime.parse(
        map['updated_at'].toString(),
      ),
    );
  }
}

class PoliceDistrictData {
  final String district;

  final int assaultCases;
  final int propertyCases;

  const PoliceDistrictData({
    required this.district,
    required this.assaultCases,
    required this.propertyCases,
  });

  int get totalCases =>
      assaultCases + propertyCases;
}


class _CrimeRow {
  final String state;
  final String district;
  final String category;
  final int crimes;

  const _CrimeRow({
    required this.state,
    required this.district,
    required this.category,
    required this.crimes,
  });
}

class _RawStateRisk {
  final String state;

  final int assaultCases;
  final int propertyCases;

  final int population2023;

  final double crimeRate;

  const _RawStateRisk({
    required this.state,
    required this.assaultCases,
    required this.propertyCases,
    required this.population2023,
    required this.crimeRate,
  });

  int get totalCases =>
      assaultCases + propertyCases;
}


class StateRiskService {
  StateRiskService._();

  static final StateRiskService instance =
  StateRiskService._();


  static const int crimeYear = 2023;


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


  static const String _crimeCsvUrl =
      'https://storage.data.gov.my/'
      'publicsafety/crime_district.csv';

  static const String _populationCsvUrl =
      'https://storage.dosm.gov.my/'
      'population/population_state.csv';


  Database? _database;

  static const int _databaseVersion = 3;

  List<_CrimeRow>? _memoryCrimeRows;

  Map<String, int>? _memoryPopulation2023;


  Future<Database> _getDatabase() async {
    if (_database != null) {
      return _database!;
    }

    final databasePath =
    await getDatabasesPath();

    final path = p.join(
      databasePath,
      'safezone_state_risk.db',
    );

    _database = await openDatabase(
      path,
      version: _databaseVersion,

      onCreate: (
          db,
          version,
          ) async {
        await _createRiskTable(
          db,
        );
      },

      onUpgrade: (
          db,
          oldVersion,
          newVersion,
          ) async {
        if (oldVersion < 3) {
          await db.execute(
            '''
            DROP TABLE IF EXISTS state_risk_cache
            ''',
          );

          await _createRiskTable(
            db,
          );
        }
      },
    );

    return _database!;
  }


  Future<void> _createRiskTable(
      Database db,
      ) async {
    await db.execute(
      '''
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
      ''',
    );
  }


  Future<List<StateRiskData>> loadStateRisks({
    bool refresh = false,
  }) async {

    if (!refresh) {
      final cached =
      await _readStateCache();

      if (cached.isNotEmpty) {
        return cached;
      }
    }


    try {
      final fresh =
      await _calculateStateRisks(
        forceRefresh: refresh,
      );

      await _saveStateCache(
        fresh,
      );

      return fresh;
    } catch (e) {
      debugPrint(
        'STATE RISK ONLINE ERROR: $e',
      );

      final cached =
      await _readStateCache();

      if (cached.isNotEmpty) {
        return cached;
      }

      rethrow;
    }
  }


  Future<List<PoliceDistrictData>>
  loadPoliceDistrictRanking(
      String state, {
        bool refresh = false,
      }) async {
    final rows =
    await _fetchCrimeRows(
      forceRefresh: refresh,
    );


    String crimeState = state;

    if (state == 'W.P. Putrajaya') {
      crimeState =
      'W.P. Kuala Lumpur';
    }

    if (state == 'W.P. Labuan') {
      crimeState = 'Sabah';
    }

    final Map<String, Map<String, int>>
    grouped = {};

    for (final row in rows) {
      if (row.state != crimeState) {
        continue;
      }

      // Do not display the "All" state-total row.
      if (row.district.toLowerCase() ==
          'all') {
        continue;
      }

      grouped.putIfAbsent(
        row.district,
            () => {
          'assault': 0,
          'property': 0,
        },
      );

      if (row.category == 'assault') {
        grouped[row.district]!['assault'] =
            (grouped[row.district]!['assault'] ??
                0) +
                row.crimes;
      }

      if (row.category == 'property') {
        grouped[row.district]!['property'] =
            (grouped[row.district]!['property'] ??
                0) +
                row.crimes;
      }
    }

    final result =
    grouped.entries.map(
          (
          entry,
          ) {
        return PoliceDistrictData(
          district: entry.key,
          assaultCases:
          entry.value['assault'] ?? 0,
          propertyCases:
          entry.value['property'] ?? 0,
        );
      },
    ).toList();

    result.sort(
          (
          a,
          b,
          ) =>
          b.totalCases.compareTo(
            a.totalCases,
          ),
    );

    return result;
  }


  Future<List<StateRiskData>>
  _calculateStateRisks({
    required bool forceRefresh,
  }) async {

    final crimeRows =
    await _fetchCrimeRows(
      forceRefresh: forceRefresh,
    );


    final population2023 =
    await _fetchPopulation2023(
      forceRefresh: forceRefresh,
    );


    final Map<String, Map<String, int>>
    stateCrime = {};

    for (final row in crimeRows) {
      if (row.state.toLowerCase() ==
          'malaysia') {
        continue;
      }


      if (row.district.toLowerCase() ==
          'all') {
        continue;
      }

      stateCrime.putIfAbsent(
        row.state,
            () => {
          'assault': 0,
          'property': 0,
        },
      );

      if (row.category == 'assault') {
        stateCrime[row.state]!['assault'] =
            (stateCrime[row.state]!['assault'] ??
                0) +
                row.crimes;
      }

      if (row.category == 'property') {
        stateCrime[row.state]!['property'] =
            (stateCrime[row.state]!['property'] ??
                0) +
                row.crimes;
      }
    }

    final directStates =
    population2025.keys.where(
          (
          state,
          ) =>
      state != 'W.P. Putrajaya' &&
          state != 'W.P. Labuan',
    );

    final rawRisks =
    <_RawStateRisk>[];


    for (final state in directStates) {
      final crime =
      stateCrime[state];

      if (crime == null) {
        debugPrint(
          'NO CRIME DATA FOR: $state',
        );

        continue;
      }

      final assault =
          crime['assault'] ?? 0;

      final property =
          crime['property'] ?? 0;

      final totalCases =
          assault + property;

      final populationUsed =
      _populationForCrimeGroup2023(
        state,
        population2023,
      );

      if (populationUsed <= 0) {
        debugPrint(
          'NO POPULATION DATA FOR: $state',
        );

        continue;
      }


      final crimeRate =
          totalCases /
              populationUsed *
              100000;

      rawRisks.add(
        _RawStateRisk(
          state: state,
          assaultCases: assault,
          propertyCases: property,
          population2023:
          populationUsed,
          crimeRate: crimeRate,
        ),
      );
    }

    if (rawRisks.length < 10) {
      throw Exception(
        'Insufficient state data. '
            'Only ${rawRisks.length} comparable crime regions found.',
      );
    }

    int malaysiaCrimeCases = 0;
    int malaysiaPopulation = 0;

    for (final state in rawRisks) {
      malaysiaCrimeCases +=
          state.totalCases;

      malaysiaPopulation +=
          state.population2023;
    }

    if (malaysiaPopulation <= 0) {
      throw Exception(
        'Invalid Malaysia population.',
      );
    }

    final malaysiaCrimeRate =
        malaysiaCrimeCases /
            malaysiaPopulation *
            100000;

    if (malaysiaCrimeRate <= 0) {
      throw Exception(
        'Invalid Malaysia crime benchmark.',
      );
    }


    debugPrint(
      '============================================',
    );

    debugPrint(
      'MALAYSIA CRIME BENCHMARK',
    );

    debugPrint(
      'Crime Cases: $malaysiaCrimeCases',
    );

    debugPrint(
      'Population: $malaysiaPopulation',
    );

    debugPrint(
      'Crime Rate: '
          '${malaysiaCrimeRate.toStringAsFixed(2)} / 100k',
    );

    debugPrint(
      '============================================',
    );

    final now =
    DateTime.now();

    final results =
    <StateRiskData>[];


    for (final raw in rawRisks) {

      final riskRatio =
          raw.crimeRate /
              malaysiaCrimeRate;

      final score =
      _benchmarkRiskScore(
        riskRatio,
      );

      final level =
      _riskLevel(
        score,
      );

      debugPrint(
        '${raw.state}: '
            'Cases ${raw.totalCases} | '
            'Population ${raw.population2023} | '
            'Rate ${raw.crimeRate.toStringAsFixed(2)} | '
            'Ratio ${riskRatio.toStringAsFixed(2)} | '
            'Score $score | '
            '$level',
      );

      results.add(
        StateRiskData(
          state: raw.state,

          // 2025 is just for UI display
          population2025:
          population2025[raw.state]!,

          // 2023 used for formula
          populationUsedForRate:
          raw.population2023,

          assaultCases:
          raw.assaultCases,

          propertyCases:
          raw.propertyCases,

          crimeRatePer100k:
          raw.crimeRate,

          riskScore:
          score,

          riskLevel:
          level,

          crimeYear:
          crimeYear,

          groupedWith:
          _groupedWith(
            raw.state,
          ),

          isInherited:
          false,

          updatedAt:
          now,
        ),
      );
    }


    StateRiskData? kl;

    for (final item in results) {
      if (item.state ==
          'W.P. Kuala Lumpur') {
        kl = item;
        break;
      }
    }

    if (kl != null) {
      results.add(
        StateRiskData(
          state:
          'W.P. Putrajaya',

          population2025:
          population2025[
          'W.P. Putrajaya']!,

          populationUsedForRate:
          kl.populationUsedForRate,

          assaultCases:
          kl.assaultCases,

          propertyCases:
          kl.propertyCases,

          crimeRatePer100k:
          kl.crimeRatePer100k,

          riskScore:
          kl.riskScore,

          riskLevel:
          kl.riskLevel,

          crimeYear:
          crimeYear,

          groupedWith:
          'W.P. Kuala Lumpur',

          isInherited:
          true,

          updatedAt:
          now,
        ),
      );
    }

    StateRiskData? sabah;

    for (final item in results) {
      if (item.state == 'Sabah') {
        sabah = item;
        break;
      }
    }

    if (sabah != null) {
      results.add(
        StateRiskData(
          state:
          'W.P. Labuan',

          population2025:
          population2025[
          'W.P. Labuan']!,

          populationUsedForRate:
          sabah.populationUsedForRate,

          assaultCases:
          sabah.assaultCases,

          propertyCases:
          sabah.propertyCases,

          crimeRatePer100k:
          sabah.crimeRatePer100k,

          riskScore:
          sabah.riskScore,

          riskLevel:
          sabah.riskLevel,

          crimeYear:
          crimeYear,

          groupedWith:
          'Sabah',

          isInherited:
          true,

          updatedAt:
          now,
        ),
      );
    }


    results.sort(
          (
          a,
          b,
          ) =>
          a.state.compareTo(
            b.state,
          ),
    );

    return results;
  }


  int _benchmarkRiskScore(
      double riskRatio,
      ) {
    final rawScore =
        riskRatio * 50;

    return rawScore
        .round()
        .clamp(
      0,
      100,
    );
  }


  String _riskLevel(
      int score,
      ) {
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

  Future<List<_CrimeRow>>
  _fetchCrimeRows({
    required bool forceRefresh,
  }) async {

    if (!forceRefresh &&
        _memoryCrimeRows != null &&
        _memoryCrimeRows!.isNotEmpty) {
      return _memoryCrimeRows!;
    }


    final response =
    await http
        .get(
      Uri.parse(
        _crimeCsvUrl,
      ),
    )
        .timeout(
      const Duration(
        seconds: 30,
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Crime CSV HTTP '
            '${response.statusCode}',
      );
    }

    final csvText =
    utf8.decode(
      response.bodyBytes,
    );

    final lines =
    const LineSplitter().convert(
      csvText,
    );

    if (lines.length < 2) {
      throw Exception(
        'Crime CSV is empty.',
      );
    }


    final header =
    _splitCsvLine(
      lines.first,
    ).map(
          (
          value,
          ) =>
          value
              .replaceAll(
            '\ufeff',
            '',
          )
              .trim()
              .toLowerCase(),
    ).toList();

    final dateIndex =
    header.indexOf(
      'date',
    );

    final stateIndex =
    header.indexOf(
      'state',
    );

    final districtIndex =
    header.indexOf(
      'district',
    );

    final categoryIndex =
    header.indexOf(
      'category',
    );

    final typeIndex =
    header.indexOf(
      'type',
    );

    final crimesIndex =
    header.indexOf(
      'crimes',
    );

    if (dateIndex == -1 ||
        stateIndex == -1 ||
        districtIndex == -1 ||
        categoryIndex == -1 ||
        typeIndex == -1 ||
        crimesIndex == -1) {
      throw Exception(
        'Unexpected crime CSV columns.',
      );
    }


    final allTypeRows =
    <_CrimeRow>[];

    final detailTypeRows =
    <_CrimeRow>[];

    for (int i = 1;
    i < lines.length;
    i++) {
      final line =
      lines[i].trim();

      if (line.isEmpty) {
        continue;
      }

      final columns =
      _splitCsvLine(
        line,
      );

      final maxIndex = [
        dateIndex,
        stateIndex,
        districtIndex,
        categoryIndex,
        typeIndex,
        crimesIndex,
      ].reduce(
            (
            a,
            b,
            ) =>
        a > b ? a : b,
      );

      if (columns.length <= maxIndex) {
        continue;
      }

      final date =
      columns[dateIndex].trim();

      if (date != '2023-01-01') {
        continue;
      }

      final state =
      _normalizeStateName(
        columns[stateIndex],
      );

      final district =
      columns[districtIndex]
          .trim();

      final category =
      columns[categoryIndex]
          .trim()
          .toLowerCase();

      final type =
      columns[typeIndex]
          .trim()
          .toLowerCase();

      final crimes =
          int.tryParse(
            columns[crimesIndex]
                .trim(),
          ) ??
              0;

      if (state.isEmpty ||
          district.isEmpty) {
        continue;
      }

      if (category != 'assault' &&
          category != 'property') {
        continue;
      }

      final item =
      _CrimeRow(
        state: state,
        district: district,
        category: category,
        crimes: crimes,
      );

      if (type == 'all') {
        allTypeRows.add(
          item,
        );
      } else {
        detailTypeRows.add(
          item,
        );
      }
    }


    final result =
    allTypeRows.isNotEmpty
        ? allTypeRows
        : detailTypeRows;

    if (result.isEmpty) {
      throw Exception(
        'No usable 2023 crime rows returned.',
      );
    }

    debugPrint(
      '2023 CRIME ROWS LOADED: '
          '${result.length}',
    );

    _memoryCrimeRows =
        result;

    return result;
  }


  Future<Map<String, int>>
  _fetchPopulation2023({
    required bool forceRefresh,
  }) async {

    if (!forceRefresh &&
        _memoryPopulation2023 != null &&
        _memoryPopulation2023!.isNotEmpty) {
      return _memoryPopulation2023!;
    }


    final response =
    await http
        .get(
      Uri.parse(
        _populationCsvUrl,
      ),
    )
        .timeout(
      const Duration(
        seconds: 40,
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Population CSV HTTP '
            '${response.statusCode}',
      );
    }

    final csvText =
    utf8.decode(
      response.bodyBytes,
    );

    final lines =
    const LineSplitter().convert(
      csvText,
    );

    if (lines.length < 2) {
      throw Exception(
        'Population CSV is empty.',
      );
    }


    final header =
    _splitCsvLine(
      lines.first,
    ).map(
          (
          value,
          ) =>
          value
              .replaceAll(
            '\ufeff',
            '',
          )
              .trim()
              .toLowerCase(),
    ).toList();

    final dateIndex =
    header.indexOf(
      'date',
    );

    final stateIndex =
    header.indexOf(
      'state',
    );

    final sexIndex =
    header.indexOf(
      'sex',
    );

    final ageIndex =
    header.indexOf(
      'age',
    );

    final ethnicityIndex =
    header.indexOf(
      'ethnicity',
    );

    final populationIndex =
    header.indexOf(
      'population',
    );

    if (dateIndex == -1 ||
        stateIndex == -1 ||
        sexIndex == -1 ||
        ageIndex == -1 ||
        ethnicityIndex == -1 ||
        populationIndex == -1) {
      throw Exception(
        'Unexpected population CSV columns: '
            '$header',
      );
    }

    final result =
    <String, int>{};


    for (int i = 1;
    i < lines.length;
    i++) {
      final line =
      lines[i].trim();

      if (line.isEmpty) {
        continue;
      }

      final columns =
      _splitCsvLine(
        line,
      );

      final maxIndex = [
        dateIndex,
        stateIndex,
        sexIndex,
        ageIndex,
        ethnicityIndex,
        populationIndex,
      ].reduce(
            (
            a,
            b,
            ) =>
        a > b ? a : b,
      );

      if (columns.length <= maxIndex) {
        continue;
      }


      final date =
      columns[dateIndex]
          .trim();

      if (date != '2023-01-01') {
        continue;
      }


      final sex =
      columns[sexIndex]
          .trim()
          .toLowerCase();

      final age =
      columns[ageIndex]
          .trim()
          .toLowerCase();

      final ethnicity =
      columns[ethnicityIndex]
          .trim()
          .toLowerCase();

      if (sex != 'both' ||
          age != 'overall' ||
          ethnicity != 'overall') {
        continue;
      }


      final state =
      _normalizeStateName(
        columns[stateIndex],
      );

      if (state.isEmpty) {
        continue;
      }


      final populationThousands =
      double.tryParse(
        columns[populationIndex]
            .trim(),
      );

      if (populationThousands ==
          null ||
          populationThousands <= 0) {
        continue;
      }

      final people =
      (populationThousands *
          1000)
          .round();

      result[state] =
          people;
    }


    debugPrint(
      '============================================',
    );

    debugPrint(
      '2023 POPULATION DATA LOADED',
    );

    debugPrint(
      'States: ${result.length}',
    );

    for (final entry
    in result.entries) {
      debugPrint(
        '${entry.key}: ${entry.value}',
      );
    }

    debugPrint(
      '============================================',
    );


    if (result.length < 16) {
      throw Exception(
        'Incomplete 2023 state population data. '
            'Only ${result.length} states returned. '
            'States: ${result.keys.join(', ')}',
      );
    }

    _memoryPopulation2023 =
        result;

    return result;
  }


  int _populationForCrimeGroup2023(
      String state,
      Map<String, int> population2023,
      ) {

    if (state ==
        'W.P. Kuala Lumpur') {
      return (population2023[
      'W.P. Kuala Lumpur'] ??
          0) +
          (population2023[
          'W.P. Putrajaya'] ??
              0);
    }


    if (state == 'Sabah') {
      return (population2023[
      'Sabah'] ??
          0) +
          (population2023[
          'W.P. Labuan'] ??
              0);
    }

    return population2023[state] ?? 0;
  }


  String? _groupedWith(
      String state,
      ) {
    if (state ==
        'W.P. Kuala Lumpur') {
      return 'W.P. Putrajaya';
    }

    if (state == 'Sabah') {
      return 'W.P. Labuan';
    }

    return null;
  }


  String _normalizeStateName(
      String value,
      ) {
    final clean =
    value
        .replaceAll(
      '"',
      '',
    )
        .trim();

    final lower =
    clean.toLowerCase();

    switch (lower) {
      case 'penang':
        return 'Pulau Pinang';

      case 'pulau pinang':
        return 'Pulau Pinang';

      case 'malacca':
        return 'Melaka';

      case 'melaka':
        return 'Melaka';

      case 'kuala lumpur':
      case 'wp kuala lumpur':
      case 'w.p kuala lumpur':
      case 'w.p. kuala lumpur':
        return 'W.P. Kuala Lumpur';

      case 'putrajaya':
      case 'wp putrajaya':
      case 'w.p putrajaya':
      case 'w.p. putrajaya':
        return 'W.P. Putrajaya';

      case 'labuan':
      case 'wp labuan':
      case 'w.p labuan':
      case 'w.p. labuan':
        return 'W.P. Labuan';

      default:
        return clean;
    }
  }


  List<String> _splitCsvLine(
      String line,
      ) {
    final result =
    <String>[];

    final current =
    StringBuffer();

    bool insideQuotes =
    false;

    for (int i = 0;
    i < line.length;
    i++) {
      final char =
      line[i];

      if (char == '"') {
        if (insideQuotes &&
            i + 1 < line.length &&
            line[i + 1] == '"') {
          current.write(
            '"',
          );

          i++;

          continue;
        }

        insideQuotes =
        !insideQuotes;

        continue;
      }

      if (char == ',' &&
          !insideQuotes) {
        result.add(
          current
              .toString()
              .trim(),
        );

        current.clear();

        continue;
      }

      current.write(
        char,
      );
    }

    result.add(
      current
          .toString()
          .trim(),
    );

    return result;
  }


  Future<void> _saveStateCache(
      List<StateRiskData> data,
      ) async {
    final db =
    await _getDatabase();

    final batch =
    db.batch();

    batch.delete(
      'state_risk_cache',
    );

    for (final item in data) {
      batch.insert(
        'state_risk_cache',
        item.toMap(),
        conflictAlgorithm:
        ConflictAlgorithm.replace,
      );
    }

    await batch.commit(
      noResult: true,
    );
  }


  Future<List<StateRiskData>>
  _readStateCache() async {
    final db =
    await _getDatabase();

    final rows =
    await db.query(
      'state_risk_cache',
      orderBy:
      'state ASC',
    );

    if (rows.isEmpty) {
      return [];
    }

    return rows.map(
          (
          row,
          ) {
        return StateRiskData.fromMap(
          row,
        );
      },
    ).toList();
  }
}