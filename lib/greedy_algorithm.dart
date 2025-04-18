import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'firebase_service.dart';
import 'location_service.dart';

class AStarRouteOptimizer {
  final FirebaseService firebaseService = FirebaseService();

  // ✅ Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth's radius in KM
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _totalRouteDistance(List<Map<String, dynamic>> route) {
    double totalDistance = 0.0;
    for (int i = 0; i < route.length - 1; i++) {
      totalDistance += _calculateDistance(
        route[i]['latitude'],
        route[i]['longitude'],
        route[i + 1]['latitude'],
        route[i + 1]['longitude'],
      );
    }
    return totalDistance;
  }

  List<Map<String, dynamic>> _twoOptSwap(List<Map<String, dynamic>> route, int i, int k) {
    List<Map<String, dynamic>> newRoute = [];
    newRoute.addAll(route.sublist(0, i));
    newRoute.addAll(route.sublist(i, k + 1).reversed);
    newRoute.addAll(route.sublist(k + 1));
    return newRoute;
  }

  List<Map<String, dynamic>> _applyTwoOpt(List<Map<String, dynamic>> route) {
    double bestDistance = _totalRouteDistance(route);
    List<Map<String, dynamic>> bestRoute = List.from(route);

    bool improved = true;
    while (improved) {
      improved = false;

      for (int i = 1; i < route.length - 2; i++) {
        for (int k = i + 1; k < route.length - 1; k++) {
          List<Map<String, dynamic>> newRoute = _twoOptSwap(bestRoute, i, k);
          double newDistance = _totalRouteDistance(newRoute);

          if (newDistance < bestDistance) {
            bestDistance = newDistance;
            bestRoute = newRoute;
            improved = true;
          }
        }
      }
    }

    return bestRoute;
  }

  Future<List<Map<String, dynamic>>> getOptimizedDeliverySequence() async {
    List<Map<String, dynamic>> addresses = await firebaseService.getStoredAddresses();
    if (addresses.isEmpty) return [];

    Position? currentLocation = await LocationService.getCurrentLocation();
    if (currentLocation == null) return [];

    double currentLat = currentLocation.latitude;
    double currentLon = currentLocation.longitude;

    List<Map<String, dynamic>> route = [];
    while (addresses.isNotEmpty) {
      Map<String, dynamic> nearest = addresses.first;
      double minDistance = _calculateDistance(currentLat, currentLon, nearest['latitude'], nearest['longitude']);

      for (var address in addresses) {
        double distance = _calculateDistance(currentLat, currentLon, address['latitude'], address['longitude']);
        if (distance < minDistance) {
          minDistance = distance;
          nearest = address;
        }
      }

      route.add(nearest);
      currentLat = nearest['latitude'];
      currentLon = nearest['longitude'];
      addresses.remove(nearest);
    }

    print("📦 Initial greedy route generated with ${route.length} stops.");
    print("🔁 Running 2-Opt optimization...");
    List<Map<String, dynamic>> optimizedRoute = _applyTwoOpt(route);
    print("✅ Final optimized route ready.");

    return optimizedRoute;
  }
}
