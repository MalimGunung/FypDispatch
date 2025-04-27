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
import 'dart:ui' as ui; // <-- Add this import for custom marker generation

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

  bool _userInteractingWithMap = false;
  DateTime? _lastMapInteraction;
  final Duration _interactionTimeout = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    hasStartedDelivery = true; // Immediately set to true
    fetchDeliveryLocations(); // Auto-fetch without needing button
    // Start a timer to check for interaction timeout
    _startInteractionTimeoutChecker();
  }

  void _startInteractionTimeoutChecker() {
    Future.doWhile(() async {
      await Future.delayed(Duration(seconds: 1));
      if (_userInteractingWithMap && _lastMapInteraction != null) {
        if (DateTime.now().difference(_lastMapInteraction!) > _interactionTimeout) {
          setState(() {
            _userInteractingWithMap = false;
          });
          // Zoom to current location after timeout if position is available
          if (currentPosition != null && mapController != null) {
            animateToCurrentLocation(currentPosition!);
          }
        }
      }
      return mounted;
    });
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

        // --- START: Save to historical automatically ---
        // Fetch all remaining parcels' IDs before deleting
        List<Map<String, dynamic>> parcels = await firebaseService.getStoredAddresses();
        List<String> parcelIds = parcels.map((e) => e['id'].toString()).toList();
        if (parcelIds.isNotEmpty) {
          await firebaseService.moveToHistory(parcelIds);
        }
        // --- END: Save to historical automatically ---

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
      // ✅ Zoom only if user is not interacting
      if (!_userInteractingWithMap) {
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

    // Automatically zoom to current location when entering the page
    if (mapController != null) {
      animateToCurrentLocation(currentPosition!);
    } else {
      // If mapController is not yet ready, zoom after map is created
      Future.delayed(Duration(milliseconds: 500), () {
        if (mapController != null && currentPosition != null) {
          animateToCurrentLocation(currentPosition!);
        }
      });
    }

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
          createNumberedMarker(i + 1, color: Colors.red).then((icon) {
            setState(() {
              markers.add(
                Marker(
                  markerId: MarkerId((i + 1).toString()),
                  position: deliveryPoints[i],
                  icon: icon,
                  infoWindow: InfoWindow(title: "Stop ${i + 1}"),
                ),
              );
            });
          });
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

  // Helper to generate numbered marker icon
  Future<BitmapDescriptor> createNumberedMarker(int number, {Color color = Colors.red}) async {
    final int size = 100;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()..color = color;
    final double radius = size / 2.0;

    // Draw circle
    canvas.drawCircle(Offset(radius, radius), radius, paint);

    // Draw number
    final textPainter = TextPainter(
      text: TextSpan(
        text: number.toString(),
        style: TextStyle(
          fontSize: 48,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(radius - textPainter.width / 2, radius - textPainter.height / 2),
    );

    final img = await recorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Future<bool> _onWillPop() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[400], size: 28),
            SizedBox(width: 10),
            Text(
              "Leave Route?",
              style: TextStyle(
                color: Colors.blueAccent.shade700,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
                fontSize: 22,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to leave this screen?\n\nYour current delivery progress will be lost.",
          style: TextStyle(
            fontSize: 16,
            color: Colors.blueGrey[700],
            fontFamily: 'Montserrat',
          ),
        ),
        actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blueAccent.shade700,
              textStyle: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
            ),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
              elevation: 2,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text("Leave"),
            ),
          ),
        ],
      ),
    );
    return shouldLeave == true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        // Add gradient background
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: const Color.fromARGB(255, 7, 7, 7)),
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.pop(context);
              }
            },
          ),
          iconTheme: IconThemeData(color: Colors.blueAccent.shade700),
          title: Text(
            "Optimized Delivery Route",
            style: TextStyle(
              color: Colors.blueAccent.shade700,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontFamily: 'Montserrat',
            ),
          ),
          centerTitle: true,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFe0eafc), Color(0xFFcfdef3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ETA Card
                Card(
                  margin: EdgeInsets.all(16),
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  color: Colors.white.withOpacity(0.97),
                  shadowColor: Colors.blueAccent.withOpacity(0.10),
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon(Icons.timer, color: Colors.blueAccent.shade700, size: 28),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Estimated Time to Next Stop:",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Montserrat',
                              color: Colors.blueAccent.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          estimatedTime,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Map Section
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Listener(
                        onPointerDown: (_) {
                          setState(() {
                            _userInteractingWithMap = true;
                            _lastMapInteraction = DateTime.now();
                          });
                        },
                        onPointerUp: (_) {
                          setState(() {
                            _lastMapInteraction = DateTime.now();
                          });
                        },
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
                          onCameraMoveStarted: () {
                            setState(() {
                              _userInteractingWithMap = true;
                              _lastMapInteraction = DateTime.now();
                            });
                          },
                          onCameraIdle: () {
                            setState(() {
                              _lastMapInteraction = DateTime.now();
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Delivery List Section
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.97),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.10),
                          blurRadius: 16,
                          offset: Offset(0, -6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(14),
                          child: Text(
                            "Delivery Stops",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent.shade700,
                              fontFamily: 'Montserrat',
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
                                margin: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                                shadowColor: Colors.blueAccent.withOpacity(0.10),
                                child: ListTile(
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: deliveryStatus[index]
                                          ? Colors.green[100]
                                          : Colors.blueAccent.withOpacity(0.10),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      deliveryStatus[index]
                                          ? Icons.check
                                          : Icons.directions_car,
                                      color: deliveryStatus[index]
                                          ? Colors.green
                                          : Colors.blueAccent.shade700,
                                    ),
                                  ),
                                  title: Text(
                                    "Stop ${index + 1}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: deliveryStatus[index]
                                          ? Colors.green[800]
                                          : Colors.blueAccent.shade700,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                  subtitle: Text(
                                    deliveryAddresses[index],
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.blueGrey[700],
                                      fontFamily: 'Montserrat',
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
          ),
        ),

        // Bottom Navigation Bar
        bottomNavigationBar: Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.97),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.10),
                blurRadius: 14,
                offset: Offset(0, -6),
              ),
            ],
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 🔵 Navigate Button
              SizedBox(
                width: 180,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (deliveryPoints.isNotEmpty) {
                      setState(() {
                        isInNavigationMode = true; // ✅ Trigger auto-navigate
                      });
                      launchGoogleMapsNavigation(deliveryPoints.first);
                    }
                  },
                  icon: Icon(Icons.navigation, size: 26),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      "NAVIGATE",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                    shadowColor: Colors.blueAccent.withOpacity(0.22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
