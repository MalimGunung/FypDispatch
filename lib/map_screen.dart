import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_service.dart';
import 'astar_algorithm.dart';
import 'location_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  final FirebaseService firebaseService = FirebaseService();
  final AStarRouteOptimizer optimizer = AStarRouteOptimizer();
  bool hasStartedDelivery =
      false; // ✅ Prevents auto-navigation before pressing the button
  bool isPaused = false; // ✅ Tracks whether delivery is paused

  List<LatLng> deliveryPoints = [];
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  Position? currentPosition;

  // ✅ Replace with your valid Google API Key
  String googleApiKey = "AIzaSyCo0_suiw5NmUQf34lGAkfxlJdLvR01NvI";
  String estimatedTime = "Calculating..."; // ✅ Default ETA text

  @override
  void initState() {
    super.initState();
    fetchDeliveryLocations();
  }

  Future<void> fetchEstimatedTime(LatLng origin, LatLng destination) async {
    String url =
        "https://routes.googleapis.com/directions/v2:computeRoutes?key=$googleApiKey";

    Map<String, dynamic> requestBody = {
      "origin": {
        "location": {
          "latLng": {"latitude": origin.latitude, "longitude": origin.longitude}
        }
      },
      "destination": {
        "location": {
          "latLng": {
            "latitude": destination.latitude,
            "longitude": destination.longitude
          }
        }
      },
      "travelMode": "DRIVE",
      "computeAlternativeRoutes": false,
      "routeModifiers": {
        "avoidTolls": false,
        "avoidHighways": false,
        "avoidFerries": false
      },
      "languageCode": "en-US",
      "units": "METRIC"
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": googleApiKey,
        "X-Goog-FieldMask": "routes.duration",
      },
      body: json.encode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      int durationInSeconds = data["routes"][0]["duration"]["seconds"];
      int minutes = (durationInSeconds / 60).round();

      setState(() {
        estimatedTime = "$minutes min";
      });

      print("🕒 Estimated Time Remaining: $estimatedTime");
    } else {
      print("❌ Google Routes API Error: ${response.body}");
      setState(() {
        estimatedTime = "Unknown";
      });
    }
  }

  Future<void> checkIfDispatcherArrived(Position position) async {
    if (isPaused || deliveryPoints.isEmpty) return;

    LatLng currentLocation = LatLng(position.latitude, position.longitude);
    LatLng nextStop = deliveryPoints.first;

    double distance = Geolocator.distanceBetween(
      currentLocation.latitude,
      currentLocation.longitude,
      nextStop.latitude,
      nextStop.longitude,
    );

    print("📍 Distance to next stop: ${distance.toStringAsFixed(2)} meters");

    // ✅ Fetch ETA and update UI
    fetchEstimatedTime(currentLocation, nextStop);

    if (distance < 50) {
      // ✅ If within 50 meters, mark as arrived
      print("✅ Arrived at stop!");
      deliveryPoints.removeAt(0); // ✅ Remove completed stop

      if (deliveryPoints.isNotEmpty) {
        if (!isPaused) {
          // ✅ Only continue if not paused
          print("🚀 Navigating to next stop...");
          launchWazeNavigation(deliveryPoints.first);
        }
      } else {
        print("🎉 All deliveries completed!");
      }
    }
  }

  void startTrackingDispatcher() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // ✅ Update every 10 meters
      ),
    ).listen((Position position) {
      checkIfDispatcherArrived(position);
    });
  }

  void launchWazeNavigation(LatLng destination) async {
    final Uri wazeUrl = Uri.parse(
        "waze://?ll=${destination.latitude},${destination.longitude}&navigate=yes");
    final Uri fallbackUrl = Uri.parse(
        "https://waze.com/ul?ll=${destination.latitude},${destination.longitude}&navigate=yes");

    if (await canLaunchUrl(wazeUrl)) {
      await launchUrl(wazeUrl, mode: LaunchMode.externalApplication);
    } else {
      print("⚠️ Waze app not installed, opening in browser.");
      await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
    }
  }

  // ✅ Fetch delivery locations and generate optimized route
  Future<void> fetchDeliveryLocations() async {
    if (!hasStartedDelivery)
      return; // ✅ Prevents auto-starting before pressing "Start Delivery"

    Position? position = await LocationService.getCurrentLocation();
    if (position == null) {
      print("❌ Error: Could not retrieve current location.");
      return;
    }

    currentPosition = position;
    List<Map<String, dynamic>> optimizedRoute =
        await optimizer.getOptimizedDeliverySequence();

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
            position:
                LatLng(currentPosition!.latitude, currentPosition!.longitude),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(title: "Start Location"),
          ),
        );

        // ✅ Add numbered markers for delivery points
        for (int i = 0; i < deliveryPoints.length; i++) {
          markers.add(
            Marker(
              markerId: MarkerId((i + 1).toString()), // Numbered marker
              position: deliveryPoints[i],
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(title: "Stop ${i + 1}"),
            ),
          );
        }
      });

      // ✅ Start tracking dispatcher location to automate navigation
      startTrackingDispatcher();

      // ✅ Start navigation to first stop
      launchWazeNavigation(deliveryPoints.first);
    }
  }

  // ✅ Get actual route using Google Routes API
  Future<void> getRouteFromGoogleMaps() async {
    if (deliveryPoints.isEmpty || currentPosition == null) return;

    setState(() {
      polylines.clear(); // Clear previous polylines

      // ✅ Add current location as the first point in the polyline
      List<LatLng> routePoints = [
        LatLng(currentPosition!.latitude,
            currentPosition!.longitude), // Dispatcher’s location
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

    print(
        "✅ Straight-line polyline successfully generated from current location!");
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
      body: Column(
        children: [
          // ✅ Show ETA at the top
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "🕒 Estimated Time to Next Stop: $estimatedTime",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(currentPosition?.latitude ?? 3.1390,
                    currentPosition?.longitude ?? 101.6869), // Default to KL
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
          ),
          // ✅ "Start Delivery" Button
          Padding(
            padding: EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  hasStartedDelivery = true; // ✅ Allow auto-navigation
                });
                fetchDeliveryLocations(); // ✅ Start navigation
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              child: Text("🚀 Start Delivery"),
            ),
          ),
          // ✅ "Pause Delivery" Button
          Padding(
            padding: EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  isPaused = true; // ✅ Pause delivery
                });
                print("⏸️ Delivery paused!");
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text("⏸️ Pause Delivery"),
            ),
          ),
          // ✅ "Resume Delivery" Button
          Padding(
            padding: EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  isPaused = false; // ✅ Resume delivery
                });
                print("▶️ Delivery resumed!");
                if (deliveryPoints.isNotEmpty) {
                  launchWazeNavigation(
                      deliveryPoints.first); // ✅ Resume navigation
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text("▶️ Resume Delivery"),
            ),
          ),
        ],
      ),
    );
  }
}
