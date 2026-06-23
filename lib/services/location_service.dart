import 'package:geolocator/geolocator.dart';

class LocationResult {
  final Position? position;
  final String? error;

  const LocationResult._({this.position, this.error});

  factory LocationResult.success(Position position) =>
      LocationResult._(position: position);

  factory LocationResult.error(String error) => LocationResult._(error: error);

  bool get isSuccess => position != null;
}

class LocationService {
  /// Requests location permission and returns the user's current GPS position.
  static Future<LocationResult> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationResult.error(
          'Location services are disabled on your device.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationResult.error(
            'Location permission denied. Please allow access to continue.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationResult.error(
          'Location permissions are permanently denied. '
          'Please enable them in your browser settings.');
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationResult.success(position);
    } catch (e) {
      return LocationResult.error(
          'Could not get your location. Please try again.');
    }
  }

  /// Calculates the distance in meters between two GPS coordinates.
  static double distanceBetween({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    return Geolocator.distanceBetween(fromLat, fromLng, toLat, toLng);
  }
}
