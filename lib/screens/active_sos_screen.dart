import 'package:flutter/material.dart';

import '../services/sos_service.dart';
import 'incident_room_screen.dart';

class ActiveSosScreen extends StatelessWidget {
  final SosIncident incident;

  const ActiveSosScreen({
    super.key,
    required this.incident,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return IncidentRoomScreen(
      initialIncident:
      incident,

      isOwner:
      true,
    );
  }
}