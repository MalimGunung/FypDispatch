import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'firebase_service.dart';
import 'astar_algorithm.dart';
import 'location_service.dart';


class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  final FirebaseService firebaseService = FirebaseService();
  final AStarRouteOptimizer optimizer = AStarRouteOptimizer();

  List<LatLng> deliveryPoints = [];
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  Position? currentPosition;
  PolylinePoints polylinePoints = PolylinePoints();
  
  // ✅ Ensure you have a valid Google API Key
  String googleApiKey = "AIzaSyCo0_suiw5NmUQf34lGAkfxlJdLvR01NvI"; // 🔥 Replace this with your actual API Key

  @override
  void initState() {
    super.initState();
    fetchDeliveryLocations();
  }

  // ✅ Fetch delivery locations and generate optimized route
  Future<void> fetchDeliveryLocations() async {
    Position? position = await LocationService.getCurrentLocation();
    if (position == null) {
      print("❌ Error: Could not retrieve current location.");
      return;
    }

    currentPosition = position;
    List<Map<String, dynamic>> optimizedRoute = await optimizer.getOptimizedDeliverySequence();

    if (optimizedRoute.isNotEmpty) {
      setState(() {
        deliveryPoints = optimizedRoute
            .map((address) => LatLng(address["latitude"], address["longitude"]))
            .toList();

        markers = optimizedRoute.map((address) {
          return Marker(
            markerId: MarkerId(address["address"]),
            position: LatLng(address["latitude"], address["longitude"]),
            infoWindow: InfoWindow(title: address["address"]),
          );
        }).toSet();
      });

      // ✅ Generate directions route using Google API
      getRouteFromGoogleMaps();
    }
  }

  // ✅ Get actual route using Google Directions API
Future<void> getRouteFromGoogleMaps() async {
  if (deliveryPoints.isEmpty) return;

  List<LatLng> routePoints = [];

  for (int i = 0; i < deliveryPoints.length - 1; i++) {
    PolylineResult polylineResult = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: googleApiKey, // ✅ Ensure API Key is valid
      request: PolylineRequest(
        origin: PointLatLng(deliveryPoints[i].latitude, deliveryPoints[i].longitude),
        destination: PointLatLng(deliveryPoints[i + 1].latitude, deliveryPoints[i + 1].longitude),
        mode: TravelMode.driving, // ✅ FIXED: Use `mode` instead of `travelMode`
        optimizeWaypoints: true, // ✅ Ensure Google optimizes waypoints
      ),
    );

    if (polylineResult.status == "OK" && polylineResult.points.isNotEmpty) {
      setState(() {
        polylines.add(
          Polyline(
            polylineId: PolylineId("optimized_route_${i}"),
            points: polylineResult.points.map((e) => LatLng(e.latitude, e.longitude)).toList(),
            color: Colors.blue,
            width: 5,
          ),
        );
      });
    } else {
      print("❌ Google Directions API Error: ${polylineResult.status}");
    }
  }

  if (polylines.isEmpty) {
    print("❌ No route found. Ensure Google Routes API is enabled.");
  } else {
    print("✅ Route successfully generated!");
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Optimized Delivery Route")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(currentPosition?.latitude ?? 3.1390, currentPosition?.longitude ?? 101.6869), // Default to KL
          zoom: 12,
        ),
        markers: markers,
        polylines: polylines,
        myLocationEnabled: true,
        onMapCreated: (controller) {
          setState(() {
            mapController = controller;
          });
        },
      ),
    );
  }
}

