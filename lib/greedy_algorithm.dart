import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'firebase_service.dart';
import 'location_service.dart';

class AStarRouteOptimizer {
  final FirebaseService firebaseService = FirebaseService();

  // ✅ Replace with your ORS API key
  static const String _orsApiKey = '5b3ce3597851110001cf6248c4f4ec157fda4aa7a289bd1c8e4ef93f';

  // ✅ Get real road distance using ORS
  Future<double> _getORSRoadDistance(double lat1, double lon1, double lat2, double lon2) async {
    final url =
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$_orsApiKey&start=$lon1,$lat1&end=$lon2,$lat2';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final distanceMeters = data['features'][0]['properties']['segments'][0]['distance'];
        return distanceMeters / 1000.0; // return in KM
      } else {
        print("❌ ORS API Error: ${response.body}");
      }
    } catch (e) {
      print("❌ ORS Request Error: $e");
    }

    // fallback to Haversine if API fails
    return _calculateDistance(lat1, lon1, lat2, lon2);
  }

  // 🧮 Haversine fallback
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

  Future<double> _totalRouteDistance(List<Map<String, dynamic>> route) async {
    double total = 0.0;
    for (int i = 0; i < route.length - 1; i++) {
      total += await _getORSRoadDistance(
        route[i]['latitude'],
        route[i]['longitude'],
        route[i + 1]['latitude'],
        route[i + 1]['longitude'],
      );
    }
    return total;
  }

  List<Map<String, dynamic>> _twoOptSwap(List<Map<String, dynamic>> route, int i, int k) {
    List<Map<String, dynamic>> newRoute = [];
    newRoute.addAll(route.sublist(0, i));
    newRoute.addAll(route.sublist(i, k + 1).reversed);
    newRoute.addAll(route.sublist(k + 1));
    return newRoute;
  }

  Future<List<Map<String, dynamic>>> _applyTwoOpt(List<Map<String, dynamic>> route) async {
    double bestDistance = await _totalRouteDistance(route);
    List<Map<String, dynamic>> bestRoute = List.from(route);
    bool improved = true;

    while (improved) {
      improved = false;
      for (int i = 1; i < route.length - 2; i++) {
        for (int k = i + 1; k < route.length - 1; k++) {
          List<Map<String, dynamic>> newRoute = _twoOptSwap(bestRoute, i, k);
          double newDistance = await _totalRouteDistance(newRoute);

          if (newDistance < bestDistance) {
            bestDistance = newDistance;
            bestRoute = newRoute;
            improved = true;
          }
        }
      }
      route = bestRoute;
    }

    return bestRoute;
  }

  // ✅ Public method to get optimized delivery sequence
  Future<List<Map<String, dynamic>>> getOptimizedDeliverySequence(String userId) async {
    List<Map<String, dynamic>> addresses = await firebaseService.getStoredAddresses(userId);
    if (addresses.isEmpty) return [];

    Position? currentLocation = await LocationService.getCurrentLocation();
    if (currentLocation == null) return [];

    double currentLat = currentLocation.latitude;
    double currentLon = currentLocation.longitude;

    List<Map<String, dynamic>> route = [];

    while (addresses.isNotEmpty) {
      Map<String, dynamic> nearest = addresses.first;
      double minDistance = await _getORSRoadDistance(currentLat, currentLon, nearest['latitude'], nearest['longitude']);

      for (var address in addresses) {
        double distance = await _getORSRoadDistance(currentLat, currentLon, address['latitude'], address['longitude']);
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

    print("📦 Greedy road-optimized route generated with ${route.length} stops.");

    List<Map<String, dynamic>> optimizedRoute = await _applyTwoOpt(route);

    double finalDistance = await _totalRouteDistance(optimizedRoute);
    print("✅ Final optimized route distance (ORS): ${finalDistance.toStringAsFixed(2)} KM");

    return optimizedRoute;
  }
}
