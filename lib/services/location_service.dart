import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

// ============================================================
// LOCATION RESULT
// ============================================================

class SafeZoneLocationResult {
  final double latitude;
  final double longitude;

  final double? accuracy;

  // ==========================================================
  // HUMAN READABLE LOCATION
  // ==========================================================

  final String locationName;

  final String district;

  // ==========================================================
  // NORMALIZED STATE NAME
  //
  // This is designed to match StateRiskService:
  //
  // Selangor
  // Johor
  // W.P. Kuala Lumpur
  // W.P. Putrajaya
  // W.P. Labuan
  // etc.
  // ==========================================================

  final String? state;

  final String? rawState;

  final String? locality;

  final String? subAdministrativeArea;

  final String? postalCode;

  const SafeZoneLocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.locationName,
    required this.district,
    required this.state,
    required this.rawState,
    required this.locality,
    required this.subAdministrativeArea,
    required this.postalCode,
  });
}

// ============================================================
// LOCATION EXCEPTIONS
// ============================================================

enum SafeZoneLocationErrorType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unableToGetLocation,
  unableToDetermineArea,
}

// ============================================================
// LOCATION EXCEPTION
// ============================================================

class SafeZoneLocationException implements Exception {
  final SafeZoneLocationErrorType type;

  final String message;

  const SafeZoneLocationException({
    required this.type,
    required this.message,
  });

  @override
  String toString() {
    return message;
  }
}

// ============================================================
// LOCATION SERVICE
// ============================================================

class LocationService {
  LocationService._();

  static final LocationService instance =
  LocationService._();

  final Geocoding _geocoding = Geocoding();

  // ============================================================
  // GET CURRENT LOCATION
  //
  // Full flow:
  //
  // 1. Check GPS
  // 2. Check permission
  // 3. Ask permission if needed
  // 4. Get coordinates
  // 5. Reverse geocode
  // 6. Normalize Malaysian state
  // ============================================================

  Future<SafeZoneLocationResult>
  getCurrentLocation() async {
    // ==========================================================
    // STEP 1:
    // CHECK LOCATION SERVICE
    // ==========================================================

    final serviceEnabled =
    await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const SafeZoneLocationException(
        type:
        SafeZoneLocationErrorType.serviceDisabled,
        message:
        'Location services are turned off. Please enable GPS to continue.',
      );
    }

    // ==========================================================
    // STEP 2:
    // CHECK PERMISSION
    // ==========================================================

    LocationPermission permission =
    await Geolocator.checkPermission();

    // ==========================================================
    // STEP 3:
    // REQUEST PERMISSION
    // ==========================================================

    if (permission ==
        LocationPermission.denied) {
      permission =
      await Geolocator.requestPermission();
    }

    // ==========================================================
    // STILL DENIED
    // ==========================================================

    if (permission ==
        LocationPermission.denied) {
      throw const SafeZoneLocationException(
        type:
        SafeZoneLocationErrorType.permissionDenied,
        message:
        'Location permission is required to detect your current safety area.',
      );
    }

    // ==========================================================
    // DENIED FOREVER
    // ==========================================================

    if (permission ==
        LocationPermission.deniedForever) {
      throw const SafeZoneLocationException(
        type:
        SafeZoneLocationErrorType
            .permissionDeniedForever,
        message:
        'Location permission has been permanently denied. Please enable it from the app settings.',
      );
    }

    // ==========================================================
    // STEP 4:
    // GET GPS POSITION
    // ==========================================================

    Position position;

    try {
      position =
      await Geolocator.getCurrentPosition(
        locationSettings:
        const LocationSettings(
          accuracy:
          LocationAccuracy.high,
          timeLimit:
          Duration(
            seconds: 15,
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'GET GPS POSITION ERROR: $e',
      );

      // ========================================================
      // TRY LAST KNOWN POSITION
      // ========================================================

      final lastPosition =
      await Geolocator.getLastKnownPosition();

      if (lastPosition == null) {
        throw const SafeZoneLocationException(
          type:
          SafeZoneLocationErrorType
              .unableToGetLocation,
          message:
          'Unable to determine your current GPS location. Please try again.',
        );
      }

      position =
          lastPosition;
    }

    debugPrint(
      '============================================',
    );

    debugPrint(
      'SAFEZONE GPS',
    );

    debugPrint(
      'Latitude: ${position.latitude}',
    );

    debugPrint(
      'Longitude: ${position.longitude}',
    );

    debugPrint(
      'Accuracy: ${position.accuracy} m',
    );

    debugPrint(
      '============================================',
    );

    // ==========================================================
    // STEP 5:
    // REVERSE GEOCODING
    // ==========================================================

    Placemark? placemark;

    try {
      final placemarks =
      await _geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        placemark =
            placemarks.first;
      }
    } catch (e) {
      debugPrint(
        'REVERSE GEOCODING ERROR: $e',
      );
    }

    // ==========================================================
    // IF GEOCODING FAILS
    //
    // GPS is still valid.
    // We return coordinates without pretending we know the state.
    // ==========================================================

    if (placemark == null) {
      return SafeZoneLocationResult(
        latitude:
        position.latitude,

        longitude:
        position.longitude,

        accuracy:
        position.accuracy,

        locationName:
        'Current Location',

        district:
        'Area name unavailable',

        state:
        null,

        rawState:
        null,

        locality:
        null,

        subAdministrativeArea:
        null,

        postalCode:
        null,
      );
    }

    // ==========================================================
    // RAW LOCATION FIELDS
    // ==========================================================

    final rawState =
    _clean(
      placemark.administrativeArea,
    );

    final locality =
    _clean(
      placemark.locality,
    );

    final subAdministrativeArea =
    _clean(
      placemark.subAdministrativeArea,
    );

    final subLocality =
    _clean(
      placemark.subLocality,
    );

    final street =
    _clean(
      placemark.street,
    );

    final name =
    _clean(
      placemark.name,
    );

    final postalCode =
    _clean(
      placemark.postalCode,
    );

    // ==========================================================
    // NORMALIZE STATE
    // ==========================================================

    final normalizedState =
    normalizeMalaysiaState(
      rawState ??
          locality ??
          subAdministrativeArea ??
          '',
    );

    // ==========================================================
    // LOCATION NAME
    //
    // Prefer:
    //
    // Sub-locality
    // Locality
    // District
    // Street
    // Current Location
    // ==========================================================

    final locationName =
    _firstUseful(
      [
        subLocality,
        locality,
        subAdministrativeArea,
        street,
        name,
      ],
      fallback:
      'Current Location',
    );

    // ==========================================================
    // DISTRICT
    //
    // Important:
    // This is a human-readable current area label.
    //
    // It is NOT automatically assumed to be the official
    // PDRM Police District used by crime_district.
    // ==========================================================

    final district =
    _firstUseful(
      [
        subAdministrativeArea,
        locality,
        subLocality,
      ],
      fallback:
      normalizedState ??
          'Area unavailable',
    );

    debugPrint(
      '============================================',
    );

    debugPrint(
      'SAFEZONE REVERSE GEOCODING',
    );

    debugPrint(
      'Location Name: $locationName',
    );

    debugPrint(
      'District: $district',
    );

    debugPrint(
      'Raw State: $rawState',
    );

    debugPrint(
      'Normalized State: $normalizedState',
    );

    debugPrint(
      'Locality: $locality',
    );

    debugPrint(
      'Sub Administrative Area: '
          '$subAdministrativeArea',
    );

    debugPrint(
      'Postal Code: $postalCode',
    );

    debugPrint(
      '============================================',
    );

    return SafeZoneLocationResult(
      latitude:
      position.latitude,

      longitude:
      position.longitude,

      accuracy:
      position.accuracy,

      locationName:
      locationName,

      district:
      district,

      state:
      normalizedState,

      rawState:
      rawState,

      locality:
      locality,

      subAdministrativeArea:
      subAdministrativeArea,

      postalCode:
      postalCode,
    );
  }

  // ============================================================
  // OPEN DEVICE LOCATION SETTINGS
  // ============================================================

  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  // ============================================================
  // OPEN APP SETTINGS
  // ============================================================

  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  // ============================================================
  // NORMALIZE MALAYSIAN STATE NAME
  //
  // IMPORTANT:
  //
  // Output must match StateRiskService keys.
  // ============================================================

  String? normalizeMalaysiaState(
      String value,
      ) {
    final clean =
    value
        .trim()
        .toLowerCase();

    if (clean.isEmpty) {
      return null;
    }

    // ==========================================================
    // JOHOR
    // ==========================================================

    if (clean.contains(
      'johor',
    )) {
      return 'Johor';
    }

    // ==========================================================
    // KEDAH
    // ==========================================================

    if (clean.contains(
      'kedah',
    )) {
      return 'Kedah';
    }

    // ==========================================================
    // KELANTAN
    // ==========================================================

    if (clean.contains(
      'kelantan',
    )) {
      return 'Kelantan';
    }

    // ==========================================================
    // MELAKA / MALACCA
    // ==========================================================

    if (clean.contains(
      'melaka',
    ) ||
        clean.contains(
          'malacca',
        )) {
      return 'Melaka';
    }

    // ==========================================================
    // NEGERI SEMBILAN
    // ==========================================================

    if (clean.contains(
      'negeri sembilan',
    ) ||
        clean.contains(
          'negri sembilan',
        )) {
      return 'Negeri Sembilan';
    }

    // ==========================================================
    // PAHANG
    // ==========================================================

    if (clean.contains(
      'pahang',
    )) {
      return 'Pahang';
    }

    // ==========================================================
    // PERAK
    // ==========================================================

    if (clean.contains(
      'perak',
    )) {
      return 'Perak';
    }

    // ==========================================================
    // PERLIS
    // ==========================================================

    if (clean.contains(
      'perlis',
    )) {
      return 'Perlis';
    }

    // ==========================================================
    // PENANG / PULAU PINANG
    // ==========================================================

    if (clean.contains(
      'pulau pinang',
    ) ||
        clean.contains(
          'penang',
        )) {
      return 'Pulau Pinang';
    }

    // ==========================================================
    // SABAH
    // ==========================================================

    if (clean.contains(
      'sabah',
    )) {
      return 'Sabah';
    }

    // ==========================================================
    // SARAWAK
    // ==========================================================

    if (clean.contains(
      'sarawak',
    )) {
      return 'Sarawak';
    }

    // ==========================================================
    // SELANGOR
    // ==========================================================

    if (clean.contains(
      'selangor',
    )) {
      return 'Selangor';
    }

    // ==========================================================
    // TERENGGANU
    // ==========================================================

    if (clean.contains(
      'terengganu',
    ) ||
        clean.contains(
          'trengganu',
        )) {
      return 'Terengganu';
    }

    // ==========================================================
    // PUTRAJAYA
    //
    // Check before Kuala Lumpur.
    // ==========================================================

    if (clean.contains(
      'putrajaya',
    )) {
      return 'W.P. Putrajaya';
    }

    // ==========================================================
    // LABUAN
    // ==========================================================

    if (clean.contains(
      'labuan',
    )) {
      return 'W.P. Labuan';
    }

    // ==========================================================
    // KUALA LUMPUR
    // ==========================================================

    if (clean.contains(
      'kuala lumpur',
    ) ||
        clean == 'kl') {
      return 'W.P. Kuala Lumpur';
    }

    return null;
  }

  // ============================================================
  // CLEAN STRING
  // ============================================================

  String? _clean(
      String? value,
      ) {
    if (value == null) {
      return null;
    }

    final clean =
    value.trim();

    if (clean.isEmpty) {
      return null;
    }

    return clean;
  }

  // ============================================================
  // FIRST USEFUL VALUE
  // ============================================================

  String _firstUseful(
      List<String?> values, {
        required String fallback,
      }) {
    for (final value
    in values) {
      if (value != null &&
          value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return fallback;
  }
}