import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
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
  
  // ✅ Replace with your valid Google API Key
  String googleApiKey = "AIzaSyCo0_suiw5NmUQf34lGAkfxlJdLvR01NvI";

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

      markers.clear(); // Clear existing markers

      // ✅ Add dispatcher location as Marker 0
      markers.add(
        Marker(
          markerId: MarkerId("0"),
          position: LatLng(currentPosition!.latitude, currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: "Start Location"),
        ),
      );

      // ✅ Add numbered markers for delivery points
      for (int i = 0; i < deliveryPoints.length; i++) {
        markers.add(
          Marker(
            markerId: MarkerId((i + 1).toString()), // Numbered marker
            position: deliveryPoints[i],
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: "Stop ${i + 1}"),
          ),
        );
      }
    });

    // ✅ Generate polyline starting from dispatcher’s location
    getRouteFromGoogleMaps();
  }
}


  // ✅ Get actual route using Google Routes API
Future<void> getRouteFromGoogleMaps() async {
  if (deliveryPoints.isEmpty || currentPosition == null) return;

  setState(() {
    polylines.clear(); // Clear previous polylines

    // ✅ Add current location as the first point in the polyline
    List<LatLng> routePoints = [
      LatLng(currentPosition!.latitude, currentPosition!.longitude), // Dispatcher’s location
      ...deliveryPoints, // Followed by delivery stops
    ];

    polylines.add(
      Polyline(
        polylineId: PolylineId("straight_line_route"),
        points: routePoints, // ✅ Connect current location to delivery points
        color: Colors.blue,
        width: 5,
      ),
    );
  });

  print("✅ Straight-line polyline successfully generated from current location!");
}



  // ✅ Decode Google Polyline to display actual navigation path
  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
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
