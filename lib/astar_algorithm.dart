import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'firebase_service.dart';
import 'location_service.dart'; // Import location service

class AStarRouteOptimizer {
  final FirebaseService firebaseService = FirebaseService();

  // Calculate distance using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth’s radius in KM
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // Distance in KM
  }

  // Generate an optimized delivery sequence
  Future<List<Map<String, dynamic>>> getOptimizedDeliverySequence() async {
    List<Map<String, dynamic>> addresses = await firebaseService.getStoredAddresses();

    if (addresses.isEmpty) {
      print("❌ No addresses found for optimization.");
      return [];
    }

    Position? currentLocation = await LocationService.getCurrentLocation();

    if (currentLocation == null) {
      print("❌ Could not retrieve current location.");
      return [];
    }

    print("📍 Optimizing delivery for ${addresses.length} locations.");
    print("🚀 Dispatcher Location: Lat: ${currentLocation.latitude}, Lon: ${currentLocation.longitude}");

    // Sort addresses based on the nearest distance to the dispatcher’s current location
    addresses.sort((a, b) {
      double distanceA = _calculateDistance(currentLocation.latitude, currentLocation.longitude, a["latitude"], a["longitude"]);
      double distanceB = _calculateDistance(currentLocation.latitude, currentLocation.longitude, b["latitude"], b["longitude"]);
      return distanceA.compareTo(distanceB);
    });

    print("✅ Optimized Route:");
    for (var i = 0; i < addresses.length; i++) {
      print("${i + 1}. ${addresses[i]["address"]} | Lat: ${addresses[i]["latitude"]}, Lon: ${addresses[i]["longitude"]}");
    }

    return addresses;
  }
}
