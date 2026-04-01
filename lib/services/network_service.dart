import 'package:network_info_plus/network_info_plus.dart';

class NetworkService {
  final NetworkInfo _info = NetworkInfo();

  Future<bool> isConnectedToUniversity() async {
    String? wifiName = await _info.getWifiName();

    if (wifiName != null && wifiName.contains("AOU")) {
      return true;
    }
    return false;
  }
}
