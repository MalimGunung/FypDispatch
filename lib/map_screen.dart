import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_service.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  final FirebaseService firebaseService = FirebaseService();
  List<LatLng> deliveryPoints = [];
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

  @override
  void initState() {
    super.initState();
    fetchDeliveryLocations();
  }

  // ✅ Fetch delivery locations from Firebase
  Future<void> fetchDeliveryLocations() async {
    List<Map<String, dynamic>> addresses = await firebaseService.getStoredAddresses();

    if (addresses.isNotEmpty) {
      setState(() {
        deliveryPoints = addresses
            .map((address) => LatLng(address["latitude"], address["longitude"]))
            .toList();

        markers = addresses.map((address) {
          return Marker(
            markerId: MarkerId(address["address"]),
            position: LatLng(address["latitude"], address["longitude"]),
            infoWindow: InfoWindow(title: address["address"]),
          );
        }).toSet();
      });

      generateOptimizedRoute();
    }
  }

  // ✅ Generate optimized delivery route
  Future<void> generateOptimizedRoute() async {
    if (deliveryPoints.isEmpty) return;

    Position currentLocation = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    LatLng startPoint = LatLng(currentLocation.latitude, currentLocation.longitude);

    PolylinePoints polylinePoints = PolylinePoints();
    List<LatLng> polylineCoordinates = [startPoint, ...deliveryPoints];

    setState(() {
      polylines.add(Polyline(
        polylineId: PolylineId("optimized_route"),
        points: polylineCoordinates,
        color: Colors.blue,
        width: 5,
      ));

      markers.add(
        Marker(
          markerId: MarkerId("current_location"),
          position: startPoint,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: "Current Location"),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Optimized Delivery Route")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(3.1390, 101.6869), // Default to Kuala Lumpur
          zoom: 10,
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
