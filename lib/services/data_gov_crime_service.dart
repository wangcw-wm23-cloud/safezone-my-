import 'dart:convert';

import 'package:http/http.dart' as http;

class CrimeRecord {
  final DateTime date;
  final String state;
  final String district;
  final String category;
  final String type;
  final int crimes;

  const CrimeRecord({
    required this.date,
    required this.state,
    required this.district,
    required this.category,
    required this.type,
    required this.crimes,
  });

  int get year => date.year;

  factory CrimeRecord.fromJson(Map<String, dynamic> json) {
    return CrimeRecord(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime(2000),
      state: json['state']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      crimes: int.tryParse(json['crimes']?.toString() ?? '0') ?? 0,
    );
  }
}

class CrimeInsight {
  final String state;
  final String district;

  final int latestYear;
  final int latestTotal;
  final int previousTotal;

  final int violentTotal;
  final int propertyTotal;

  final Map<int, int> yearlyTotals;
  final Map<String, int> typeTotals;

  const CrimeInsight({
    required this.state,
    required this.district,
    required this.latestYear,
    required this.latestTotal,
    required this.previousTotal,
    required this.violentTotal,
    required this.propertyTotal,
    required this.yearlyTotals,
    required this.typeTotals,
  });

  double? get yearChangePercent {
    if (previousTotal == 0) {
      return null;
    }

    return ((latestTotal - previousTotal) / previousTotal) * 100;
  }

  String? get topCrimeType {
    if (typeTotals.isEmpty) {
      return null;
    }

    final sorted = typeTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  int get historicalTotal {
    return yearlyTotals.values.fold(0, (sum, value) => sum + value);
  }
}

class DataGovCrimeService {
  static const String _baseUrl = 'api.data.gov.my';

  static const String _datasetId = 'crime_district';

  static const List<String> states = [
    'Johor',
    'Kedah',
    'Kelantan',
    'Melaka',
    'Negeri Sembilan',
    'Pahang',
    'Perak',
    'Perlis',
    'Pulau Pinang',
    'Sabah',
    'Sarawak',
    'Selangor',
    'Terengganu',
    'W.P. Kuala Lumpur',
  ];

  Future<List<CrimeRecord>> getCrimeRecordsByState(String state) async {
    final uri = Uri.https(_baseUrl, '/data-catalogue', {
      'id': _datasetId,

      'ifilter': '$state@state',

      'limit': '1000',

      'sort': 'date',

      'include': 'date,state,district,category,type,crimes',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(
        'data.gov.my returned '
        '${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);

    List<dynamic> rows;

    if (decoded is List) {
      rows = decoded;
    }
    else if (decoded is Map<String, dynamic>) {
      final possibleData =
          decoded['data'] ?? decoded['results'] ?? decoded['records'];

      if (possibleData is List) {
        rows = possibleData;
      } else {
        rows = [];
      }
    } else {
      rows = [];
    }

    final records = rows
        .whereType<Map>()
        .map((row) => CrimeRecord.fromJson(Map<String, dynamic>.from(row)))
        .where((record) => record.state.toLowerCase() == state.toLowerCase())
        .toList();

    return records;
  }

  List<String> getDistricts(List<CrimeRecord> records) {
    final districts =
        records
            .map((record) => record.district.trim())
            .where((district) => district.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return districts;
  }

  CrimeInsight buildInsight({
    required List<CrimeRecord> records,
    required String state,
    String? district,
  }) {
    final filtered = district == null || district == 'All Districts'
        ? records
        : records.where((record) => record.district == district).toList();

    if (filtered.isEmpty) {
      return CrimeInsight(
        state: state,
        district: district ?? 'All Districts',
        latestYear: 0,
        latestTotal: 0,
        previousTotal: 0,
        violentTotal: 0,
        propertyTotal: 0,
        yearlyTotals: const {},
        typeTotals: const {},
      );
    }

    final years = filtered.map((record) => record.year).toSet().toList()
      ..sort();

    final latestYear = years.last;

    final previousYear = years.length >= 2
        ? years[years.length - 2]
        : latestYear;

    final yearlyTotals = <int, int>{};

    for (final record in filtered) {
      yearlyTotals.update(
        record.year,
        (value) => value + record.crimes,
        ifAbsent: () => record.crimes,
      );
    }

    final latestRecords = filtered
        .where((record) => record.year == latestYear)
        .toList();

    final previousRecords = filtered
        .where((record) => record.year == previousYear)
        .toList();

    final latestTotal = latestRecords.fold<int>(
      0,
      (sum, record) => sum + record.crimes,
    );

    final previousTotal = previousRecords.fold<int>(
      0,
      (sum, record) => sum + record.crimes,
    );

    final violentTotal = latestRecords
        .where((record) => record.category.toLowerCase() == 'assault')
        .fold<int>(0, (sum, record) => sum + record.crimes);

    final propertyTotal = latestRecords
        .where((record) => record.category.toLowerCase() == 'property')
        .fold<int>(0, (sum, record) => sum + record.crimes);

    final typeTotals = <String, int>{};

    for (final record in latestRecords) {
      typeTotals.update(
        record.type,
        (value) => value + record.crimes,
        ifAbsent: () => record.crimes,
      );
    }

    return CrimeInsight(
      state: state,
      district: district ?? 'All Districts',
      latestYear: latestYear,
      latestTotal: latestTotal,
      previousTotal: previousTotal,
      violentTotal: violentTotal,
      propertyTotal: propertyTotal,
      yearlyTotals: yearlyTotals,
      typeTotals: typeTotals,
    );
  }
}
