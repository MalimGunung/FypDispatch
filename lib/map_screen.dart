import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_service.dart';
import 'greedy_algorithm.dart';
import 'location_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:reorderables/reorderables.dart';
import 'delivery_complete_screen.dart';

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
  List<bool> deliveryStatus = []; // ⬅️ true = completed, false = pending
  bool hasAnimatedToLocation = false;
  bool isInNavigationMode = false;

  List<LatLng> deliveryPoints = [];
  List<String> deliveryAddresses = []; // ⬅️ Store address names for display
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  Position? currentPosition;

  // ✅ Replace with your valid Google API Key
  String googleApiKey = "AIzaSyCo0_suiw5NmUQf34lGAkfxlJdLvR01NvI";
  String estimatedTime = "Calculating..."; // ✅ Default ETA text

  @override
  void initState() {
    super.initState();
    hasStartedDelivery = true; // Immediately set to true
    fetchDeliveryLocations(); // Auto-fetch without needing button
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
      print("✅ Arrived at stop!");

      setState(() {
        deliveryStatus[0] = true; // Mark as completed
        deliveryPoints.removeAt(0);
        deliveryAddresses.removeAt(0);
        deliveryStatus.removeAt(0);
      });

      if (deliveryPoints.isNotEmpty) {
        if (!isPaused && isInNavigationMode) {
          print("🚀 Auto-navigating to next stop...");
          launchGoogleMapsNavigation(deliveryPoints.first);
        }
      } else {
        // ✅ All deliveries completed
        print("🎉 All deliveries completed!");

        // ✅ Delete all parcels from Firestore
        await firebaseService.deleteAllParcels();

        // ✅ Navigate to confirmation screen (animated)
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DeliveryCompleteScreen(),
            ),
          );
        }
      }
    }
  }

  void startTrackingDispatcher() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      // ✅ Zoom only once at the start to avoid map flickering
      if (!hasAnimatedToLocation) {
        animateToCurrentLocation(position);
        hasAnimatedToLocation = true;
      }

      checkIfDispatcherArrived(position);
    });
  }

  void launchGoogleMapsNavigation(LatLng destination) async {
    final url = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}&travelmode=driving&dir_action=navigate");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      print("❌ Could not open Google Maps");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Google Maps could not be launched")),
      );
    }
  }

  //Reset App State
  void resetAppState() {
    setState(() {
      deliveryPoints.clear();
      deliveryAddresses.clear();
      deliveryStatus.clear();
      markers.clear();
      polylines.clear();
      hasStartedDelivery = false;
      isPaused = false;
      estimatedTime = "Calculating...";
    });
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
        deliveryAddresses = optimizedRoute
            .map((address) => address["address"] as String)
            .toList();
        deliveryStatus = List.generate(deliveryPoints.length, (_) => false);

        markers.clear();

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

        for (int i = 0; i < deliveryPoints.length; i++) {
          markers.add(
            Marker(
              markerId: MarkerId((i + 1).toString()),
              position: deliveryPoints[i],
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(title: "Stop ${i + 1}"),
            ),
          );
        }
      });

      getRouteFromGoogleMaps(); // ✅ Call this to draw the polyline

      // ✅ Start tracking dispatcher location for automation
      startTrackingDispatcher();
    }
  }

  void updateRouteAfterChanges() {
    setState(() {
      polylines.clear(); // ✅ Clear old route
      polylines.add(
        Polyline(
          polylineId: PolylineId("updated_route"),
          points: [
            LatLng(currentPosition!.latitude, currentPosition!.longitude),
            ...deliveryPoints
          ],
          color: Colors.blue,
          width: 5,
        ),
      );
    });

    print("✅ Route updated with new stop order!");
  }

  void _deleteStop(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm Deletion"),
        content:
            Text("Are you sure you want to delete this stop from the list?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        deliveryPoints.removeAt(index);
        deliveryAddresses.removeAt(index);
        deliveryStatus.removeAt(index);
      });

      print("🗑️ Stop removed. Remaining stops: $deliveryPoints");

      // 🔄 Automatically update the route after changes
      updateRouteAfterChanges();
    }
  }

  // ✅ Method to animate camera to current location
  void animateToCurrentLocation(Position position) {
    if (mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16.5, // 🔍 Adjust zoom level as needed
            tilt: 30, // Optional tilt for better 3D view
          ),
        ),
      );
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
      appBar: AppBar(
        title: Text(
          "Optimized Delivery Route",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          // ETA Card
          Card(
            margin: EdgeInsets.all(16),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.timer, color: Colors.blue),
                  SizedBox(width: 12),
                  Text(
                    "Estimated Time to Next Stop:",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Spacer(),
                  Text(
                    estimatedTime, // Make sure this is a String
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Map Section
          Expanded(
            flex: 4,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  currentPosition?.latitude ?? 3.1390,
                  currentPosition?.longitude ?? 101.6869,
                ),
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

          // Delivery List Section
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      "Delivery Stops",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ReorderableColumn(
                      onReorder: (int oldIndex, int newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = deliveryPoints.removeAt(oldIndex);
                          final address = deliveryAddresses.removeAt(oldIndex);
                          final status = deliveryStatus.removeAt(oldIndex);

                          deliveryPoints.insert(newIndex, item);
                          deliveryAddresses.insert(newIndex, address);
                          deliveryStatus.insert(newIndex, status);
                        });
                      },
                      children: List.generate(deliveryPoints.length, (index) {
                        return Card(
                          key: ValueKey(deliveryPoints[index]),
                          margin:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: deliveryStatus[index]
                                    ? Colors.green[100]
                                    : Colors.orange[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                deliveryStatus[index]
                                    ? Icons.check
                                    : Icons.directions_car,
                                color: deliveryStatus[index]
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                            title: Text(
                              "Stop ${index + 1}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: deliveryStatus[index]
                                    ? Colors.green[800]
                                    : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              deliveryAddresses[index],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red[400]),
                              onPressed: () => _deleteStop(index),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -4),
            ),
          ],
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 🔵 Navigate Button
            ElevatedButton.icon(
              onPressed: () {
                if (deliveryPoints.isNotEmpty) {
                  setState(() {
                    isInNavigationMode = true; // ✅ Trigger auto-navigate
                  });
                  launchGoogleMapsNavigation(deliveryPoints.first);
                }
              },
              icon: Icon(Icons.navigation, size: 24),
              label: Text("NAVIGATE"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
