import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

<<<<<<< HEAD
// Service to check WiFi connection
class WifiService {
  // Allowed university WiFi name
  static const String allowedWifiSsid = 'AOU-STUDENTS';

  // Get network info (WiFi name)
  static final NetworkInfo _networkInfo = NetworkInfo();

  // Check connection type (WiFi / Mobile)
  static final Connectivity _connectivity = Connectivity();

  // Request required permissions (location + wifi)
  static Future<void> requestPermissions() async {
    // Only needed on Android
    if (Platform.isAndroid) {
      // Location permission required for WiFi name
      await Permission.location.request();

      try {
        // Android 13+ permission
=======
class WifiService {
  static const String allowedWifiSsid = 'AOU-STUDENTS';

  static final NetworkInfo _networkInfo = NetworkInfo();
  static final Connectivity _connectivity = Connectivity();

  static Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.location.request();

      try {
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
        await Permission.nearbyWifiDevices.request();
      } catch (_) {}
    }
  }

<<<<<<< HEAD
  // Get current WiFi name (SSID)
  static Future<String?> getCurrentWifiName() async {
    // Only works on Android
    if (!Platform.isAndroid) return null;

    // Ask for permissions first
    await requestPermissions();

    // Check if device is connected to WiFi
=======
  static Future<String?> getCurrentWifiName() async {
    if (!Platform.isAndroid) return null;

    await requestPermissions();

>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
    final connectivityResult = await _connectivity.checkConnectivity();

    if (!connectivityResult.contains(ConnectivityResult.wifi)) {
      return null;
    }

<<<<<<< HEAD
    // Get WiFi name
=======
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
    String? ssid = await _networkInfo.getWifiName();

    if (ssid == null) return null;

<<<<<<< HEAD
    // Remove quotes and spaces
=======
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
    ssid = ssid.replaceAll('"', '').trim();

    if (ssid.isEmpty) return null;

    return ssid;
  }

<<<<<<< HEAD
  // Check if user is connected to university WiFi
  static Future<bool> isOnUniversityWifi() async {
    final ssid = await getCurrentWifiName();

    return ssid == allowedWifiSsid;
  }
}
=======
  static Future<bool> isOnUniversityWifi() async {
    final ssid = await getCurrentWifiName();
    return ssid == allowedWifiSsid;
  }
}
>>>>>>> 6189e135f3de2c07d9cd20d1b0be1fa3c949a3f2
