import 'package:flutter/material.dart';
import 'greedy_algorithm.dart';
import 'map_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OptimizedDeliveryScreen extends StatefulWidget {
  final String userEmail;
  final bool forceReoptimize;

  const OptimizedDeliveryScreen({
    super.key,
    required this.userEmail,
    this.forceReoptimize = false,
  });

  // Static cache for optimization results
  static List<Map<String, dynamic>>? _cachedRoute;
  static List<double?>? _cachedDistances;
  static double? _cachedTotalDistance;
  static String? _cachedEstimatedTime;
  static bool _cacheInvalidated = true;

  // Call this from parcel_scanner.dart after changes
  static void invalidateCache() {
    _cacheInvalidated = true;
  }

  @override
  _OptimizedDeliveryScreenState createState() =>
      _OptimizedDeliveryScreenState();
}

class _OptimizedDeliveryScreenState extends State<OptimizedDeliveryScreen> {
  List<Map<String, dynamic>> deliveryList = [];
  bool isLoading = true;
  final GreedyOptimizer optimizer = GreedyOptimizer();
  Position? currentPosition;
  List<double?> orsDistances = [];
  double loadingProgress = 0.0;
  String loadingMessage = "Initializing...";
  double _totalDistanceInKm = 0.0;
  String _estimatedTotalTime = "Calculating...";
  bool _hasOptimizedOnce = false;

  @override
  void initState() {
    super.initState();
    // Use cache if available and not invalidated, else optimize
    if (!OptimizedDeliveryScreen._cacheInvalidated &&
        OptimizedDeliveryScreen._cachedRoute != null &&
        OptimizedDeliveryScreen._cachedDistances != null &&
        OptimizedDeliveryScreen._cachedTotalDistance != null &&
        OptimizedDeliveryScreen._cachedEstimatedTime != null &&
        !widget.forceReoptimize) {
      setState(() {
        deliveryList = OptimizedDeliveryScreen._cachedRoute!;
        orsDistances = OptimizedDeliveryScreen._cachedDistances!;
        _totalDistanceInKm = OptimizedDeliveryScreen._cachedTotalDistance!;
        _estimatedTotalTime = OptimizedDeliveryScreen._cachedEstimatedTime!;
        isLoading = false;
      });
    } else {
      fetchDeliveryList();
    }
  }

  @override
  void didUpdateWidget(covariant OptimizedDeliveryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If forceReoptimize is true, re-run optimization
    if (widget.forceReoptimize && !_hasOptimizedOnce) {
      fetchDeliveryList();
      _hasOptimizedOnce = true;
    }
  }

  Future<void> fetchDeliveryList() async {
    try {
      setState(() {
        isLoading = true;
        loadingMessage = "Fetching current location...";
        loadingProgress = 0.1;
        _totalDistanceInKm = 0.0;
        _estimatedTotalTime = "Calculating...";
      });
      currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        loadingMessage = "Optimizing delivery sequence...";
        loadingProgress = 0.3;
      });
      List<Map<String, dynamic>> route =
          await optimizer.getOptimizedDeliverySequence(widget.userEmail);

      List<double?> distances = [];
      double calculatedTotalDistance = 0.0;
      if (currentPosition != null && route.isNotEmpty) {
        setState(() {
          loadingMessage = "Calculating road distance 1 of ${route.length}...";
          loadingProgress = 0.5 + (0.5 * (1 / route.length));
        });
        double? initialDist = await _getORSRoadDistance(
          currentPosition!.latitude,
          currentPosition!.longitude,
          route[0]['latitude'],
          route[0]['longitude'],
        );
        distances.add(initialDist);
        if (initialDist != null) {
          calculatedTotalDistance += initialDist;
        }

        for (int i = 0; i < route.length - 1; i++) {
          setState(() {
            loadingMessage =
                "Calculating road distance ${i + 2} of ${route.length}...";
            loadingProgress = 0.5 + (0.5 * ((i + 2) / route.length));
          });
          double? dist = await _getORSRoadDistance(
            route[i]['latitude'],
            route[i]['longitude'],
            route[i + 1]['latitude'],
            route[i + 1]['longitude'],
          );
          distances.add(dist);
          if (dist != null) {
            calculatedTotalDistance += dist;
          }
        }
      } else if (route.isEmpty) {
        setState(() {
          loadingProgress = 1.0;
        });
      }

      String estimatedTimeStr = "N/A";
      if (route.isNotEmpty && calculatedTotalDistance > 0) {
        double drivingHours = calculatedTotalDistance / 40.0;
        double stopMinutes = route.length * 5.0;
        double totalMinutes = (drivingHours * 60) + stopMinutes;

        int hours = totalMinutes ~/ 60;
        int minutes = (totalMinutes % 60).round();
        estimatedTimeStr = "${hours}h ${minutes}m";
      } else if (route.isNotEmpty &&
          calculatedTotalDistance == 0 &&
          orsDistances.any((d) => d == null)) {
        estimatedTimeStr = "Partial data";
      }

      setState(() {
        deliveryList = route;
        orsDistances = distances;
        _totalDistanceInKm = calculatedTotalDistance;
        _estimatedTotalTime = estimatedTimeStr;
        isLoading = false;
        loadingMessage = "Done!";
      });

      // Cache the result
      OptimizedDeliveryScreen._cachedRoute = route;
      OptimizedDeliveryScreen._cachedDistances = distances;
      OptimizedDeliveryScreen._cachedTotalDistance = calculatedTotalDistance;
      OptimizedDeliveryScreen._cachedEstimatedTime = estimatedTimeStr;
      OptimizedDeliveryScreen._cacheInvalidated = false;
    } catch (e) {
      print("❌ Error fetching delivery list: $e");
      setState(() {
        isLoading = false;
        loadingMessage = "Error occurred.";
      });
    }
  }

  // Use two ORS API keys for improved reliability
  static const List<String> _orsApiKeys = [
    '5b3ce3597851110001cf6248014503d6bb042740758494cf91a36816644b5aba3fbc5e56ca3d9bfb',
    '5b3ce3597851110001cf6248dab480f8ea3f4444be33bffab7bd37cb'
  ];

  Future<double?> _getORSRoadDistance(
      double lat1, double lon1, double lat2, double lon2) async {
    for (final apiKey in _orsApiKeys) {
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
          // If rate limit or error, try next key
        }
      } catch (e) {
        print("❌ ORS Request Error (key $apiKey): $e");
        // Try next key
      }
    }
    return null;
  }

  void _showFullMapDialog(double latitude, double longitude) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            height: 400,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(latitude, longitude),
                zoom: 16,
              ),
              markers: {
                Marker(
                  markerId: MarkerId('selected_location'),
                  position: LatLng(latitude, longitude),
                ),
              },
              zoomControlsEnabled: true,
              myLocationButtonEnabled: false,
            ),
          ),
        );
      },
    );
  }

  void _showLocationDetailDialog(
      Map<String, dynamic> delivery, double? distance) {
    final double latitude = delivery["latitude"];
    final double longitude = delivery["longitude"];
    int index = deliveryList.indexOf(delivery);
    String distanceLabel = "";
    if (distance != null) {
      if (index == 0) {
        distanceLabel = "From Current Location";
      } else {
        distanceLabel = "From Stop $index";
      }
    }
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)), // Slightly more rounded
          insetPadding: EdgeInsets.symmetric(
              horizontal: 16, vertical: 24), // Adjusted padding
          backgroundColor:
              Colors.transparent, // To allow custom background with gradient
          elevation:
              0, // Elevation will be handled by the inner container's shadow
          child: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  // Subtle gradient for dialog background
                  colors: [Color(0xFFFDFEFE), Color(0xFFF4F6F9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  )
                ]),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gradient header with icon and title
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blueAccent
                                .shade700, // Darker blue for more contrast
                            Colors.blueAccent.shade400
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: [
                          // Shadow for header
                          BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.2),
                              blurRadius: 10,
                              offset: Offset(0, 4))
                        ]),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Icon(Icons.pin_drop_outlined, // Changed icon
                            color: Colors.white,
                            size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Location Details", // Adjusted title
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Montserrat',
                              fontSize: 20, // Adjusted font size
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Map preview with rounded corners
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        16, 16, 16, 8), // Add padding around the map card
                    child: Card(
                      elevation: 3,
                      margin: EdgeInsets.zero, // Remove default card margin
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip
                          .antiAlias, // Ensures content respects border radius
                      child: GestureDetector(
                        // Remove AbsorbPointer so the map is interactive and toolbar works
                        onTap: () => _showFullMapDialog(latitude, longitude),
                        child: SizedBox(
                          width: double.infinity,
                          height: 170, // Adjusted height
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(latitude, longitude),
                              zoom: 15.5, // Slightly more zoom
                            ),
                            markers: {
                              Marker(
                                markerId: MarkerId('preview_location'),
                                position: LatLng(latitude, longitude),
                              ),
                            },
                            zoomControlsEnabled: false,
                            myLocationButtonEnabled: false,
                            liteModeEnabled:
                                true, // Keep lite mode for performance
                            mapToolbarEnabled:
                                true, // Enable Google Map toolbar (directions/map button)
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Details section
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16), // Adjusted padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          delivery["address"],
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                            fontFamily: 'Montserrat',
                            color: Colors.blueGrey[900],
                          ),
                        ),
                        SizedBox(height: 18), // Increased spacing
                        Divider(
                          color: Colors.grey[200], // Lighter divider
                          thickness: 1,
                        ),
                        SizedBox(height: 18), // Increased spacing
                        _buildDetailRow(
                          Icons.gps_fixed_rounded, // Updated icon
                          "Latitude:",
                          latitude.toStringAsFixed(5),
                          Colors.blueAccent.shade700,
                        ),
                        SizedBox(height: 12), // Adjusted spacing
                        _buildDetailRow(
                          Icons.explore_rounded, // Updated icon
                          "Longitude:",
                          longitude.toStringAsFixed(5),
                          Colors.blueAccent.shade700,
                        ),
                        if (distance != null)
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 12.0), // Adjusted spacing
                            child: _buildDetailRow(
                              Icons.route_outlined, // Updated icon
                              "$distanceLabel:",
                              "${distance.toStringAsFixed(1)} km",
                              Colors.deepPurple.shade400,
                              isBoldValue: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Close button with themed style
                  Padding(
                    padding: const EdgeInsets.only(
                        bottom: 20,
                        right: 20,
                        left: 20,
                        top: 12), // Adjusted padding
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        // Changed to ElevatedButton for a more defined look
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent.shade400,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12), // Adjusted padding
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12), // More rounded
                          ),
                          elevation: 3,
                        ),
                        // Changed to ElevatedButton for a more defined look
                        child: Text(
                          "CLOSE",
                          style: TextStyle(
                            // color: Colors.white, // Text color is handled by ElevatedButton's foregroundColor
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                            fontSize: 14, // Slightly smaller
                            letterSpacing: 0.5,
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
      },
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, Color iconColor,
      {bool isBoldValue = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically
      children: [
        Container(
          // Circular background for icon
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child:
              Icon(icon, color: iconColor, size: 18), // Slightly smaller icon
        ),
        SizedBox(width: 12), // Increased spacing
        Text(
          label,
          style: TextStyle(
            fontSize: 14.5, // Adjusted font size
            color: Colors.blueGrey[700], // Slightly darker label
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14.5, // Adjusted font size
              color: Colors.blueGrey[800],
              fontFamily: 'Montserrat',
              fontWeight: isBoldValue
                  ? FontWeight.bold
                  : FontWeight.w500, // Value can also be semi-bold
            ),
            textAlign: TextAlign.right, // Align value to the right
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor:
            Colors.transparent, // Keep transparent for gradient body
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Optimized Route",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'Montserrat',
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent.shade700, Colors.blueAccent.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF0F4F8),
              Color(0xFFE0EAFC)
            ], // Lighter, cleaner gradient
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: true, // Ensure content is below the AppBar
          child: Column(
            children: [
              Container(
                margin:
                    EdgeInsets.only(top: 16, bottom: 16, left: 18, right: 18),
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assistant_navigation,
                        color: Colors.blueAccent.shade700, size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Your optimized delivery sequence:",
                        style: TextStyle(
                          color: Colors.blueGrey[800],
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Montserrat',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              // Summary Section
              if (!isLoading && deliveryList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                      top: 0,
                      left: 18,
                      right: 18,
                      bottom: 16), // Adjusted top padding
                  child: Card(
                    color: Colors.white, // Change card color to white
                    elevation: 4, // Slightly increased elevation
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(16)), // More rounded corners
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 16.0), // Adjusted padding
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem(
                                Icons.pin_drop_outlined,
                              "${deliveryList.length}",
                              "Addresses",
                              Colors.orange.shade700),
                          _buildSummaryItem(
                              Icons.route_outlined,
                              "${_totalDistanceInKm.toStringAsFixed(1)} km",
                              "Distance",
                              Colors.green.shade700),
                          _buildSummaryItem(
                              Icons.timer_outlined,
                              _estimatedTotalTime,
                              "Est. Time",
                              Colors.deepPurple
                                  .shade400), // Changed to deepPurple for consistency
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: isLoading
                    ? Center(
                        child: Padding(
                          // Added padding for the loading indicator
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                loadingMessage,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.blueGrey[700],
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 20),
                              LinearProgressIndicator(
                                value: loadingProgress,
                                backgroundColor: Colors.blueGrey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.blueAccent.shade700),
                                minHeight: 8, // Make the progress bar thicker
                              ),
                              SizedBox(height: 10),
                              Text(
                                // Kept this as a general message
                                "Optimizing your route, please wait...",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.blueGrey[600],
                                  fontFamily: 'Montserrat',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : deliveryList.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.map_outlined,
                                      size: 60, color: Colors.blueGrey[300]),
                                  SizedBox(height: 16),
                                  Text(
                                    "No Deliveries Found",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.blueGrey[700],
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Please ensure addresses are scanned and saved correctly.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.blueGrey[500],
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            itemCount: deliveryList.length,
                            itemBuilder: (context, index) {
                              final delivery = deliveryList[index];
                              double? distance = (orsDistances.isNotEmpty &&
                                      orsDistances.length > index)
                                  ? orsDistances[index]
                                  : null;
                              return Card(
                                color: Colors.white, // Set card color to white
                                margin: EdgeInsets.symmetric(vertical: 7),
                                elevation: 2.5, // Subtle elevation
                                shadowColor: Colors.blueAccent.withOpacity(0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blueAccent.shade400,
                                          Colors.blueAccent.shade700
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          fontFamily: 'Montserrat',
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    delivery["address"],
                                    style: TextStyle(
                                      fontWeight:
                                          FontWeight.w600, // Slightly bolder
                                      fontSize: 15.5,
                                      fontFamily: 'Montserrat',
                                      color: Colors.blueGrey[800],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: distance != null &&
                                          index < orsDistances.length
                                      ? Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Row(
                                            children: [
                                              Icon(
                                                  Icons
                                                      .directions_car_filled_outlined,
                                                  size: 16,
                                                  color: Colors
                                                      .deepPurple.shade300),
                                              SizedBox(width: 4),
                                              Text(
                                                index == 0
                                                    ? "From Current Location: ${distance.toStringAsFixed(1)} km"
                                                    : "From Stop $index: ${distance.toStringAsFixed(1)} km",
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  color: Colors
                                                      .deepPurple.shade400,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : null,
                                  trailing: Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Colors.blueAccent.shade200,
                                    size: 18,
                                  ),
                                  onTap: () {
                                    _showLocationDetailDialog(
                                        delivery, distance);
                                  },
                                ),
                              );
                            },
                          ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    20, 16, 20, 20), // Adjusted padding
                child: ElevatedButton.icon(
                  icon: Icon(Icons.map_outlined, size: 22),
                  label: Text(
                    "VIEW FULL ROUTE ON MAP",
                    style: TextStyle(
                      fontSize: 16, // Slightly smaller for better fit
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  onPressed: deliveryList.isEmpty
                      ? null
                      : () {
                          // Disable if list is empty
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    MapScreen(userEmail: widget.userEmail)),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.shade700,
                    disabledBackgroundColor: Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 52), // Adjusted height
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16), // More rounded
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    elevation: 5,
                    shadowColor: Colors.blueAccent.withOpacity(0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
      IconData icon, String value, String label, Color iconColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 28), // Slightly larger icon
        SizedBox(height: 6), // Increased spacing
        Text(
          value,
          style: TextStyle(
            fontSize: 17, // Slightly larger font size for value
            fontWeight: FontWeight.bold,
            fontFamily: 'Montserrat',
            color: Colors.blueGrey[900], // Darker color for value
          ),
        ),
        SizedBox(height: 3), // Adjusted spacing
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5, // Slightly adjusted font size for label
            fontFamily: 'Montserrat',
            color: Colors.blueGrey[700], // Medium-dark grey for label
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
