import 'package:flutter/material.dart';

import '../models/coordination_models.dart';
import '../services/sos_service.dart';
import 'incident_room_screen.dart';

class NearbySosDetailScreen
    extends StatelessWidget {
  final NearbySosIncident incident;

  const NearbySosDetailScreen({
    super.key,
    required this.incident,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return IncidentRoomScreen(
      initialIncident:
      SosIncident(
        id:
        incident.id,

        userId:
        incident.userId,

        category:
        incident.category,

        latitude:
        incident.latitude,

        longitude:
        incident.longitude,

        address:
        incident.address,

        status:
        incident.status,

        createdAt:
        incident.createdAt,
      ),

      isOwner:
      false,
    );
  }
}