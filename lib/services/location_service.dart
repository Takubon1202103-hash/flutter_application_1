import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<String?> getCurrentLocationName() async {
    try {
      // 権限確認
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return null;
        }
      }

      // 位置情報取得（精度低め＝速い）
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );

      // 座標 → 住所
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) return null;

      final p = placemarks.first;
      // 区・市区町村を優先、なければ都市名
      final name = p.subLocality?.isNotEmpty == true
          ? p.subLocality
          : p.locality?.isNotEmpty == true
              ? p.locality
              : p.administrativeArea;

      return name;
    } catch (_) {
      return null;
    }
  }
}
