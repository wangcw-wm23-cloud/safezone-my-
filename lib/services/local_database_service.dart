import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabaseService {
  LocalDatabaseService._();

  static final LocalDatabaseService instance =
  LocalDatabaseService._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initializeDatabase();

    return _database!;
  }

  Future<Database> _initializeDatabase() async {
    final databasePath =
    await getDatabasesPath();

    final path = join(
      databasePath,
      'safezone_local.db',
    );

    return openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
      onConfigure: (db) async {
        await db.execute(
          'PRAGMA foreign_keys = ON',
        );
      },
    );
  }

  Future<void> _createDatabase(
      Database db,
      int version,
      ) async {
    await db.execute(
      '''
      CREATE TABLE IF NOT EXISTS activity_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        incident_id TEXT,
        activity_type TEXT NOT NULL
          CHECK (
            activity_type IN (
              'requested',
              'responded'
            )
          ),
        status TEXT NOT NULL,
        title TEXT,
        location TEXT,
        latitude REAL,
        longitude REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        synced INTEGER NOT NULL DEFAULT 0
          CHECK (
            synced IN (0, 1)
          )
      )
      ''',
    );

    await db.execute(
      '''
      CREATE TABLE IF NOT EXISTS cached_crime_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        state TEXT NOT NULL,
        district TEXT NOT NULL,
        year INTEGER NOT NULL,
        category TEXT NOT NULL,
        crime_type TEXT NOT NULL,
        crimes INTEGER NOT NULL DEFAULT 0,
        cached_at TEXT NOT NULL,
        UNIQUE (
          state,
          district,
          year,
          category,
          crime_type
        )
      )
      ''',
    );

    await db.execute(
      '''
      CREATE TABLE IF NOT EXISTS pending_sync (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        action TEXT NOT NULL,
        table_name TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
      ''',
    );

    await db.execute(
      '''
      CREATE INDEX IF NOT EXISTS idx_activity_user
      ON activity_history (user_id)
      ''',
    );

    await db.execute(
      '''
      CREATE INDEX IF NOT EXISTS idx_activity_incident
      ON activity_history (incident_id)
      ''',
    );

    await db.execute(
      '''
      CREATE INDEX IF NOT EXISTS idx_activity_created
      ON activity_history (created_at DESC)
      ''',
    );

    await db.execute(
      '''
      CREATE INDEX IF NOT EXISTS idx_crime_area
      ON cached_crime_data (
        state,
        district,
        year
      )
      ''',
    );

    await db.execute(
      '''
      CREATE INDEX IF NOT EXISTS idx_pending_user
      ON pending_sync (user_id)
      ''',
    );
  }

  Future<int> insertActivity({
    required String userId,
    String? incidentId,
    required String activityType,
    required String status,
    String? title,
    String? location,
    double? latitude,
    double? longitude,
    bool synced = false,
  }) async {
    final db = await database;

    final now = DateTime.now()
        .toUtc()
        .toIso8601String();

    if (incidentId != null &&
        incidentId.trim().isNotEmpty) {
      final existing = await db.query(
        'activity_history',
        columns: ['id'],
        where:
        'user_id = ? AND incident_id = ? AND activity_type = ?',
        whereArgs: [
          userId,
          incidentId,
          activityType,
        ],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final id =
        existing.first['id'] as int;

        await db.update(
          'activity_history',
          {
            'status': status,
            'title': title,
            'location': location,
            'latitude': latitude,
            'longitude': longitude,
            'updated_at': now,
            'synced': synced ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [id],
        );

        return id;
      }
    }

    return db.insert(
      'activity_history',
      {
        'user_id': userId,
        'incident_id': incidentId,
        'activity_type': activityType,
        'status': status,
        'title': title,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'created_at': now,
        'updated_at': now,
        'synced': synced ? 1 : 0,
      },
    );
  }

  Future<List<Map<String, dynamic>>>
  getActivities(
      String userId,
      ) async {
    final db = await database;

    return db.query(
      'activity_history',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> updateActivityStatus({
    required int id,
    required String status,
    bool? synced,
  }) async {
    final db = await database;

    final values =
    <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now()
          .toUtc()
          .toIso8601String(),
    };

    if (synced != null) {
      values['synced'] =
      synced ? 1 : 0;
    }

    await db.update(
      'activity_history',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateActivityByIncident({
    required String userId,
    required String incidentId,
    required String status,
    bool? synced,
  }) async {
    final db = await database;

    final values =
    <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now()
          .toUtc()
          .toIso8601String(),
    };

    if (synced != null) {
      values['synced'] =
      synced ? 1 : 0;
    }

    await db.update(
      'activity_history',
      values,
      where:
      'user_id = ? AND incident_id = ?',
      whereArgs: [
        userId,
        incidentId,
      ],
    );
  }

  Future<void> clearUserActivities(
      String userId,
      ) async {
    final db = await database;

    await db.delete(
      'activity_history',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> cacheCrimeRecord({
    required String state,
    required String district,
    required int year,
    required String category,
    required String crimeType,
    required int crimes,
  }) async {
    final db = await database;

    await db.insert(
      'cached_crime_data',
      {
        'state': state,
        'district': district,
        'year': year,
        'category': category,
        'crime_type': crimeType,
        'crimes': crimes,
        'cached_at': DateTime.now()
            .toUtc()
            .toIso8601String(),
      },
      conflictAlgorithm:
      ConflictAlgorithm.replace,
    );
  }

  Future<void> cacheCrimeRecords(
      List<Map<String, dynamic>> records,
      ) async {
    final db = await database;

    final batch = db.batch();

    final now = DateTime.now()
        .toUtc()
        .toIso8601String();

    for (final record in records) {
      batch.insert(
        'cached_crime_data',
        {
          'state': record['state'],
          'district': record['district'],
          'year': record['year'],
          'category': record['category'],
          'crime_type':
          record['crime_type'],
          'crimes': record['crimes'],
          'cached_at': now,
        },
        conflictAlgorithm:
        ConflictAlgorithm.replace,
      );
    }

    await batch.commit(
      noResult: true,
    );
  }

  Future<List<Map<String, dynamic>>>
  getCachedCrimeData({
    required String state,
    String? district,
  }) async {
    final db = await database;

    if (district == null ||
        district == 'All Districts') {
      return db.query(
        'cached_crime_data',
        where: 'state = ?',
        whereArgs: [state],
        orderBy: 'year ASC',
      );
    }

    return db.query(
      'cached_crime_data',
      where:
      'state = ? AND district = ?',
      whereArgs: [
        state,
        district,
      ],
      orderBy: 'year ASC',
    );
  }

  Future<void> clearCrimeCache() async {
    final db = await database;

    await db.delete(
      'cached_crime_data',
    );
  }

  Future<int> addPendingSync({
    required String userId,
    required String action,
    required String tableName,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;

    return db.insert(
      'pending_sync',
      {
        'user_id': userId,
        'action': action,
        'table_name': tableName,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now()
            .toUtc()
            .toIso8601String(),
        'retry_count': 0,
      },
    );
  }

  Future<List<Map<String, dynamic>>>
  getPendingSync(
      String userId,
      ) async {
    final db = await database;

    final rows = await db.query(
      'pending_sync',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );

    return rows.map(
          (row) {
        final result =
        Map<String, dynamic>.from(
          row,
        );

        try {
          result['payload_data'] =
              jsonDecode(
                row['payload'].toString(),
              );
        } catch (_) {
          result['payload_data'] = null;
        }

        return result;
      },
    ).toList();
  }

  Future<void> increaseRetryCount(
      int id,
      ) async {
    final db = await database;

    await db.rawUpdate(
      '''
      UPDATE pending_sync
      SET retry_count = retry_count + 1
      WHERE id = ?
      ''',
      [id],
    );
  }

  Future<void> removePendingSync(
      int id,
      ) async {
    final db = await database;

    await db.delete(
      'pending_sync',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearPendingSync(
      String userId,
      ) async {
    final db = await database;

    await db.delete(
      'pending_sync',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }


  Future<Map<String, int>>
  getDatabaseStats() async {
    final db = await database;

    final activity =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''
                SELECT COUNT(*)
                FROM activity_history
                ''',
          ),
        ) ??
            0;

    final crime =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''
                SELECT COUNT(*)
                FROM cached_crime_data
                ''',
          ),
        ) ??
            0;

    final pending =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''
                SELECT COUNT(*)
                FROM pending_sync
                ''',
          ),
        ) ??
            0;

    return {
      'activity_history': activity,
      'cached_crime_data': crime,
      'pending_sync': pending,
    };
  }

  Future<void> closeDatabase() async {
    final db = _database;

    if (db != null) {
      await db.close();

      _database = null;
    }
  }
}