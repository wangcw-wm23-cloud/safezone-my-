class IncidentHelper {
  final String id;

  final String incidentId;

  final String responderId;

  final String responderName;

  final String status;

  final double? latitude;

  final double? longitude;

  final double? accuracy;

  final DateTime? acceptedAt;

  final DateTime? lastLocationAt;

  const IncidentHelper({
    required this.id,
    required this.incidentId,
    required this.responderId,
    required this.responderName,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.acceptedAt,
    required this.lastLocationAt,
  });

  bool get hasLocation {
    return latitude != null &&
        longitude != null;
  }

  factory IncidentHelper.fromMap(
      Map<String, dynamic> map,
      ) {
    return IncidentHelper(
      id:
      map['id'].toString(),

      incidentId:
      map['incident_id'].toString(),

      responderId:
      map['responder_id'].toString(),

      responderName:
      map['responder_name']
          ?.toString() ??
          'SafeZone Helper',

      status:
      map['status']
          ?.toString() ??
          'accepted',

      latitude:
      (map['latitude'] as num?)
          ?.toDouble(),

      longitude:
      (map['longitude'] as num?)
          ?.toDouble(),

      accuracy:
      (map['location_accuracy'] as num?)
          ?.toDouble(),

      acceptedAt:
      DateTime.tryParse(
        map['accepted_at']
            ?.toString() ??
            '',
      ),

      lastLocationAt:
      DateTime.tryParse(
        map['last_location_at']
            ?.toString() ??
            '',
      ),
    );
  }
}

class IncidentMessage {
  final String id;

  final String incidentId;

  final String senderId;

  final String senderName;

  final String message;

  final String messageType;

  final DateTime createdAt;

  const IncidentMessage({
    required this.id,
    required this.incidentId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.messageType,
    required this.createdAt,
  });

  factory IncidentMessage.fromMap(
      Map<String, dynamic> map,
      ) {
    return IncidentMessage(
      id:
      map['id'].toString(),

      incidentId:
      map['incident_id'].toString(),

      senderId:
      map['sender_id'].toString(),

      senderName:
      map['sender_name']
          ?.toString() ??
          'SafeZone User',

      message:
      map['message']
          ?.toString() ??
          '',

      messageType:
      map['message_type']
          ?.toString() ??
          'text',

      createdAt:
      DateTime.parse(
        map['created_at'].toString(),
      ),
    );
  }
}

class NearbySosIncident {
  final String id;

  final String userId;

  final String category;

  final double latitude;

  final double longitude;

  final String? address;

  final String status;

  final DateTime createdAt;

  final double distanceMetres;

  const NearbySosIncident({
    required this.id,
    required this.userId,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.status,
    required this.createdAt,
    required this.distanceMetres,
  });

  factory NearbySosIncident.fromMap(
      Map<String, dynamic> map,
      ) {
    return NearbySosIncident(
      id:
      map['id'].toString(),

      userId:
      map['user_id'].toString(),

      category:
      map['category']
          ?.toString() ??
          'unsure',

      latitude:
      (map['latitude'] as num)
          .toDouble(),

      longitude:
      (map['longitude'] as num)
          .toDouble(),

      address:
      map['address']
          ?.toString(),

      status:
      map['status']
          ?.toString() ??
          'active',

      createdAt:
      DateTime.parse(
        map['created_at'].toString(),
      ),

      distanceMetres:
      (map['distance_m'] as num?)
          ?.toDouble() ??
          0,
    );
  }
}