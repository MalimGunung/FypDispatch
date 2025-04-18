import 'package:flutter/material.dart';
import 'greedy_algorithm.dart';
import 'map_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class OptimizedDeliveryScreen extends StatefulWidget {
  @override
  _OptimizedDeliveryScreenState createState() => _OptimizedDeliveryScreenState();
}

class _OptimizedDeliveryScreenState extends State<OptimizedDeliveryScreen> {
  List<Map<String, dynamic>> deliveryList = [];
  bool isLoading = true;
  final AStarRouteOptimizer optimizer = AStarRouteOptimizer();
  Position? currentPosition;

  @override
  void initState() {
    super.initState();
    fetchDeliveryList();
  }

  Future<void> fetchDeliveryList() async {
    try {
      currentPosition = await Geolocator.getCurrentPosition();
      List<Map<String, dynamic>> route = await optimizer.getOptimizedDeliverySequence();
      setState(() {
        deliveryList = route;
        isLoading = false;
      });
    } catch (e) {
      print("❌ Error fetching delivery list: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth's radius in KM
    double dLat = (lat2 - lat1) * 3.14159265359 / 180;
    double dLon = (lon2 - lon1) * 3.14159265359 / 180;
    double a =
        (sin(dLat / 2) * sin(dLat / 2)) + cos(lat1 * 3.14159265359 / 180) * cos(lat2 * 3.14159265359 / 180) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
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

  void _showLocationDetailDialog(Map<String, dynamic> delivery, double? distance) {
    final double latitude = delivery["latitude"];
    final double longitude = delivery["longitude"];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            "Location Detail",
            style: TextStyle(
              color: Colors.blueAccent.shade700,
              fontWeight: FontWeight.bold,
              fontFamily: 'Montserrat',
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _showFullMapDialog(latitude, longitude),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(latitude, longitude),
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: MarkerId('preview_location'),
                            position: LatLng(latitude, longitude),
                          ),
                        },
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        liteModeEnabled: true,
                        onTap: (_) => _showFullMapDialog(latitude, longitude),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  delivery["address"],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Montserrat',
                    color: Colors.blueGrey[900],
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "Latitude: ${latitude.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.blueGrey[700],
                    fontFamily: 'Montserrat',
                  ),
                ),
                Text(
                  "Longitude: ${longitude.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.blueGrey[700],
                    fontFamily: 'Montserrat',
                  ),
                ),
                if (distance != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Distance: ${distance.toStringAsFixed(2)} km",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.deepPurple,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                "CLOSE",
                style: TextStyle(
                  color: Colors.blueAccent.shade700,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: const Color.fromARGB(255, 7, 7, 7)),
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: IconThemeData(color: const Color.fromARGB(255, 2, 2, 2)),
        title: Text(
          "Optimized Delivery List",
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
          top: false,
          child: Column(
            children: [
              SizedBox(height: kToolbarHeight + 32),
              Container(
                margin: EdgeInsets.only(bottom: 18, left: 18, right: 18),
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.08),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.route, color: const Color.fromARGB(255, 0, 0, 0), size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Here is your optimized delivery sequence.",
                        style: TextStyle(
                          color: Colors.blueAccent.shade700,
                          fontSize: 16,
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
                    ? Center(child: CircularProgressIndicator())
                    : deliveryList.isEmpty
                        ? Center(
                            child: Text(
                              "❌ No deliveries found!\nCheck if addresses are scanned and stored properly.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.red,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: deliveryList.length,
                            itemBuilder: (context, index) {
                              final delivery = deliveryList[index];
                              double? distance;
                              if (currentPosition != null) {
                                distance = calculateDistance(
                                  currentPosition!.latitude,
                                  currentPosition!.longitude,
                                  delivery['latitude'],
                                  delivery['longitude'],
                                );
                              }
                              return Container(
                                margin: EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueAccent.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Card(
                                  color: Colors.white.withOpacity(0.97),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                    leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent.shade700,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.blueAccent.withOpacity(0.18),
                                            blurRadius: 12,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
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
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        fontFamily: 'Montserrat',
                                        color: Colors.blueGrey[900],
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (distance != null)
                                          Text(
                                            "📏 Distance: ${distance.toStringAsFixed(2)} km",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.deepPurple,
                                              fontFamily: 'Montserrat',
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Icon(
                                      Icons.chevron_right,
                                      color: Colors.blueAccent.shade200,
                                    ),
                                    onTap: () {
                                      _showLocationDetailDialog(delivery, distance);
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.13),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MapScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      elevation: 6,
                      shadowColor: Colors.blueAccent.withOpacity(0.22),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map, size: 24),
                        SizedBox(width: 12),
                        Text(
                          "VIEW ON MAP",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ],
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
}

