import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'firebase_service.dart';
import 'location_service.dart';

class AStarRouteOptimizer {
  final FirebaseService firebaseService = FirebaseService();

  // ✅ Haversine formula to calculate distance
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth's radius in KM
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

  // ✅ A-Star Algorithm for optimized delivery sequence
  Future<List<Map<String, dynamic>>> getOptimizedDeliverySequence() async {
    List<Map<String, dynamic>> addresses = await firebaseService.getStoredAddresses();

    if (addresses.isEmpty) {
      print("❌ No addresses found for optimization.");
      return [];
    }

    Position? currentLocation = await LocationService.getCurrentLocation();
    if (currentLocation == null) {
      print("❌ Unable to get dispatcher's location. Make sure GPS is enabled.");
      return [];
    }

    print("📍 Running A-Star Algorithm for ${addresses.length} locations.");
    print("🚀 Dispatcher Start Location: Lat: ${currentLocation.latitude}, Lon: ${currentLocation.longitude}");

    List<Map<String, dynamic>> optimizedRoute = [];
    Set<String> visited = {};
    List<Map<String, dynamic>> unvisited = List.from(addresses);

    double currentLat = currentLocation.latitude;
    double currentLon = currentLocation.longitude;

    while (unvisited.isNotEmpty) {
      // ✅ Sort by best A-Star path
      unvisited.sort((a, b) {
        double gA = _calculateDistance(currentLat, currentLon, a["latitude"], a["longitude"]);
        double gB = _calculateDistance(currentLat, currentLon, b["latitude"], b["longitude"]);

        return gA.compareTo(gB);
      });

      Map<String, dynamic> nextStop = unvisited.removeAt(0);

      if (visited.contains(nextStop["id"])) continue;

      visited.add(nextStop["id"]);
      optimizedRoute.add(nextStop);

      print("✅ Next Stop: ${nextStop["address"]} | Lat: ${nextStop["latitude"]}, Lon: ${nextStop["longitude"]}");

      currentLat = nextStop["latitude"];
      currentLon = nextStop["longitude"];
    }

    print("✅ Optimized Route Generated with ${optimizedRoute.length} stops.");
    return optimizedRoute;
  }
}
