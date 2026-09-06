import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/coordination_models.dart';
import 'device_binding_service.dart';
import 'local_database_service.dart';
import 'location_service.dart';
import 'sos_service.dart';

class EmergencyCoordinationService {
  EmergencyCoordinationService._();

  static final EmergencyCoordinationService instance =
  EmergencyCoordinationService._();

  final SupabaseClient supabase =
      Supabase.instance.client;


  Stream<SosIncident?> streamIncident(
      String incidentId,
      ) {
    return supabase
        .from(
      'sos_incidents',
    )
        .stream(
      primaryKey: [
        'id',
      ],
    )
        .eq(
      'id',
      incidentId,
    )
        .map(
          (
          rows,
          ) {
        if (rows.isEmpty) {
          return null;
        }

        return SosIncident.fromMap(
          rows.first,
        );
      },
    );
  }


  Stream<List<IncidentHelper>> streamHelpers(
      String incidentId,
      ) {
    return supabase
        .from(
      'incident_responses',
    )
        .stream(
      primaryKey: [
        'id',
      ],
    )
        .eq(
      'incident_id',
      incidentId,
    )
        .order(
      'accepted_at',
    )
        .map(
          (
          rows,
          ) {
        return rows
            .map(
          IncidentHelper.fromMap,
        )
            .where(
              (
              helper,
              ) {
            return helper.status ==
                'accepted';
          },
        )
            .toList();
      },
    );
  }


  Stream<List<IncidentMessage>> streamMessages(
      String incidentId,
      ) {
    return supabase
        .from(
      'incident_messages',
    )
        .stream(
      primaryKey: [
        'id',
      ],
    )
        .eq(
      'incident_id',
      incidentId,
    )
        .order(
      'created_at',
    )
        .map(
          (
          rows,
          ) {
        return rows
            .map(
          IncidentMessage.fromMap,
        )
            .toList();
      },
    );
  }


  Future<List<NearbySosIncident>>
  getNearbyIncidents() async {
    final location =
    await LocationService.instance
        .getCurrentLocation();

    final response =
    await supabase.rpc(
      'get_nearby_sos',
      params: {
        'p_latitude':
        location.latitude,

        'p_longitude':
        location.longitude,

        'p_radius_m':
        1000.0,
      },
    );

    final rows =
    (response as List)
        .map(
          (
          row,
          ) {
        return Map<String, dynamic>.from(
          row as Map,
        );
      },
    )
        .toList();

    return rows
        .map(
      NearbySosIncident.fromMap,
    )
        .toList();
  }


  Future<IncidentHelper?> getMyResponse(
      String incidentId,
      ) async {
    final user =
        supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final row =
    await supabase
        .from(
      'incident_responses',
    )
        .select()
        .eq(
      'incident_id',
      incidentId,
    )
        .eq(
      'responder_id',
      user.id,
    )
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return IncidentHelper.fromMap(
      row,
    );
  }


  Future<IncidentHelper> joinIncident({
    required String incidentId,
    required String category,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final user =
        supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    final deviceBound =
    await DeviceBindingService.instance
        .isCurrentDeviceBound();

    if (!deviceBound) {
      throw Exception(
        'Please bind this device before helping.',
      );
    }

    final location =
    await LocationService.instance
        .getCurrentLocation();

    final response =
    await supabase.rpc(
      'join_incident',
      params: {
        'p_incident_id':
        incidentId,

        'p_latitude':
        location.latitude,

        'p_longitude':
        location.longitude,

        'p_accuracy':
        location.accuracy,
      },
    );

    final dynamic raw;

    if (response is List) {
      if (response.isEmpty) {
        throw Exception(
          'Unable to join this SOS.',
        );
      }

      raw =
          response.first;
    } else {
      raw =
          response;
    }

    final helper =
    IncidentHelper.fromMap(
      Map<String, dynamic>.from(
        raw as Map,
      ),
    );


    try {
      await LocalDatabaseService.instance
          .insertActivity(
        userId:
        user.id,

        incidentId:
        incidentId,

        activityType:
        'responded',

        status:
        'accepted',

        title:
        'Helped with ${_categoryName(category)}',

        location:
        address,

        latitude:
        latitude,

        longitude:
        longitude,

        synced:
        true,
      );
    } catch (_) {
    }

    return helper;
  }


  Future<void> updateHelperLocation(
      String incidentId,
      ) async {
    final location =
    await LocationService.instance
        .getCurrentLocation();

    await supabase.rpc(
      'update_helper_location',
      params: {
        'p_incident_id':
        incidentId,

        'p_latitude':
        location.latitude,

        'p_longitude':
        location.longitude,

        'p_accuracy':
        location.accuracy,
      },
    );
  }


  Future<void> leaveIncident(
      String incidentId,
      ) async {
    await supabase.rpc(
      'leave_incident',
      params: {
        'p_incident_id':
        incidentId,
      },
    );

    await updateLocalResponseStatus(
      incidentId,
      'cancelled',
    );
  }


  Future<void> updateLocalResponseStatus(
      String incidentId,
      String status,
      ) async {
    final user =
        supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final db =
      await LocalDatabaseService.instance
          .database;

      await db.update(
        'activity_history',
        {
          'status':
          status,

          'updated_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),

          'synced':
          1,
        },
        where:
        'user_id = ? '
            'AND incident_id = ? '
            'AND activity_type = ?',
        whereArgs: [
          user.id,
          incidentId,
          'responded',
        ],
      );
    } catch (_) {
    }
  }


  Future<void> sendMessage({
    required String incidentId,
    required String message,
  }) async {
    final user =
        supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    final cleaned =
    message.trim();

    if (cleaned.isEmpty) {
      return;
    }

    if (cleaned.length > 500) {
      throw Exception(
        'Message must be 500 characters or fewer.',
      );
    }

    await supabase
        .from(
      'incident_messages',
    )
        .insert(
      {
        'incident_id':
        incidentId,

        'sender_id':
        user.id,

        'message':
        cleaned,
      },
    );
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
        return 'SOS Emergency';
    }
  }
}