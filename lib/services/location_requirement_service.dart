import 'package:geolocator/geolocator.dart';

enum LocationRequirementStatus {
  checking,
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

class LocationRequirementService {
  LocationRequirementService._();

  static final LocationRequirementService instance =
  LocationRequirementService._();

  Future<LocationRequirementStatus> check({
    bool requestPermission = false,
  }) async {
    try {
      final serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return LocationRequirementStatus.serviceDisabled;
      }

      var permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied &&
          requestPermission) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.deniedForever) {
        return LocationRequirementStatus
            .permissionDeniedForever;
      }

      if (permission ==
          LocationPermission.denied) {
        return LocationRequirementStatus
            .permissionDenied;
      }

      if (permission ==
          LocationPermission.whileInUse ||
          permission ==
              LocationPermission.always) {
        return LocationRequirementStatus.ready;
      }

      return LocationRequirementStatus
          .permissionDenied;
    } catch (_) {
      return LocationRequirementStatus.error;
    }
  }

  Stream<ServiceStatus> get serviceStatusStream =>
      Geolocator.getServiceStatusStream();

  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}