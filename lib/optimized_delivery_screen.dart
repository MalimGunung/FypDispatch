import 'package:flutter/material.dart';
import 'greedy_algorithm.dart';
import 'map_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OptimizedDeliveryScreen extends StatefulWidget {
  final String userEmail;
  OptimizedDeliveryScreen({Key? key, required this.userEmail})
      : super(key: key);

  @override
  _OptimizedDeliveryScreenState createState() =>
      _OptimizedDeliveryScreenState();
}

class _OptimizedDeliveryScreenState extends State<OptimizedDeliveryScreen> {
  List<Map<String, dynamic>> deliveryList = [];
  bool isLoading = true;
  final AStarRouteOptimizer optimizer = AStarRouteOptimizer();
  Position? currentPosition;
  List<double?> orsDistances = []; // Store ORS distances for each delivery

  @override
  void initState() {
    super.initState();
    fetchDeliveryList();
  }

  Future<void> fetchDeliveryList() async {
    try {
      currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Map<String, dynamic>> route =
          await optimizer.getOptimizedDeliverySequence(widget.userEmail);
      List<double?> distances = [];
      if (currentPosition != null) {
        for (final delivery in route) {
          double? dist = await _getORSRoadDistance(
            currentPosition!.latitude,
            currentPosition!.longitude,
            delivery['latitude'],
            delivery['longitude'],
          );
          distances.add(dist);
        }
      }
      setState(() {
        deliveryList = route;
        orsDistances = distances;
        isLoading = false;
      });
    } catch (e) {
      print("❌ Error fetching delivery list: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<double?> _getORSRoadDistance(
      double lat1, double lon1, double lat2, double lon2) async {
    const String _orsApiKey =
        '5b3ce3597851110001cf6248c4f4ec157fda4aa7a289bd1c8e4ef93f';
    final url =
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$_orsApiKey&start=$lon1,$lat1&end=$lon2,$lat2';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final distanceMeters =
            data['features'][0]['properties']['segments'][0]['distance'];
        return distanceMeters / 1000.0; // return in KM
      } else {
        print("❌ ORS API Error: ${response.body}");
      }
    } catch (e) {
      print("❌ ORS Request Error: $e");
    }
    return null;
  }

  void _showFullMapDialog(double latitude, double longitude) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.all(12),
          child: Container(
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
    showDialog(
      context: context,
       barrierDismissible: true, 
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), // Slightly more rounded
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24), // Adjusted padding
          backgroundColor: Colors.transparent, // To allow custom background with gradient
          elevation: 0, // Elevation will be handled by the inner container's shadow
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient( // Subtle gradient for dialog background
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
              ]
            ),
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
                          Colors.blueAccent.shade700, // Darker blue for more contrast
                          Colors.blueAccent.shade400
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [ // Shadow for header
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.2),
                          blurRadius: 10,
                          offset: Offset(0,4)
                        )
                      ]
                    ),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), // Add padding around the map card
                    child: Card(
                      elevation: 3,
                      margin: EdgeInsets.zero, // Remove default card margin
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias, // Ensures content respects border radius
                      child: GestureDetector(
                        onTap: () => _showFullMapDialog(latitude, longitude),
                        child: Container(
                          width: double.infinity,
                          height: 170, // Adjusted height
                          child: AbsorbPointer( 
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
                              liteModeEnabled: true, // Keep lite mode for performance
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Details section
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 16), // Adjusted padding
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
                          "${latitude.toStringAsFixed(5)}",
                          Colors.blueAccent.shade700,
                        ),
                        SizedBox(height: 12), // Adjusted spacing
                        _buildDetailRow(
                          Icons.explore_rounded, // Updated icon
                          "Longitude:",
                          "${longitude.toStringAsFixed(5)}",
                          Colors.blueAccent.shade700,
                        ),
                        if (distance != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0), // Adjusted spacing
                            child: _buildDetailRow(
                              Icons.route_outlined, // Updated icon
                              "Distance:",
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
                    padding: const EdgeInsets.only(bottom: 20, right: 20, left: 20, top: 12), // Adjusted padding
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton( // Changed to ElevatedButton for a more defined look
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
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent.shade400,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12), // Adjusted padding
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12), // More rounded
                          ),
                          elevation: 3,
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

  Widget _buildDetailRow(IconData icon, String label, String value, Color iconColor, {bool isBoldValue = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically
      children: [
        Container( // Circular background for icon
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18), // Slightly smaller icon
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
              fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w500, // Value can also be semi-bold
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
        backgroundColor: Colors.transparent, // Keep transparent for gradient body
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
            colors: [Color(0xFFF0F4F8), Color(0xFFE0EAFC)], // Lighter, cleaner gradient
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: true, // Ensure content is below the AppBar
          child: Column(
            children: [
              // Removed SizedBox(height: kToolbarHeight + 32) as SafeArea handles it
              Container(
                margin: EdgeInsets.only(top: 16, bottom: 16, left: 18, right: 18),
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
                    Icon(Icons.assistant_navigation, color: Colors.blueAccent.shade700, size: 24),
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
              Expanded(
                child: isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent.shade700),
                            ),
                            SizedBox(height: 20),
                            Text(
                              "Optimizing your route...",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.blueGrey[700],
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ],
                        ),
                      )
                    : deliveryList.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.map_outlined, size: 60, color: Colors.blueGrey[300]),
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
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            itemCount: deliveryList.length,
                            itemBuilder: (context, index) {
                              final delivery = deliveryList[index];
                              double? distance = (orsDistances.length > index && orsDistances[index] != null)
                                  ? orsDistances[index]
                                  : null;
                              return Card(
                                margin: EdgeInsets.symmetric(vertical: 7),
                                elevation: 2.5, // Subtle elevation
                                shadowColor: Colors.blueAccent.withOpacity(0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.blueAccent.shade400, Colors.blueAccent.shade700],
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
                                      fontWeight: FontWeight.w600, // Slightly bolder
                                      fontSize: 15.5,
                                      fontFamily: 'Montserrat',
                                      color: Colors.blueGrey[800],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: distance != null
                                      ? Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.directions_car_filled_outlined, size: 16, color: Colors.deepPurple.shade300),
                                              SizedBox(width: 4),
                                              Text(
                                                "${distance.toStringAsFixed(1)} km",
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  color: Colors.deepPurple.shade400,
                                                  fontFamily: 'Montserrat',
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
                                    _showLocationDetailDialog(delivery, distance);
                                  },
                                ),
                              );
                            },
                          ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), // Adjusted padding
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
                  onPressed: deliveryList.isEmpty ? null : () { // Disable if list is empty
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
}
