import 'dart:math';
import 'package:collection/collection.dart'; // ✅ Import built-in PriorityQueue
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
    
    // ✅ Initialize PriorityQueue
    PriorityQueue<Map<String, dynamic>> openSet = PriorityQueue<Map<String, dynamic>>(
        (a, b) => (a["fScore"] as double).compareTo(b["fScore"] as double));

    // Start from current location
    double startLat = currentLocation.latitude;
    double startLon = currentLocation.longitude;

    // ✅ Add all locations to priority queue with fScore = gScore + hScore
    for (var address in addresses) {
      double gScore = _calculateDistance(startLat, startLon, address["latitude"], address["longitude"]);
      double hScore = _calculateDistance(address["latitude"], address["longitude"], addresses.first["latitude"], addresses.first["longitude"]);
      address["gScore"] = gScore;
      address["hScore"] = hScore;
      address["fScore"] = gScore + hScore;
      openSet.add(address);
    }

    while (openSet.isNotEmpty) {
      // ✅ Get the location with the lowest fScore
      Map<String, dynamic> current = openSet.removeFirst();

      if (visited.contains(current["id"])) continue;

      visited.add(current["id"]);
      optimizedRoute.add(current);

      print("✅ Next Stop: ${current["address"]} | Lat: ${current["latitude"]}, Lon: ${current["longitude"]}");

      startLat = current["latitude"];
      startLon = current["longitude"];

      // ✅ Recalculate fScore for remaining locations
      List<Map<String, dynamic>> newSet = [];
      for (var address in addresses) {
        if (visited.contains(address["id"])) continue;

        double gScore = _calculateDistance(startLat, startLon, address["latitude"], address["longitude"]);
        double hScore = _calculateDistance(address["latitude"], address["longitude"], addresses.first["latitude"], addresses.first["longitude"]);
        address["gScore"] = gScore;
        address["hScore"] = hScore;
        address["fScore"] = gScore + hScore;

        newSet.add(address);
      }

      // ✅ Re-sort priority queue based on fScores
      openSet = PriorityQueue<Map<String, dynamic>>(
          (a, b) => (a["fScore"] as double).compareTo(b["fScore"] as double));
      openSet.addAll(newSet);
    }

    print("✅ Optimized Route Generated with ${optimizedRoute.length} stops.");
    return optimizedRoute;
  }
}
