// import 'package:geolocator/geolocator.dart';
// import 'firebase_service.dart';
// import 'location_service.dart';
// import 'dart:math';

// class DeliverySequence {
//   final FirebaseService firebaseService = FirebaseService();
//   final LocationService locationService = LocationService();

//   double _calculateDistance(
//       double lat1, double lon1, double lat2, double lon2) {
//     const R = 6371; // Radius of the Earth in km
//     double dLat = (lat2 - lat1) * pi / 180;
//     double dLon = (lon2 - lon1) * pi / 180;
//     double a = sin(dLat / 2) * sin(dLat / 2) +
//         cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
//             sin(dLon / 2) * sin(dLon / 2);
//     double c = 2 * atan2(sqrt(a), sqrt(1 - a));
//     return R * c; // Distance in km
//   }

//   Future<List<Map<String, dynamic>>> getOptimizedDeliverySequence() async {
//     Position currentLocation = await locationService.getCurrentLocation();
//     List<Map<String, dynamic>> addresses = await firebaseService.getStoredAddresses();

//     addresses.sort((a, b) {
//       double distanceA = _calculateDistance(
//           currentLocation.latitude, currentLocation.longitude,
//           a["latitude"], a["longitude"]);
//       double distanceB = _calculateDistance(
//           currentLocation.latitude, currentLocation.longitude,
//           b["latitude"], b["longitude"]);
//       return distanceA.compareTo(distanceB);
//     });

//     return addresses;
//   }
// }
