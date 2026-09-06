import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';


class SafeZoneLocationResult {
  final double latitude;
  final double longitude;

  final double? accuracy;


  final String locationName;

  final String district;


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


enum SafeZoneLocationErrorType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unableToGetLocation,
  unableToDetermineArea,
}


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


class LocationService {
  LocationService._();

  static final LocationService instance =
  LocationService._();

  final Geocoding _geocoding = Geocoding();


  Future<SafeZoneLocationResult>
  getCurrentLocation() async {

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


    LocationPermission permission =
    await Geolocator.checkPermission();


    if (permission ==
        LocationPermission.denied) {
      permission =
      await Geolocator.requestPermission();
    }


    if (permission ==
        LocationPermission.denied) {
      throw const SafeZoneLocationException(
        type:
        SafeZoneLocationErrorType.permissionDenied,
        message:
        'Location permission is required to detect your current safety area.',
      );
    }


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


    final normalizedState =
    normalizeMalaysiaState(
      rawState ??
          locality ??
          subAdministrativeArea ??
          '',
    );


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


  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }


  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }


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


    if (clean.contains(
      'johor',
    )) {
      return 'Johor';
    }


    if (clean.contains(
      'kedah',
    )) {
      return 'Kedah';
    }


    if (clean.contains(
      'kelantan',
    )) {
      return 'Kelantan';
    }


    if (clean.contains(
      'melaka',
    ) ||
        clean.contains(
          'malacca',
        )) {
      return 'Melaka';
    }


    if (clean.contains(
      'negeri sembilan',
    ) ||
        clean.contains(
          'negri sembilan',
        )) {
      return 'Negeri Sembilan';
    }


    if (clean.contains(
      'pahang',
    )) {
      return 'Pahang';
    }


    if (clean.contains(
      'perak',
    )) {
      return 'Perak';
    }


    if (clean.contains(
      'perlis',
    )) {
      return 'Perlis';
    }


    if (clean.contains(
      'pulau pinang',
    ) ||
        clean.contains(
          'penang',
        )) {
      return 'Pulau Pinang';
    }


    if (clean.contains(
      'sabah',
    )) {
      return 'Sabah';
    }


    if (clean.contains(
      'sarawak',
    )) {
      return 'Sarawak';
    }


    if (clean.contains(
      'selangor',
    )) {
      return 'Selangor';
    }


    if (clean.contains(
      'terengganu',
    ) ||
        clean.contains(
          'trengganu',
        )) {
      return 'Terengganu';
    }


    if (clean.contains(
      'putrajaya',
    )) {
      return 'W.P. Putrajaya';
    }


    if (clean.contains(
      'labuan',
    )) {
      return 'W.P. Labuan';
    }


    if (clean.contains(
      'kuala lumpur',
    ) ||
        clean == 'kl') {
      return 'W.P. Kuala Lumpur';
    }

    return null;
  }


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