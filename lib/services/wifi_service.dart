import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

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
        await Permission.nearbyWifiDevices.request();
      } catch (_) {}
    }
  }

  // Get current WiFi name (SSID)
  static Future<String?> getCurrentWifiName() async {
    // Only works on Android
    if (!Platform.isAndroid) return null;

    // Ask for permissions first
    await requestPermissions();

    // Check if device is connected to WiFi
    final connectivityResult = await _connectivity.checkConnectivity();

    if (!connectivityResult.contains(ConnectivityResult.wifi)) {
      return null;
    }

    // Get WiFi name
    String? ssid = await _networkInfo.getWifiName();

    if (ssid == null) return null;

    // Remove quotes and spaces
    ssid = ssid.replaceAll('"', '').trim();

    if (ssid.isEmpty) return null;

    return ssid;
  }

  // Check if user is connected to university WiFi
  static Future<bool> isOnUniversityWifi() async {
    final ssid = await getCurrentWifiName();

    return ssid == allowedWifiSsid;
  }
}
