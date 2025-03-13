import 'package:geolocator/geolocator.dart';
import 'package:collection/collection.dart';// ✅ Import built-in PriorityQueue

class LocationService {
  // ✅ Request location permissions at runtime
  static Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("❌ Location services are disabled.");
      return false;
    }

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

  // ✅ Get current GPS location
  static Future<Position?> getCurrentLocation() async {
    bool hasPermission = await requestPermission();

    if (!hasPermission) {
      print("❌ Location permission not granted.");
      return null;
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print("✅ Current Location: Lat: ${position.latitude}, Lon: ${position.longitude}");
    } catch (e) {
      print("❌ Error getting GPS location: $e");
    }

    return position;
  }
}
