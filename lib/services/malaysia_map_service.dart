import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';


class MalaysiaGeoPoint {
  final double longitude;
  final double latitude;

  const MalaysiaGeoPoint({
    required this.longitude,
    required this.latitude,
  });
}


class MalaysiaGeoRing {
  final List<MalaysiaGeoPoint> points;

  const MalaysiaGeoRing({
    required this.points,
  });
}


class MalaysiaGeoPolygon {
  final List<MalaysiaGeoRing> rings;

  const MalaysiaGeoPolygon({
    required this.rings,
  });
}



class MalaysiaGeoBounds {
  final double minLongitude;
  final double minLatitude;
  final double maxLongitude;
  final double maxLatitude;

  const MalaysiaGeoBounds({
    required this.minLongitude,
    required this.minLatitude,
    required this.maxLongitude,
    required this.maxLatitude,
  });

  double get longitudeSpan =>
      maxLongitude - minLongitude;

  double get latitudeSpan =>
      maxLatitude - minLatitude;

  double get centreLongitude =>
      (minLongitude + maxLongitude) / 2;

  double get centreLatitude =>
      (minLatitude + maxLatitude) / 2;
}


class MalaysiaStateBoundary {
  final String stateCode;


  final String sourceName;


  final String riskStateName;

  final List<MalaysiaGeoPolygon> polygons;

  final MalaysiaGeoBounds bounds;

  const MalaysiaStateBoundary({
    required this.stateCode,
    required this.sourceName,
    required this.riskStateName,
    required this.polygons,
    required this.bounds,
  });
}


class MalaysiaMapBoundary {
  final List<MalaysiaStateBoundary> states;

  final MalaysiaGeoBounds bounds;

  const MalaysiaMapBoundary({
    required this.states,
    required this.bounds,
  });
}


class MalaysiaMapService {
  MalaysiaMapService._();

  static final MalaysiaMapService instance =
  MalaysiaMapService._();


  static const String geoJsonUrl =
      'https://raw.githubusercontent.com/'
      'atifmustaffa/malaysia-geojson/'
      'refs/heads/master/'
      'malaysia.state.min.geojson';

  static const String _cacheKey =
      'malaysia_state_boundary_v1';

  Database? _database;

  MalaysiaMapBoundary? _memoryCache;


  static const Map<String, String>
  _stateCodeToRiskName = {
    'JHR': 'Johor',
    'KDH': 'Kedah',
    'KTN': 'Kelantan',
    'MLK': 'Melaka',
    'NSN': 'Negeri Sembilan',
    'PHG': 'Pahang',
    'PNG': 'Pulau Pinang',
    'PRK': 'Perak',
    'PLS': 'Perlis',
    'SBH': 'Sabah',
    'SWK': 'Sarawak',
    'SGR': 'Selangor',
    'TRG': 'Terengganu',

    'KUL': 'W.P. Kuala Lumpur',
    'LBN': 'W.P. Labuan',
    'PJY': 'W.P. Putrajaya',
  };


  Future<Database> _getDatabase() async {
    if (_database != null) {
      return _database!;
    }

    final databasePath =
    await getDatabasesPath();

    final path = p.join(
      databasePath,
      'safezone_map_cache.db',
    );

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (
          db,
          version,
          ) async {
        await db.execute(
          '''
          CREATE TABLE map_boundary_cache (
            cache_key TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
          ''',
        );
      },
    );

    return _database!;
  }

  Future<MalaysiaMapBoundary> load({
    bool refresh = false,
  }) async {
    if (!refresh &&
        _memoryCache != null) {
      return _memoryCache!;
    }

    String? cachedRaw;

    try {
      cachedRaw =
      await _readCachedGeoJson();
    } catch (e) {
    }


    if (!refresh &&
        cachedRaw != null &&
        cachedRaw.isNotEmpty) {
      try {
        final parsed =
        _parseGeoJson(
          cachedRaw,
        );

        _memoryCache =
            parsed;

        return parsed;
      } catch (e) {

      }
    }


    try {
      final response =
      await http
          .get(
        Uri.parse(
          geoJsonUrl,
        ),
      )
          .timeout(
        const Duration(
          seconds: 20,
        ),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Map cloud HTTP ${response.statusCode}',
        );
      }

      final raw =
          response.body;


      final parsed =
      _parseGeoJson(
        raw,
      );

      await _saveGeoJson(
        raw,
      );

      _memoryCache =
          parsed;

      return parsed;
    } catch (e) {


      if (cachedRaw != null &&
          cachedRaw.isNotEmpty) {
        final parsed =
        _parseGeoJson(
          cachedRaw,
        );

        _memoryCache =
            parsed;

        return parsed;
      }

      rethrow;
    }
  }


  Future<void> _saveGeoJson(
      String raw,
      ) async {
    final db =
    await _getDatabase();

    await db.insert(
      'map_boundary_cache',
      {
        'cache_key':
        _cacheKey,
        'payload':
        raw,
        'updated_at':
        DateTime.now()
            .toIso8601String(),
      },
      conflictAlgorithm:
      ConflictAlgorithm.replace,
    );
  }


  Future<String?> _readCachedGeoJson() async {
    final db =
    await _getDatabase();

    final result =
    await db.query(
      'map_boundary_cache',
      columns: [
        'payload',
      ],
      where:
      'cache_key = ?',
      whereArgs: [
        _cacheKey,
      ],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first[
    'payload']
        ?.toString();
  }


  MalaysiaMapBoundary _parseGeoJson(
      String raw,
      ) {
    final decoded =
    jsonDecode(
      raw,
    );

    if (decoded is! Map) {
      throw Exception(
        'Invalid Malaysia GeoJSON.',
      );
    }

    final root =
    Map<String, dynamic>.from(
      decoded,
    );

    final featureRaw =
    root['features'];

    if (featureRaw is! List) {
      throw Exception(
        'GeoJSON features missing.',
      );
    }

    final states =
    <MalaysiaStateBoundary>[];

    double malaysiaMinLon =
        double.infinity;

    double malaysiaMinLat =
        double.infinity;

    double malaysiaMaxLon =
    -double.infinity;

    double malaysiaMaxLat =
    -double.infinity;


    for (final rawFeature
    in featureRaw) {
      if (rawFeature is! Map) {
        continue;
      }

      final feature =
      Map<String, dynamic>.from(
        rawFeature,
      );

      final propertiesRaw =
      feature['properties'];

      final geometryRaw =
      feature['geometry'];

      if (propertiesRaw is! Map ||
          geometryRaw is! Map) {
        continue;
      }

      final properties =
      Map<String, dynamic>.from(
        propertiesRaw,
      );

      final geometry =
      Map<String, dynamic>.from(
        geometryRaw,
      );

      final stateCode =
      (properties['state_code'] ??
          feature['id'])
          ?.toString()
          .trim()
          .toUpperCase();

      if (stateCode == null ||
          stateCode.isEmpty) {
        continue;
      }

      final riskName =
      _stateCodeToRiskName[
      stateCode];

      if (riskName == null) {
        continue;
      }

      final sourceName =
      (properties['state_name'] ??
          properties['name'] ??
          riskName)
          .toString();

      final polygons =
      _parseGeometry(
        geometry,
      );

      if (polygons.isEmpty) {
        continue;
      }

      final bounds =
      _calculateBounds(
        polygons,
      );

      malaysiaMinLon =
      malaysiaMinLon <
          bounds.minLongitude
          ? malaysiaMinLon
          : bounds.minLongitude;

      malaysiaMinLat =
      malaysiaMinLat <
          bounds.minLatitude
          ? malaysiaMinLat
          : bounds.minLatitude;

      malaysiaMaxLon =
      malaysiaMaxLon >
          bounds.maxLongitude
          ? malaysiaMaxLon
          : bounds.maxLongitude;

      malaysiaMaxLat =
      malaysiaMaxLat >
          bounds.maxLatitude
          ? malaysiaMaxLat
          : bounds.maxLatitude;

      states.add(
        MalaysiaStateBoundary(
          stateCode:
          stateCode,
          sourceName:
          sourceName,
          riskStateName:
          riskName,
          polygons:
          polygons,
          bounds:
          bounds,
        ),
      );
    }

    if (states.isEmpty) {
      throw Exception(
        'No Malaysia state boundaries found.',
      );
    }

    return MalaysiaMapBoundary(
      states:
      states,
      bounds:
      MalaysiaGeoBounds(
        minLongitude:
        malaysiaMinLon,
        minLatitude:
        malaysiaMinLat,
        maxLongitude:
        malaysiaMaxLon,
        maxLatitude:
        malaysiaMaxLat,
      ),
    );
  }

  List<MalaysiaGeoPolygon> _parseGeometry(
      Map<String, dynamic> geometry,
      ) {
    final type =
    geometry['type']
        ?.toString();

    final coordinates =
    geometry['coordinates'];

    if (coordinates is! List) {
      return [];
    }

    if (type ==
        'Polygon') {
      final polygon =
      _parsePolygon(
        coordinates,
      );

      return polygon == null
          ? []
          : [
        polygon,
      ];
    }

    if (type ==
        'MultiPolygon') {
      final result =
      <MalaysiaGeoPolygon>[];

      for (final rawPolygon
      in coordinates) {
        if (rawPolygon is! List) {
          continue;
        }

        final polygon =
        _parsePolygon(
          rawPolygon,
        );

        if (polygon != null) {
          result.add(
            polygon,
          );
        }
      }

      return result;
    }

    return [];
  }

  MalaysiaGeoPolygon? _parsePolygon(
      List<dynamic> rawPolygon,
      ) {
    final rings =
    <MalaysiaGeoRing>[];

    for (final rawRing
    in rawPolygon) {
      if (rawRing is! List) {
        continue;
      }

      final points =
      <MalaysiaGeoPoint>[];

      for (final rawPoint
      in rawRing) {
        if (rawPoint is! List ||
            rawPoint.length <
                2) {
          continue;
        }

        final longitude =
        rawPoint[0];

        final latitude =
        rawPoint[1];

        if (longitude is! num ||
            latitude is! num) {
          continue;
        }

        points.add(
          MalaysiaGeoPoint(
            longitude:
            longitude.toDouble(),
            latitude:
            latitude.toDouble(),
          ),
        );
      }

      if (points.length >= 3) {
        rings.add(
          MalaysiaGeoRing(
            points:
            points,
          ),
        );
      }
    }

    if (rings.isEmpty) {
      return null;
    }

    return MalaysiaGeoPolygon(
      rings:
      rings,
    );
  }


  MalaysiaGeoBounds _calculateBounds(
      List<MalaysiaGeoPolygon> polygons,
      ) {
    double minLon =
        double.infinity;

    double minLat =
        double.infinity;

    double maxLon =
    -double.infinity;

    double maxLat =
    -double.infinity;

    for (final polygon
    in polygons) {
      for (final ring
      in polygon.rings) {
        for (final point
        in ring.points) {
          if (point.longitude <
              minLon) {
            minLon =
                point.longitude;
          }

          if (point.longitude >
              maxLon) {
            maxLon =
                point.longitude;
          }

          if (point.latitude <
              minLat) {
            minLat =
                point.latitude;
          }

          if (point.latitude >
              maxLat) {
            maxLat =
                point.latitude;
          }
        }
      }
    }

    return MalaysiaGeoBounds(
      minLongitude:
      minLon,
      minLatitude:
      minLat,
      maxLongitude:
      maxLon,
      maxLatitude:
      maxLat,
    );
  }
}