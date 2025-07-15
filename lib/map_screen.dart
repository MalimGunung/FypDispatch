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
  const MapScreen({super.key, required this.userEmail});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  final FirebaseService firebaseService = FirebaseService();
  final GreedyOptimizer optimizer = GreedyOptimizer();
  bool hasStartedDelivery =
      false; // ✅ Prevents auto-navigation before pressing the button
  bool isPaused = false; // ✅ Tracks whether delivery is paused
  List<bool> deliveryStatus = []; // ⬅️ true = completed, false = pending
  bool hasAnimatedToLocation = false;
  bool isInNavigationMode = false;
  bool _isOptimizingRoute = false; // <-- Add this state variable
  bool _isTrackingDispatcher = false; // <-- Add this state variable

  List<LatLng> deliveryPoints = [];
  List<String> deliveryAddresses = []; // ⬅️ Store address names for display
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  Position? currentPosition;

  // ORS API Key and Average Speed
  static const List<String> _orsApiKeys = [
    '5b3ce3597851110001cf6248014503d6bb042740758494cf91a36816644b5aba3fbc5e56ca3d9bfb',
    '5b3ce3597851110001cf6248dab480f8ea3f4444be33bffab7bd37cb'
  ];
  static const double _averageSpeedKmH = 40.0; // Average speed in km/h

  String estimatedTime = "Calculating..."; // ✅ Default ETA text
  DateTime startTime = DateTime.now(); // <-- Add this line to define startTime

  double? _orsTotalDistanceKm; // Store ORS total distance for summary
  int? _originalTotalAddresses; // <-- Add this variable

  // Add a static counter for round-robin API key usage
  static int _orsApiKeyIndex = 0;

  // Helper to get the next ORS API key in round-robin fashion
  String _nextORSApiKey() {
    final key = _orsApiKeys[_orsApiKeyIndex % _orsApiKeys.length];
    _orsApiKeyIndex++;
    return key;
  }

  @override
  void initState() {
    super.initState();
    hasStartedDelivery = true;
    startTime = DateTime.now(); // <-- Initialize startTime when delivery starts
    _startPeriodicZoomToCurrentLocation(); // <-- Add this line
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        fetchDeliveryLocations();
      }
    });
  }

  // Add this method for periodic zoom
  void _startPeriodicZoomToCurrentLocation() {
    Future.doWhile(() async {
      await Future.delayed(Duration(seconds: 5));
      if (mounted && currentPosition != null && mapController != null) {
        animateToCurrentLocation(currentPosition!);
      }
      return mounted;
    });
  }

  // ✅ Draw route using OpenRouteService API
  Future<void> drawORSRoute() async {
    if (currentPosition == null || deliveryPoints.isEmpty) return;

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
        "Authorization": _nextORSApiKey(), // Use round-robin key
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
    // Use round-robin for each request, but fallback if error
    for (int i = 0; i < _orsApiKeys.length; i++) {
      final apiKey = _nextORSApiKey();
      final String orsUrl =
          'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=${origin.longitude},${origin.latitude}&end=${destination.longitude},${destination.latitude}';
      try {
        final response = await http.get(Uri.parse(orsUrl));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          // Use ORS API's duration (in seconds)
          double durationSeconds =
              data['features'][0]['properties']['segments'][0]['duration'];
          int minutes = (durationSeconds / 60).round();
          if (mounted) {
            setState(() {
              estimatedTime = "$minutes min";
            });
          }
          print(
              "🕒 ORS Estimated Time to Next Stop: $estimatedTime (duration: $durationSeconds seconds)");
          return;
        } else {
          print(
              "❌ ORS API Error for ETA (key $apiKey): ${response.statusCode} - ${response.body}");
        }
      } catch (e) {
        print("❌ Exception fetching ORS ETA (key $apiKey): $e");
      }
    }
    if (mounted) {
      setState(() {
        estimatedTime = "Unknown";
      });
    }
  }

  Future<void> checkIfDispatcherArrived(Position position) async {
    if (isPaused || deliveryPoints.isEmpty) return;

    LatLng currentLocation = LatLng(position.latitude, position.longitude);

    // --- Find the nearest stop within 50 meters ---
    int? nearestIndex;
    double minDistance = double.infinity;
    for (int i = 0; i < deliveryPoints.length; i++) {
      double d = Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        deliveryPoints[i].latitude,
        deliveryPoints[i].longitude,
      );
      if (d < minDistance) {
        minDistance = d;
        nearestIndex = i;
      }
    }

    print("📍 Nearest stop is at index $nearestIndex, distance: ${minDistance.toStringAsFixed(2)} meters");

    // Only proceed if within 50 meters of any stop
    if (nearestIndex != null && minDistance < 50) {
      print("✅ Arrived at stop index $nearestIndex!");

      bool proceed = await _showProceedToNextStopDialog();
      if (!proceed) return;

      // --- Mark stop as completed and move to history ---
      List<Map<String, dynamic>> parcels =
          await firebaseService.getStoredAddresses(widget.userEmail);

      // Use a tolerance for coordinate comparison
      const double tolerance = 0.0001;
      Map<String, dynamic>? completedParcel;
      LatLng stopLatLng = deliveryPoints[nearestIndex];
      for (final parcel in parcels) {
        double lat = parcel['latitude'] is int
            ? (parcel['latitude'] as int).toDouble()
            : parcel['latitude'];
        double lng = parcel['longitude'] is int
            ? (parcel['longitude'] as int).toDouble()
            : parcel['longitude'];
        if ((lat - stopLatLng.latitude).abs() < tolerance &&
            (lng - stopLatLng.longitude).abs() < tolerance) {
          completedParcel = parcel;
          break;
        }
      }

      if (completedParcel != null) {
        String parcelId = completedParcel['id'].toString();
        try {
          await firebaseService.updateDeliveryStatus(
              widget.userEmail, parcelId, "complete");
          await firebaseService.moveToHistory(widget.userEmail, [parcelId]);
          await firebaseService.deleteParcel(widget.userEmail, parcelId);
          print("✅ Parcel $parcelId moved to history and deleted from active.");
        } catch (e) {
          print("❌ Error updating/moving/deleting parcel: $e");
        }
      } else {
        print("❌ No matching parcel found for completed stop.");
      }

      setState(() {
        deliveryPoints.removeAt(nearestIndex!);
        deliveryAddresses.removeAt(nearestIndex);
        deliveryStatus.removeAt(nearestIndex);
      });

      // Update route and ETA for the next stop (if any)
      if (deliveryPoints.isNotEmpty) {
        if (currentPosition != null) {
          fetchEstimatedTime(
              LatLng(currentPosition!.latitude, currentPosition!.longitude),
              deliveryPoints.first);
        }
        if (!isPaused && isInNavigationMode) {
          print("🚀 Auto-navigating to next stop...");
          launchGoogleMapsNavigation(deliveryPoints.first);
        }
        drawORSRoute();
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
                polylines.first
                    .points[polylines.first.points.indexOf(point) - 1].latitude,
                polylines
                    .first
                    .points[polylines.first.points.indexOf(point) - 1]
                    .longitude,
              );
        });

        int totalTime = DateTime.now()
            .difference(startTime)
            .inMinutes; // Calculate total time
        int totalAddresses =
            deliveryStatus.length + 1; // Include the starting point

        await recordRouteSummaryToFirebase(totalDistance / 1000, totalTime,
            totalAddresses); // Save to Firebase
      }
    } else {
      // If not arrived, update ETA for the next stop
      if (!_isOptimizingRoute && deliveryPoints.isNotEmpty) {
        fetchEstimatedTime(currentLocation, deliveryPoints.first);
      }
    }
  }

  void startTrackingDispatcher() {
    if (_isTrackingDispatcher) return; // Prevent multiple listeners
    _isTrackingDispatcher = true;
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          currentPosition = position;
        });
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

    setState(() {
      _isOptimizingRoute = true;
      estimatedTime = "Optimizing...";
    });

    Position? position = await LocationService.getCurrentLocation();
    if (position == null) {
      print("❌ Error: Could not retrieve current location.");
      setState(() {
        _isOptimizingRoute = false;
        estimatedTime = "Error";
      });
      return;
    }

    currentPosition = position;

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

        // Store the original total addresses count
        _originalTotalAddresses = deliveryPoints.length;

        markers.clear();

        // Add marker for current position (start of the route)
        if (currentPosition != null) {
          markers.add(
            Marker(
              markerId: MarkerId("0"),
              position: LatLng(currentPosition!.latitude, currentPosition!.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: InfoWindow(title: "Start Location"),
            ),
          );
        }

        for (int i = 0; i < deliveryPoints.length; i++) {
          createNumberedMarker(i + 1, color: Colors.red).then((icon) {
            if (mounted) {
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
            }
          });
        }
        // Fetch ETA for the first stop if points exist
        if (deliveryPoints.isNotEmpty && currentPosition != null) {
          fetchEstimatedTime(
              LatLng(currentPosition!.latitude, currentPosition!.longitude),
              deliveryPoints.first);
        } else {
          estimatedTime = "N/A";
        }
      });

      // --- Calculate and store total ORS distance for summary ---
      _orsTotalDistanceKm = await _calculateORSTotalDistance();

      drawORSRoute();
    } else {
      setState(() {
        estimatedTime = "No stops";
      });
    }
    if (mounted) {
      setState(() {
        _isOptimizingRoute = false;
      });
    }
  }

  // --- Add this method ---
  Future<double?> _calculateORSTotalDistance() async {
    if (currentPosition == null || deliveryPoints.isEmpty) return null;
    double total = 0.0;
    LatLng prev = LatLng(currentPosition!.latitude, currentPosition!.longitude);
    for (final point in deliveryPoints) {
      double? dist = await _getORSRoadDistance(
        prev.latitude, prev.longitude, point.latitude, point.longitude);
      if (dist != null) total += dist;
      prev = point;
    }
    print("✅ ORS total route distance: $total km");
    return total;
  }

  // --- Add this helper ---
  Future<double?> _getORSRoadDistance(
      double lat1, double lon1, double lat2, double lon2) async {
    // Use round-robin for each request, but fallback if error
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
          return distanceMeters / 1000.0; // return in KM
        } else {
          print("❌ ORS API Error (key $apiKey): ${response.body}");
        }
      } catch (e) {
        print("❌ ORS Request Error (key $apiKey): $e");
      }
    }
    return null;
  }

  Future<void> recordRouteSummaryToFirebase(
      double distance, int time, int totalAddresses) async {
    try {
      // Use the original total addresses delivered for the summary.
      final int deliveredCount = _originalTotalAddresses ?? totalAddresses;

      final double distanceToSave =
          (_orsTotalDistanceKm != null && _orsTotalDistanceKm! > 0)
              ? _orsTotalDistanceKm!
              : distance;
      await firebaseService.saveRouteSummary(
        widget.userEmail,
        distance: distanceToSave,
        time: time,
        totalAddresses: deliveredCount,
      );
      print("✅ Route summary recorded to Firebase.");
    } catch (e) {
      print("❌ Error recording route summary: $e");
    }
  }

  Future<void> _deleteStop(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          // Added rounded border
          borderRadius: BorderRadius.circular(22),
        ),
        backgroundColor: Colors.white, // Added background color
        title: Row(
          // Added Row for icon and text
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange[600], size: 28), // Added icon
            SizedBox(width: 10),
            Text(
              "Confirm Deletion",
              style: TextStyle(
                // Styled title
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
          style: TextStyle(
            // Styled content
            fontSize: 16,
            color: Colors.blueGrey[700],
            fontFamily: 'Montserrat',
          ),
        ),
        actionsPadding:
            EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Added padding
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              // Styled cancel button
              foregroundColor: Colors.blueAccent.shade700,
              textStyle: TextStyle(
                  fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
            ),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            // Changed to ElevatedButton for delete
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              // Styled delete button
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
              // Added padding to button text
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
        // Markers will be updated after re-optimization
      });

      print("🗑️ Stop removed. Remaining stops: ${deliveryPoints.length}");

      if (deliveryPoints.isNotEmpty && currentPosition != null) {
        setState(() {
          _isOptimizingRoute = true;
          estimatedTime = "Re-optimizing...";
        });

        // Prepare remaining stops for re-optimization
        List<Map<String, dynamic>> remainingStopsForOptimization = [];
        for (int i = 0; i < deliveryPoints.length; i++) {
          remainingStopsForOptimization.add({
            "latitude": deliveryPoints[i].latitude,
            "longitude": deliveryPoints[i].longitude,
            "address": deliveryAddresses[i],
            // Include other necessary fields if your optimizer uses them, e.g., 'id'
          });
        }

        List<Map<String, dynamic>> newOptimizedRoute =
            await optimizer.getOptimizedDeliverySequence(
          widget.userEmail, // userId is still needed by the optimizer structure
          initialPoints: remainingStopsForOptimization,
          startPosition: currentPosition,
        );

        if (mounted) {
          setState(() {
            if (newOptimizedRoute.isNotEmpty) {
              deliveryPoints = newOptimizedRoute
                  .map((address) =>
                      LatLng(address["latitude"], address["longitude"]))
                  .toList();
              deliveryAddresses = newOptimizedRoute
                  .map((address) => address["address"] as String)
                  .toList();
              deliveryStatus =
                  List.generate(deliveryPoints.length, (_) => false);

              markers.clear();
              // Add marker for current position
              markers.add(
                Marker(
                  markerId: MarkerId("0"), // Start or current location
                  position: LatLng(
                      currentPosition!.latitude, currentPosition!.longitude),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure),
                  infoWindow: InfoWindow(title: "Current Location"),
                ),
              );

              // Add markers for new optimized delivery points
              for (int i = 0; i < deliveryPoints.length; i++) {
                createNumberedMarker(i + 1, color: Colors.red).then((icon) {
                  if (mounted) {
                    setState(() {
                      markers.add(
                        Marker(
                          markerId: MarkerId((i + 1).toString()),
                          position: deliveryPoints[i],
                          icon: icon,
                          infoWindow: InfoWindow(
                              title: "Stop ${i + 1}: ${deliveryAddresses[i]}"),
                        ),
                      );
                    });
                  }
                });
              }

              drawORSRoute(); // Redraw route with new optimized points

              if (deliveryPoints.isNotEmpty) {
                fetchEstimatedTime(
                    LatLng(
                        currentPosition!.latitude, currentPosition!.longitude),
                    deliveryPoints.first);
              } else {
                estimatedTime = "No stops";
              }
            } else {
              // Handle case where re-optimization returns no route (e.g., error)
              deliveryPoints.clear();
              deliveryAddresses.clear();
              deliveryStatus.clear();
              markers.removeWhere((m) =>
                  m.markerId.value != "0"); // Keep current location marker
              polylines.clear();
              estimatedTime = "No stops";
            }
            _isOptimizingRoute = false;
          });
        }
      } else {
        // No delivery points left or current position unknown
        setState(() {
          polylines.clear();
          markers.removeWhere((m) =>
              m.markerId.value !=
              "0"); // Keep current location marker if it exists
          if (deliveryPoints.isEmpty) {
            estimatedTime = "No stops";
          }
          _isOptimizingRoute = false; // Ensure this is reset
        });
      }
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

  void _showStopDetailsDialog(int index) {
    if (index < 0 || index >= deliveryPoints.length) return;

    final LatLng stopLocation = deliveryPoints[index];
    final String stopAddress = deliveryAddresses[index];
    final themeBlue = Colors.blueAccent.shade700;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 28),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withAlpha((0.15 * 255).toInt()),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Custom header with blue gradient & large location icon
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [themeBlue, Colors.blueAccent.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 10),
                    Text(
                      "Stop ${index + 1} Details",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                        fontSize: 21,
                        color: Colors.white,
                        letterSpacing: 0.08
                      ),
                    )
                  ],
                ),
              ),
              Padding(
                padding:
                  EdgeInsets.symmetric(horizontal: 22, vertical: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Address",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                        fontSize: 15.5,
                        color: themeBlue,
                        letterSpacing: 0.04,
                      ),
                    ),
                    SizedBox(height: 7),
                    Card(
                      color: Colors.blueGrey.shade50,
                      shadowColor: Colors.blueGrey.shade100,
                      elevation: 0,
                      margin: EdgeInsets.all(0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11)
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical:12, horizontal: 13),
                        child: Text(
                          stopAddress,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 15.0,
                            color: Colors.blueGrey.shade800,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    SizedBox(height: 17),
                    Divider(color: Colors.grey.shade300),
                    SizedBox(height: 5),
                    Text(
                      "Coordinates",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                        fontSize: 15.5,
                        color: themeBlue,
                      ),
                    ),
                    SizedBox(height: 7),
                    Row(
                      children: [
                        Chip(
                          avatar: Icon(Icons.my_location, color: themeBlue, size:18), // Changed icon
                          backgroundColor: Colors.blue.shade50,
                          label: Text(
                            "Lat: ${stopLocation.latitude.toStringAsFixed(6)}",
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w500,
                              color: themeBlue,
                              fontSize: 13.9,
                            ),
                          ),
                        ),
                        SizedBox(width: 6),
                        Chip(
                          avatar: Icon(Icons.explore, color: Colors.teal, size:18), // Changed icon
                          backgroundColor: Colors.teal.shade50,
                          label: Text(
                            "Lng: ${stopLocation.longitude.toStringAsFixed(6)}",
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w500,
                              color: Colors.teal,
                              fontSize: 13.9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 7),
                  ],
                ),
              ),
              Divider(
                thickness: 1.3,
                color: Colors.grey.shade100,
                height: 0,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical:11, horizontal: 15),
                child: Center(
                  child: SizedBox(
                    height: 42,
                    width: 115,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.close_rounded, size:20, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                        elevation: 2
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      label: Text(
                        "CLOSE",
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _showProceedToNextStopDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.navigation_rounded, color: Colors.blueAccent.shade700, size: 28),
            SizedBox(width: 10),
            Text(
              "Proceed to Next Stop?",
              style: TextStyle(
                color: Colors.blueAccent.shade700,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Text(
          "You have arrived at this stop.\n\nDo you want to proceed to the next delivery location?",
          style: TextStyle(
            fontSize: 16,
            color: Colors.blueGrey[700],
            fontFamily: 'Montserrat',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blueAccent.shade700,
              textStyle: TextStyle(
                  fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
            ),
            child: Text("No"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
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
              child: Text("Yes"),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final themeBlue = Colors.blueAccent.shade700; // Consistent theme color

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBodyBehindAppBar:
            true, // Keep true if AppBar is transparent over content
        appBar: AppBar(
          backgroundColor:
              Colors.transparent, // Will be covered by flexibleSpace
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 22),
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.pop(context);
              }
            },
          ),
          iconTheme: IconThemeData(
              color: Colors.white), // Ensure icons are visible on gradient
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
          flexibleSpace: Container(
            // Gradient background for AppBar
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [themeBlue, Colors.blueAccent.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Container(
          // Main body gradient
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
                    borderRadius:
                        BorderRadius.circular(12), // Consistent rounding
                    side: BorderSide(color: Colors.grey.shade200, width: 0.8),
                  ),
                  color: Colors.white, // Solid white
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14), // Adjusted padding
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined, // Changed icon
                            color: themeBlue,
                            size: 26), // Consistent color
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isOptimizingRoute
                                ? "Optimizing Route:"
                                : "ETA to Next Stop:", // Simplified text
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
                        _isOptimizingRoute
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.green.shade700),
                                ),
                              )
                            : Text(
                                estimatedTime,
                                style: TextStyle(
                                  fontSize: 17, // Adjusted size
                                  fontWeight: FontWeight.w600, // Semi-bold
                                  color:
                                      Colors.green.shade700, // Consistent color
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
                  child: Padding(
                    // Add padding around the map container
                    padding: const EdgeInsets.all(12.0),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(18), // Consistent rounding
                      child: Stack(
                        // <-- Use Stack to overlay loading indicator
                        children: [
                          // Remove Listener and its handlers, just use GoogleMap directly
                          GoogleMap(
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
                            myLocationButtonEnabled: true,
                            mapToolbarEnabled: false,
                            zoomControlsEnabled: false,
                            onMapCreated: (controller) {
                              setState(() {
                                mapController = controller;
                              });
                              // Auto-fetch and draw route once map is ready
                              // if (hasStartedDelivery && deliveryPoints.isEmpty) {
                              //    fetchDeliveryLocations(); // Already called in initState or after frame callback
                              // }
                            },
                            // ...existing code...
                          ),
                          // ...existing code...
                        ],
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
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20)), // Consistent rounding
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueGrey
                              .withOpacity(0.08), // Softer shadow
                          blurRadius: 12,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: 16, horizontal: 18), // Adjusted padding
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
                          child: _isOptimizingRoute
                              ? Center(
                                  // <-- Show loading indicator for list
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                themeBlue),
                                      ),
                                      SizedBox(height: 15),
                                      Text(
                                        "Calculating best sequence...",
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.blueGrey[700],
                                          fontFamily: 'Montserrat',
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : deliveryPoints.isEmpty
                                  ? Center(
                                      // <-- Show message if no stops
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.map_outlined,
                                              size: 48,
                                              color: Colors.blueGrey[300]),
                                          SizedBox(height: 10),
                                          Text(
                                            "No delivery stops.",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.blueGrey[600],
                                              fontFamily: 'Montserrat',
                                            ),
                                          ),
                                          SizedBox(height: 5),
                                          Text(
                                            "Stops will appear here once optimized.",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.blueGrey[400],
                                              fontFamily: 'Montserrat',
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ReorderableColumn(
                                      // <-- Show list if not loading and has stops
                                      onReorder: (int oldIndex, int newIndex) {
                                        setState(() {
                                          if (newIndex > oldIndex) {
                                            newIndex -= 1;
                                          }
                                          final item =
                                              deliveryPoints.removeAt(oldIndex);
                                          final address = deliveryAddresses
                                              .removeAt(oldIndex);
                                          final status =
                                              deliveryStatus.removeAt(oldIndex);

                                          deliveryPoints.insert(newIndex, item);
                                          deliveryAddresses.insert(
                                              newIndex, address);
                                          deliveryStatus.insert(
                                              newIndex, status);
                                          // After reordering, redraw the ORS route
                                          drawORSRoute();

                                          // Fetch ETA for the new first stop
                                          if (deliveryPoints.isNotEmpty &&
                                              currentPosition != null) {
                                            fetchEstimatedTime(
                                                LatLng(
                                                    currentPosition!.latitude,
                                                    currentPosition!.longitude),
                                                deliveryPoints.first);
                                          } else if (deliveryPoints.isEmpty) {
                                            estimatedTime = "No stops";
                                          }
                                        });
                                      },
                                      children: List.generate(
                                          deliveryPoints.length, (index) {
                                        bool isCompleted =
                                            deliveryStatus[index];
                                        return Card(
                                          key: ValueKey(deliveryPoints[index]),
                                          elevation: 1.5,
                                          margin: EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 6), // Adjusted margin
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                12), // Consistent rounding
                                            side: BorderSide(
                                                color: Colors.grey.shade200,
                                                width: 0.8),
                                          ),
                                          color: Colors.white,
                                          child: ListTile(
                                            onTap: () {
                                              _showStopDetailsDialog(index);
                                            },
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical:
                                                        8), // Adjusted padding
                                            leading: Container(
                                              width: 40, // Adjusted size
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: isCompleted
                                                    ? Colors.green.shade50
                                                    : themeBlue.withOpacity(
                                                        0.08), // Softer colors
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isCompleted
                                                    ? Icons
                                                        .check_circle_outline // Changed icon
                                                    : Icons
                                                        .local_shipping_outlined, // Changed icon
                                                color: isCompleted
                                                    ? Colors.green.shade600
                                                    : themeBlue,
                                                size: 22, // Adjusted size
                                              ),
                                            ),
                                            title: Text(
                                              "Stop ${index + 1}",
                                              style: TextStyle(
                                                fontWeight: FontWeight
                                                    .w500, // Medium weight
                                                color: isCompleted
                                                    ? Colors.green.shade800
                                                    : Colors.blueGrey[
                                                        800], // Softer color
                                                fontFamily: 'Montserrat',
                                                fontSize: 15, // Adjusted size
                                              ),
                                            ),
                                            subtitle: Text(
                                              deliveryAddresses[index],
                                              style: TextStyle(
                                                fontSize: 13.5, // Adjusted size
                                                color: Colors.blueGrey[
                                                    600], // Softer color
                                                fontFamily: 'Montserrat',
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            trailing: IconButton(
                                              icon: Icon(
                                                  Icons
                                                      .delete_outline_rounded, // Changed icon
                                                  color: Colors.red.shade400),
                                              onPressed: () =>
                                                  _deleteStop(index),
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
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, -4),
              ),
            ],
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(16)),
          ),
          padding: EdgeInsets.symmetric(
              horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (isPaused ||
                          deliveryPoints.isEmpty ||
                          _isOptimizingRoute)
                      ? null
                      : () {
                          // --- Ensure navigation mode, tracking, and ETA update ---
                          setState(() {
                            isInNavigationMode = true;
                          });
                          startTrackingDispatcher(); // <-- Start tracking if not already
                          if (deliveryPoints.isNotEmpty) {
                            launchGoogleMapsNavigation(deliveryPoints.first);
                            // Update ETA for the first stop
                            if (currentPosition != null) {
                              fetchEstimatedTime(
                                LatLng(currentPosition!.latitude, currentPosition!.longitude),
                                deliveryPoints.first,
                              );
                            }
                            // Draw route
                            drawORSRoute();
                          }
                        },
                  icon: Icon(Icons.navigation_outlined, size: 24),
                  label: Text(
                    "START NAVIGATION",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Montserrat',
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
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

