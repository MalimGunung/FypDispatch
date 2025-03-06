import 'package:geolocator/geolocator.dart';

class LocationService {
  // Request location permissions
  static Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      print("❌ Location permissions are permanently denied.");
      return false;
    }

    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  // Get current location
  static Future<Position?> getCurrentLocation() async {
    bool hasPermission = await requestPermission();

    if (!hasPermission) {
      print("❌ Location permission not granted.");
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
  