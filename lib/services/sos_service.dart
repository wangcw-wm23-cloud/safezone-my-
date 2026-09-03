import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_binding_service.dart';
import 'local_database_service.dart';
import 'location_service.dart';

class SosIncident {
  final String id;
  final String userId;
  final String category;
  final double latitude;
  final double longitude;
  final String? address;
  final String status;
  final DateTime createdAt;

  const SosIncident({
    required this.id,
    required this.userId,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.status,
    required this.createdAt,
  });

  factory SosIncident.fromMap(
      Map<String, dynamic> map,
      ) {
    return SosIncident(
      id: map['id'].toString(),
      userId: map['user_id'].toString(),
      category: map['category']?.toString() ?? 'unsure',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      address: map['address']?.toString(),
      status: map['status']?.toString() ?? 'active',
      createdAt: DateTime.parse(
        map['created_at'].toString(),
      ),
    );
  }
}

class SosService {
  SosService._();

  static final SosService instance = SosService._();

  final SupabaseClient supabase = Supabase.instance.client;

  static const Set<String> _allowedCategories = {
    'medical',
    'crime',
    'accident',
    'fire_hazard',
    'other',
    'unsure',
  };

  Future<SosIncident> createSos({
    required String category,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in to use SOS.',
      );
    }

    if (!_allowedCategories.contains(category)) {
      throw Exception(
        'Please select a valid emergency category.',
      );
    }

    if (await getMyActiveSos() != null) {
      throw Exception(
        'You already have an active SOS.',
      );
    }

    await _checkSafetySetup();

    final location = await LocationService.instance
        .getCurrentLocation();

    final address = _buildAddress(location);

    final now = DateTime.now()
        .toUtc()
        .toIso8601String();

    try {
      final row = await supabase
          .from('sos_incidents')
          .insert({
        'user_id': user.id,
        'category': category,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'address': address,
        'status': 'active',
        'created_at': now,
        'updated_at': now,
      })
          .select()
          .single();

      final incident = SosIncident.fromMap(row);

      try {
        await _insertLocationUpdate(
          incidentId: incident.id,
          latitude: location.latitude,
          longitude: location.longitude,
          accuracy: location.accuracy,
          recordedAt: now,
        );
      } catch (e) {
        debugPrint(
          'INITIAL SOS LOCATION HISTORY ERROR: $e',
        );
      }

      try {
        await LocalDatabaseService.instance.insertActivity(
          userId: user.id,
          incidentId: incident.id,
          activityType: 'requested',
          status: 'active',
          title: _categoryName(category),
          location: address,
          latitude: location.latitude,
          longitude: location.longitude,
          synced: true,
        );
      } catch (e) {
        debugPrint(
          'LOCAL SOS HISTORY ERROR: $e',
        );
      }

      return incident;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception(
          'You already have an active SOS.',
        );
      }

      rethrow;
    }
  }

  Future<void> _checkSafetySetup() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'User session is unavailable.',
      );
    }

    final profile = await supabase
        .from('profiles')
        .select(
      'phone_number, phone_verified',
    )
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null) {
      throw Exception(
        'User profile could not be found.',
      );
    }

    final phone = profile['phone_number']
        ?.toString()
        .trim();

    if (phone == null || phone.isEmpty) {
      throw Exception(
        'Please add your phone number before using SOS.',
      );
    }

    if (profile['phone_verified'] != true) {
      throw Exception(
        'Please verify your phone number before using SOS.',
      );
    }

    final currentDeviceBound =
    await DeviceBindingService.instance
        .isCurrentDeviceBound();

    if (!currentDeviceBound) {
      throw Exception(
        'Please bind this device before using SOS.',
      );
    }
  }

  Future<SosIncident?> getMyActiveSos() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final row = await supabase
        .from('sos_incidents')
        .select()
        .eq('user_id', user.id)
        .inFilter(
      'status',
      [
        'active',
        'accepted',
      ],
    )
        .order(
      'created_at',
      ascending: false,
    )
        .limit(1)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return SosIncident.fromMap(row);
  }

  Future<SosIncident?> getIncident(
      String incidentId,
      ) async {
    final row = await supabase
        .from('sos_incidents')
        .select()
        .eq('id', incidentId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return SosIncident.fromMap(row);
  }

  Future<void> updateLiveLocation(
      String incidentId,
      ) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'User session unavailable.',
      );
    }

    final location = await LocationService.instance
        .getCurrentLocation();

    final now = DateTime.now()
        .toUtc()
        .toIso8601String();

    final updated = await supabase
        .from('sos_incidents')
        .update({
      'latitude': location.latitude,
      'longitude': location.longitude,
      'address': _buildAddress(location),
      'updated_at': now,
    })
        .eq('id', incidentId)
        .eq('user_id', user.id)
        .inFilter(
      'status',
      [
        'active',
        'accepted',
      ],
    )
        .select('id')
        .maybeSingle();

    if (updated == null) {
      throw Exception(
        'This SOS is no longer active.',
      );
    }

    try {
      await _insertLocationUpdate(
        incidentId: incidentId,
        latitude: location.latitude,
        longitude: location.longitude,
        accuracy: location.accuracy,
        recordedAt: now,
      );
    } catch (e) {
      debugPrint(
        'SOS LOCATION HISTORY ERROR: $e',
      );
    }
  }

  Future<void> cancelSos(
      String incidentId,
      ) async {
    await _closeIncident(
      incidentId: incidentId,
      resolved: false,
    );
  }

  Future<void> resolveSos(
      String incidentId,
      ) async {
    await _closeIncident(
      incidentId: incidentId,
      resolved: true,
    );
  }

  Future<void> _closeIncident({
    required String incidentId,
    required bool resolved,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'User session unavailable.',
      );
    }

    final status = resolved
        ? 'resolved'
        : 'cancelled';

    final now = DateTime.now()
        .toUtc()
        .toIso8601String();

    final values = <String, dynamic>{
      'status': status,
      'updated_at': now,
      if (resolved)
        'resolved_at': now
      else
        'cancelled_at': now,
    };

    final updated = await supabase
        .from('sos_incidents')
        .update(values)
        .eq('id', incidentId)
        .eq('user_id', user.id)
        .inFilter(
      'status',
      [
        'active',
        'accepted',
      ],
    )
        .select('id')
        .maybeSingle();

    if (updated == null) {
      throw Exception(
        'SOS could not be closed or is already closed.',
      );
    }

    try {
      final db = await LocalDatabaseService.instance.database;

      await db.update(
        'activity_history',
        {
          'status': status,
          'updated_at': now,
          'synced': 1,
        },
        where:
        'user_id = ? '
            'AND incident_id = ? '
            'AND activity_type = ?',
        whereArgs: [
          user.id,
          incidentId,
          'requested',
        ],
      );
    } catch (e) {
      debugPrint(
        'LOCAL SOS STATUS ERROR: $e',
      );
    }
  }

  Future<void> _insertLocationUpdate({
    required String incidentId,
    required double latitude,
    required double longitude,
    double? accuracy,
    required String recordedAt,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    await supabase.from('sos_location_updates').insert({
      'incident_id': incidentId,
      'user_id': user.id,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'recorded_at': recordedAt,
    });
  }

  String _buildAddress(
      SafeZoneLocationResult location,
      ) {
    final parts = <String>[];

    final values = <String?>[
      location.locationName,
      location.district,
      location.state,
    ];

    for (final value in values) {
      final cleaned = value?.trim() ?? '';

      if (cleaned.isNotEmpty &&
          !parts.contains(cleaned)) {
        parts.add(cleaned);
      }
    }

    return parts.join(', ');
  }

  String _categoryName(
      String value,
      ) {
    switch (value) {
      case 'medical':
        return 'Medical Emergency';

      case 'crime':
        return 'Crime / Personal Threat';

      case 'accident':
        return 'Accident';

      case 'fire_hazard':
        return 'Fire / Hazard';

      case 'other':
        return 'Other Emergency';

      default:
        return 'Not Sure / Need Help';
    }
  }
}