import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'firebase_service.dart';
import 'location_service.dart';

class GreedyOptimizer {
  final FirebaseService firebaseService = FirebaseService();

  static const List<String> _orsApiKeys = [
    '5b3ce3597851110001cf6248014503d6bb042740758494cf91a36816644b5aba3fbc5e56ca3d9bfb',
    '5b3ce3597851110001cf6248dab480f8ea3f4444be33bffab7bd37cb'
  ];
  static int _orsApiKeyIndex = 0;

  String _nextORSApiKey() {
    final key = _orsApiKeys[_orsApiKeyIndex % _orsApiKeys.length];
    _orsApiKeyIndex++;
    return key;
  }

  Future<double> _getORSRoadDistance(
      double lat1, double lon1, double lat2, double lon2) async {
    for (int i = 0; i < _orsApiKeys.length; i++) {
      final apiKey = _nextORSApiKey();
      final url =
          'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=$lon1,$lat1&end=$lon2,$lat2';
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final distanceMeters =
              data['features'][0]['properties']['segments'][0]['distance'];
          return distanceMeters / 1000.0;
        } else {
          print("❌ ORS API Error (key $apiKey): ${response.body}");
        }
      } catch (e) {
        print("❌ ORS Request Error (key $apiKey): $e");
      }
    }
    return _calculateDistance(lat1, lon1, lat2, lon2);
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  // ✅ Public method to get optimized delivery sequence
  Future<List<Map<String, dynamic>>> getOptimizedDeliverySequence(
    String userId, {
    List<Map<String, dynamic>>? initialPoints,
    Position? startPosition,
  }) async {
    List<Map<String, dynamic>> addresses;
    if (initialPoints != null && initialPoints.isNotEmpty) {
      addresses = List.from(initialPoints);
    } else if (initialPoints == null) {
      addresses = await firebaseService.getStoredAddresses(userId);
    } else {
      return [];
    }

    if (addresses.isEmpty) return [];

    Position? effectiveCurrentLocation =
        startPosition ?? await LocationService.getCurrentLocation();
    if (effectiveCurrentLocation == null) {
      print("❌ Error: Could not determine starting location.");
      return [];
    }

    double currentLat = effectiveCurrentLocation.latitude;
    double currentLon = effectiveCurrentLocation.longitude;
    List<Map<String, dynamic>> route = [];

    while (addresses.isNotEmpty) {
      Map<String, dynamic> nearest = addresses.first;
      double nearestLat = (nearest['latitude'] as num).toDouble();
      double nearestLon = (nearest['longitude'] as num).toDouble();
      double minDistance = await _getORSRoadDistance(
          currentLat, currentLon, nearestLat, nearestLon);

      for (var address in addresses) {
        double addressLat = (address['latitude'] as num).toDouble();
        double addressLon = (address['longitude'] as num).toDouble();
        double distance = await _getORSRoadDistance(
            currentLat, currentLon, addressLat, addressLon);
        if (distance < minDistance) {
          minDistance = distance;
          nearest = address;
        }
      }

      route.add(nearest);
      currentLat = (nearest['latitude'] as num).toDouble();
      currentLon = (nearest['longitude'] as num).toDouble();
      addresses.remove(nearest);
    }

    print("✅ Greedy route generated with ${route.length} stops.");
    return route;
  }
}


