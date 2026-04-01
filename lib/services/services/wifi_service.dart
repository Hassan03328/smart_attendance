import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class WifiService {
  static const String allowedWifiSsid = 'AOU-STUDENTS';

  static final NetworkInfo _networkInfo = NetworkInfo();
  static final Connectivity _connectivity = Connectivity();

  static Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.location.request();

      try {
        await Permission.nearbyWifiDevices.request();
      } catch (_) {}
    }
  }

  static Future<String?> getCurrentWifiName() async {
    if (!Platform.isAndroid) return null;

    await requestPermissions();

    final connectivityResult = await _connectivity.checkConnectivity();

    if (!connectivityResult.contains(ConnectivityResult.wifi)) {
      return null;
    }

    String? ssid = await _networkInfo.getWifiName();

    if (ssid == null) return null;

    ssid = ssid.replaceAll('"', '').trim();

    if (ssid.isEmpty) return null;

    return ssid;
  }

  static Future<bool> isOnUniversityWifi() async {
    final ssid = await getCurrentWifiName();
    return ssid == allowedWifiSsid;
  }
}
