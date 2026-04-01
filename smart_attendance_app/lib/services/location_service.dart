import 'package:geolocator/geolocator.dart';

class LocationService {
  static const double universityLat = 21.568517; 
  static const double universityLng = 39.221948;
  static const double allowedRadius = 200; // بالمتر

  static Future<bool> isInsideUniversity() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      universityLat,
      universityLng,
    );

    return distance <= allowedRadius;
  }
}
