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
  final String userEmail;
  MapScreen({Key? key, required this.userEmail}) : super(key: key);

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
  DateTime startTime = DateTime.now(); // Track start time

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
        if (DateTime.now().difference(_lastMapInteraction!) >
            _interactionTimeout) {
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

  // ✅ Draw route using OpenRouteService API
  Future<void> drawORSRoute() async {
    if (currentPosition == null || deliveryPoints.isEmpty) return;

    final String apiKey =
        '5b3ce3597851110001cf6248c4f4ec157fda4aa7a289bd1c8e4ef93f';

    final coordinates = [
      [currentPosition!.longitude, currentPosition!.latitude],
      ...deliveryPoints.map((p) => [p.longitude, p.latitude])
    ];

    final body = json.encode({
      "coordinates": coordinates,
      "instructions": false,
      "format": "geojson"
    });

    final response = await http.post(
      Uri.parse(
          'https://api.openrouteservice.org/v2/directions/driving-car/geojson'),
      headers: {
        "Authorization": apiKey,
        "Content-Type": "application/json",
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final geoJson = json.decode(response.body);
      final coords = geoJson['features'][0]['geometry']['coordinates'];

      List<LatLng> polylinePoints = coords.map<LatLng>((point) {
        return LatLng(point[1], point[0]); // [lon, lat] to LatLng
      }).toList();

      setState(() {
        polylines.clear();
        polylines.add(Polyline(
          polylineId: PolylineId("ors_route"),
          color: Colors.blueAccent,
          width: 5,
          points: polylinePoints,
        ));
      });

      print("✅ ORS route drawn with ${polylinePoints.length} points.");
    } else {
      print("❌ ORS API Error: ${response.body}");
    }
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
        List<Map<String, dynamic>> parcels =
            await firebaseService.getStoredAddresses(widget.userEmail);
        List<String> parcelIds =
            parcels.map((e) => e['id'].toString()).toList();

        // Set delivery status as complete for all parcels
        for (final id in parcelIds) {
          await firebaseService.updateDeliveryStatus(
              widget.userEmail, id, "complete");
        }

        if (parcelIds.isNotEmpty) {
          await firebaseService.moveToHistory(widget.userEmail, parcelIds);
        }
        // --- END: Save to historical automatically ---

        // ✅ Delete all parcels from Firestore
        await firebaseService.deleteAllParcels(widget.userEmail);

        // ✅ Navigate to confirmation screen (animated)
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DeliveryCompleteScreen(),
            ),
          );
        }

        double totalDistance = polylines.first.points.fold(0.0, (sum, point) {
          // Calculate total distance from polyline points
          if (sum == 0.0) return 0.0;
          return sum +
              Geolocator.distanceBetween(
                point.latitude,
                point.longitude,
                polylines.first.points[polylines.first.points.indexOf(point) - 1]
                    .latitude,
                polylines.first.points[polylines.first.points.indexOf(point) - 1]
                    .longitude,
              );
        });

        int totalTime = DateTime.now().difference(startTime).inMinutes; // Calculate total time
        int totalAddresses = deliveryStatus.length + 1; // Include the starting point

        await recordRouteSummaryToFirebase(totalDistance / 1000, totalTime, totalAddresses); // Save to Firebase
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
    if (!hasStartedDelivery) return;

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
        await optimizer.getOptimizedDeliverySequence(widget.userEmail);

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

      drawORSRoute(); // ✅ Call this to draw the polyline
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
        shape: RoundedRectangleBorder( // Added rounded border
          borderRadius: BorderRadius.circular(22),
        ),
        backgroundColor: Colors.white, // Added background color
        title: Row( // Added Row for icon and text
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[600], size: 28), // Added icon
            SizedBox(width: 10),
            Text(
              "Confirm Deletion",
              style: TextStyle( // Styled title
                color: Colors.blueAccent.shade700,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
                fontSize: 22,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete this stop from the list?",
          style: TextStyle( // Styled content
            fontSize: 16,
            color: Colors.blueGrey[700],
            fontFamily: 'Montserrat',
          ),
        ),
        actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Added padding
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom( // Styled cancel button
              foregroundColor: Colors.blueAccent.shade700,
              textStyle: TextStyle(
                  fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
            ),
            child: Text("Cancel"),
          ),
          ElevatedButton( // Changed to ElevatedButton for delete
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom( // Styled delete button
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: TextStyle(
                  fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
              elevation: 2,
            ),
            child: Padding( // Added padding to button text
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text("Delete"),
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
  Future<BitmapDescriptor> createNumberedMarker(int number,
      {Color color = Colors.red}) async {
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
              textStyle: TextStyle(
                  fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
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
              textStyle: TextStyle(
                  fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
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

  Future<void> recordRouteSummaryToFirebase(double distance, int time, int totalAddresses) async {
    try {
      await firebaseService.saveRouteSummary(
        widget.userEmail,
        distance: distance,
        time: time,
        totalAddresses: totalAddresses,
      );
      print("✅ Route summary recorded to Firebase.");
    } catch (e) {
      print("❌ Error recording route summary: $e");
    }
  }

  void _showStopDetailsDialog(int index) {
    if (index < 0 || index >= deliveryPoints.length) return;

    final LatLng stopLocation = deliveryPoints[index];
    final String stopAddress = deliveryAddresses[index];
    final themeBlue = Colors.blueAccent.shade700;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.location_on_outlined, color: themeBlue, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Stop ${index + 1} Details",
                style: TextStyle(
                  color: themeBlue,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text(
                "Address:",
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    color: Colors.blueGrey[700]),
              ),
              SizedBox(height: 4),
              Text(
                stopAddress,
                style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    color: Colors.blueGrey[600]),
              ),
              SizedBox(height: 16),
              Text(
                "Coordinates:",
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    color: Colors.blueGrey[700]),
              ),
              SizedBox(height: 4),
              Text(
                "Latitude: ${stopLocation.latitude.toStringAsFixed(6)}",
                style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    color: Colors.blueGrey[600]),
              ),
              Text(
                "Longitude: ${stopLocation.longitude.toStringAsFixed(6)}",
                style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    color: Colors.blueGrey[600]),
              ),
            ],
          ),
        ),
        actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: themeBlue,
              textStyle: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
            child: Text("CLOSE"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeBlue = Colors.blueAccent.shade700; // Consistent theme color

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBodyBehindAppBar: true, // Keep true if AppBar is transparent over content
        appBar: AppBar(
          backgroundColor: Colors.transparent, // Will be covered by flexibleSpace
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.pop(context);
              }
            },
          ),
          iconTheme: IconThemeData(color: Colors.white), // Ensure icons are visible on gradient
          title: Text(
            "Optimized Delivery Route",
            style: TextStyle(
              color: Colors.white, // White text on gradient
              fontSize: 19, // Adjusted size
              fontWeight: FontWeight.w600, // Semi-bold
              fontFamily: 'Montserrat',
            ),
          ),
          centerTitle: true,
          flexibleSpace: Container( // Gradient background for AppBar
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [themeBlue, Colors.blueAccent.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Container( // Main body gradient
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF3F5F9), Color(0xFFE8EFF5)], // Softer gradient
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ETA Card
                Card(
                  margin: EdgeInsets.fromLTRB(16, 16, 16, 8), // Adjusted margin
                  elevation: 3, // Subtle elevation
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // Consistent rounding
                    side: BorderSide(color: Colors.grey.shade200, width: 0.8),
                  ),
                  color: Colors.white, // Solid white
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14), // Adjusted padding
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined, // Changed icon
                            color: themeBlue, size: 26), // Consistent color
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "ETA to Next Stop:", // Simplified text
                            style: TextStyle(
                              fontSize: 15, // Adjusted size
                              fontWeight: FontWeight.w500, // Medium weight
                              fontFamily: 'Montserrat',
                              color: Colors.blueGrey[700], // Softer color
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          estimatedTime,
                          style: TextStyle(
                            fontSize: 17, // Adjusted size
                            fontWeight: FontWeight.w600, // Semi-bold
                            color: Colors.green.shade700, // Consistent color
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
                  child: Padding( // Add padding around the map container
                    padding: const EdgeInsets.all(12.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18), // Consistent rounding
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
                          myLocationButtonEnabled: true, // Enable the button
                          mapToolbarEnabled: false, // Disable map toolbar for cleaner UI
                          zoomControlsEnabled: false, // Disable zoom controls
                          onMapCreated: (controller) {
                            setState(() {
                              mapController = controller;
                            });
                            // Auto-fetch and draw route once map is ready
                            if (hasStartedDelivery && deliveryPoints.isEmpty) {
                               fetchDeliveryLocations();
                            }
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
                      color: Colors.white, // Solid white background
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)), // Consistent rounding
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueGrey.withOpacity(0.08), // Softer shadow
                          blurRadius: 12,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 18), // Adjusted padding
                          child: Text(
                            "Delivery Stops",
                            style: TextStyle(
                              fontSize: 18, // Adjusted size
                              fontWeight: FontWeight.w600, // Semi-bold
                              color: themeBlue, // Consistent theme color
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
                                final address =
                                    deliveryAddresses.removeAt(oldIndex);
                                final status =
                                    deliveryStatus.removeAt(oldIndex);

                                deliveryPoints.insert(newIndex, item);
                                deliveryAddresses.insert(newIndex, address);
                                deliveryStatus.insert(newIndex, status);
                                // After reordering, redraw the ORS route
                                drawORSRoute();
                              });
                            },
                            children:
                                List.generate(deliveryPoints.length, (index) {
                              bool isCompleted = deliveryStatus[index];
                              return Card(
                                key: ValueKey(deliveryPoints[index]),
                                elevation: 1.5,
                                margin: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6), // Adjusted margin
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12), // Consistent rounding
                                  side: BorderSide(color: Colors.grey.shade200, width: 0.8),
                                ),
                                color: Colors.white,
                                child: ListTile(
                                  onTap: () {
                                    _showStopDetailsDialog(index);
                                  },
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Adjusted padding
                                  leading: Container(
                                    width: 40, // Adjusted size
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isCompleted
                                          ? Colors.green.shade50
                                          : themeBlue.withOpacity(0.08), // Softer colors
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isCompleted
                                          ? Icons.check_circle_outline // Changed icon
                                          : Icons.local_shipping_outlined, // Changed icon
                                      color: isCompleted
                                          ? Colors.green.shade600
                                          : themeBlue,
                                      size: 22, // Adjusted size
                                    ),
                                  ),
                                  title: Text(
                                    "Stop ${index + 1}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500, // Medium weight
                                      color: isCompleted
                                          ? Colors.green.shade800
                                          : Colors.blueGrey[800], // Softer color
                                      fontFamily: 'Montserrat',
                                      fontSize: 15, // Adjusted size
                                    ),
                                  ),
                                  subtitle: Text(
                                    deliveryAddresses[index],
                                    style: TextStyle(
                                      fontSize: 13.5, // Adjusted size
                                      color: Colors.blueGrey[600], // Softer color
                                      fontFamily: 'Montserrat',
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, // Changed icon
                                        color: Colors.red.shade400),
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
          height: 70, // Adjusted height
          decoration: BoxDecoration(
            color: Colors.white, // Solid white
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withOpacity(0.1), // Softer shadow
                blurRadius: 10,
                offset: Offset(0, -4),
              ),
            ],
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)), // Consistent rounding
          ),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8), // Added padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center the button
            children: [
              // 🔵 Navigate Button
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7, // Responsive width
                height: 50, // Fixed height
                child: ElevatedButton.icon(
                  onPressed: (isPaused || deliveryPoints.isEmpty) ? null : () { // Disable if paused or no points
                    if (deliveryPoints.isNotEmpty) {
                      setState(() {
                        isInNavigationMode = true;
                      });
                      launchGoogleMapsNavigation(deliveryPoints.first);
                    }
                  },
                  icon: Icon(Icons.navigation_outlined, size: 24), // Changed icon
                  label: Text(
                    "START NAVIGATION", // Updated text
                    style: TextStyle(
                      fontSize: 16, // Adjusted size
                      fontWeight: FontWeight.w600, // Semi-bold
                      fontFamily: 'Montserrat',
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeBlue, // Consistent theme color
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // Consistent rounding
                    ),
                    elevation: 2, // Subtle elevation
                    shadowColor: themeBlue.withOpacity(0.2),
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
