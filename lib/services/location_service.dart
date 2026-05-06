import 'package:geolocator/geolocator.dart';

// Service to check if user is inside university using GPS
class LocationService {
  // University location (latitude & longitude)
  static const double universityLat = 21.5921992;
  static const double universityLng = 39.1453120;

  // Allowed radius in meters (student must be inside this range)
  static const double allowedRadius = 1000; // بالمتر

  // Check if user is inside university area
  static Future<bool> isInsideUniversity() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location service is ON
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    // Check location permission
    permission = await Geolocator.checkPermission();

    // If permission denied, ask user
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      // If still denied → stop
      if (permission == LocationPermission.denied) return false;
    }

    // If permanently denied → cannot use location
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    // Get current user location
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Calculate distance between user and university
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      universityLat,
      universityLng,
    );

    // Return true if inside allowed radius
    return distance <= allowedRadius;
  }
}
