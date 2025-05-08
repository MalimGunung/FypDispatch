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
      currentPosition = await Geolocator.getCurrentPosition();
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
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          insetPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 32),
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFe0eafc), Color(0xFFcfdef3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.13),
                  blurRadius: 32,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gradient header with icon and title
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blueAccent.shade700,
                        Colors.blueAccent.shade200
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(26)),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          color: const Color.fromARGB(255, 131, 204, 217),
                          size: 30),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Location Detail",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                            fontSize: 22,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Map preview with rounded corners
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                      top: Radius.zero, bottom: Radius.circular(18)),
                  child: GestureDetector(
                    onTap: () => _showFullMapDialog(latitude, longitude),
                    child: Container(
                      width: double.infinity,
                      height: 170,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.blueAccent.withOpacity(0.10),
                            width: 1,
                          ),
                        ),
                      ),
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
                // Details section
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        delivery["address"],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          fontFamily: 'Montserrat',
                          color: Colors.blueGrey[900],
                        ),
                      ),
                      SizedBox(height: 14),
                      Divider(
                        color: Colors.blueAccent.withOpacity(0.18),
                        thickness: 1,
                        height: 1,
                      ),
                      SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(Icons.my_location,
                              color: Colors.blueAccent.shade200, size: 20),
                          SizedBox(width: 6),
                          Text(
                            "Latitude:",
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.blueGrey[700],
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            "${latitude.toStringAsFixed(5)}",
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.blueGrey[900],
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.explore,
                              color: Colors.blueAccent.shade200, size: 20),
                          SizedBox(width: 6),
                          Text(
                            "Longitude:",
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.blueGrey[700],
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            "${longitude.toStringAsFixed(5)}",
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.blueGrey[900],
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ],
                      ),
                      if (distance != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Row(
                            children: [
                              Icon(Icons.straighten,
                                  color: Colors.deepPurple, size: 20),
                              SizedBox(width: 6),
                              Text(
                                "Distance:",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.deepPurple,
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                "${distance.toStringAsFixed(2)} km",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.deepPurple,
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Close button with themed style
                Padding(
                  padding: const EdgeInsets.only(
                      bottom: 16, right: 18, left: 18, top: 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: Icon(Icons.close_rounded,
                            color: Colors.blueAccent.shade700),
                        label: Text(
                          "CLOSE",
                          style: TextStyle(
                            color: Colors.blueAccent.shade700,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blueAccent.shade700,
                          padding: EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          backgroundColor: Colors.blueAccent.withOpacity(0.07),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: const Color.fromARGB(255, 7, 7, 7)),
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
                    Icon(Icons.route,
                        color: const Color.fromARGB(255, 0, 0, 0), size: 22),
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
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            itemCount: deliveryList.length,
                            itemBuilder: (context, index) {
                              final delivery = deliveryList[index];
                              double? distance = (orsDistances.length > index)
                                  ? orsDistances[index]
                                  : null;
                              return Container(
                                margin: EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.blueAccent.withOpacity(0.08),
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
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 16),
                                    leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent.shade700,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.blueAccent
                                                .withOpacity(0.18),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                      _showLocationDetailDialog(
                                          delivery, distance);
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
                        MaterialPageRoute(
                            builder: (context) =>
                                MapScreen(userEmail: widget.userEmail)),
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
