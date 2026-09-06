part of 'home_screen.dart';



enum _NearbyAlertCategory { sos, accident, suspicious, medical, other }



class _NearbyAlert {
  final String id;

  final String title;

  final _NearbyAlertCategory category;

  final double latitude;

  final double longitude;

  final double distanceKm;

  final String timeAgo;

  final String? locationName;

  final NearbySosIncident incident;

  const _NearbyAlert({
    required this.id,
    required this.title,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.timeAgo,
    required this.locationName,
    required this.incident,
  });

  factory _NearbyAlert.fromIncident(NearbySosIncident incident) {
    return _NearbyAlert(
      id: incident.id,

      title: _titleFromCategory(incident.category),

      category: _categoryFromValue(incident.category),

      latitude: incident.latitude,

      longitude: incident.longitude,

      distanceKm: incident.distanceMetres / 1000,

      timeAgo: _formatTimeAgo(incident.createdAt),

      locationName: incident.address,

      incident: incident,
    );
  }

  static _NearbyAlertCategory _categoryFromValue(String value) {
    switch (value) {
      case 'medical':
        return _NearbyAlertCategory.medical;

      case 'accident':
        return _NearbyAlertCategory.accident;

      case 'crime':
        return _NearbyAlertCategory.suspicious;

      case 'fire_hazard':
      case 'other':
        return _NearbyAlertCategory.other;

      case 'unsure':
      default:
        return _NearbyAlertCategory.sos;
    }
  }

  static String _titleFromCategory(String value) {
    switch (value) {
      case 'medical':
        return 'Medical Emergency';

      case 'accident':
        return 'Accident';

      case 'crime':
        return 'Crime / Personal Threat';

      case 'fire_hazard':
        return 'Fire / Hazard';

      case 'other':
        return 'Other Emergency';

      case 'unsure':
      default:
        return 'SOS Emergency';
    }
  }

  static String _formatTimeAgo(DateTime value) {
    final difference = DateTime.now().difference(value.toLocal());

    if (difference.inSeconds < 60) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }

    return '${difference.inDays} day ago';
  }
}
