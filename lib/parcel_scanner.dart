import 'package:flutter/material.dart';
import 'firebase_service.dart';
import 'mlkit_ocr.dart';
import 'camera_screen.dart';
import 'package:geocoding/geocoding.dart';
import 'optimized_delivery_screen.dart';
import 'map_screen.dart';

class ParcelScanning extends StatefulWidget {
  @override
  _ParcelScanningState createState() => _ParcelScanningState();
}

class _ParcelScanningState extends State<ParcelScanning> {
  final MLKitOCR mlkitOCR = MLKitOCR();
  final FirebaseService firebaseService = FirebaseService();
  List<Map<String, dynamic>> addressList = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchStoredAddresses();
  }

  // ✅ Fetch stored addresses from Firebase
  Future<void> fetchStoredAddresses() async {
    setState(() => isLoading = true);
    List<Map<String, dynamic>> storedAddresses =
        await firebaseService.getStoredAddresses();
    setState(() {
      addressList = storedAddresses;
      isLoading = false;
    });
  }

  // ✅ Capture and scan an address from an image
  Future<void> scanParcel() async {
    final imagePath = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => CameraScreen()), // ✅ Call CameraScreen
    );

    if (imagePath != null) {
      String address = await mlkitOCR.extractTextFromImage(imagePath);

      if (address.isEmpty || address == "No valid address detected") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("❌ No valid address detected. Please try again.")),
        );
        return;
      }

      var coordinates = await getCoordinates(address);

      if (coordinates == null ||
          !coordinates.containsKey("latitude") ||
          !coordinates.containsKey("longitude")) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to get location for this address!")),
        );
        print("❌ Geocoding Failed for Address: $address");
        return;
      }

      double latitude = coordinates["latitude"]!;
      double longitude = coordinates["longitude"]!;

      print("✅ Address: $address");
      print("📍 Latitude: $latitude, Longitude: $longitude");

      await firebaseService.saveParcelData(
        address,
        latitude,
        longitude,
      );

      fetchStoredAddresses(); // Refresh UI with updated data

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Parcel Added Successfully!")),
      );
    }
  }

  // ✅ Convert address to latitude and longitude
  Future<Map<String, double>?> getCoordinates(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return {
          "latitude": locations.first.latitude,
          "longitude": locations.first.longitude
        };
      }
    } catch (e) {
      print("❌ Geocoding Error: $e");
    }
    return null;
  }

  // ✅ Delete an address
  Future<void> deleteAddress(String documentId) async {
    await firebaseService.deleteParcel(documentId);
    fetchStoredAddresses(); // Refresh UI
  }

  // ✅ Edit an address
  Future<void> editAddress(String documentId, String currentAddress) async {
    TextEditingController addressController =
        TextEditingController(text: currentAddress);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit Address"),
          content: TextField(
            controller: addressController,
            decoration: InputDecoration(labelText: "New Address"),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                String newAddress = addressController.text.trim();
                if (newAddress.isNotEmpty) {
                  var coordinates = await getCoordinates(newAddress);
                  if (coordinates != null) {
                    await firebaseService.updateParcel(
                      documentId,
                      newAddress,
                      coordinates["latitude"]!,
                      coordinates["longitude"]!,
                    );
                    fetchStoredAddresses();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              "❌ Failed to get location for the new address!")),
                    );
                  }
                }
                Navigator.pop(context);
              },
              child: Text("Save"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Parcel Scanning")),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : addressList.isEmpty
                    ? Center(child: Text("📭 No parcels scanned yet."))
                    : ListView.builder(
                        itemCount: addressList.length,
                        itemBuilder: (context, index) {
                          return Card(
                            elevation: 4,
                            margin: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListTile(
                              leading: Icon(Icons.location_on,
                                  color: Colors.red, size: 30),
                              title: Text(
                                addressList[index]["address"],
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                "📍 Lat: ${addressList[index]["latitude"]}, Lon: ${addressList[index]["longitude"]}",
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[700]),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => editAddress(
                                      addressList[index]["id"],
                                      addressList[index]["address"],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text("Confirm Delete"),
                                          content: Text(
                                              "Are you sure you want to delete this address?"),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                deleteAddress(
                                                    addressList[index]["id"]);
                                                Navigator.pop(context);
                                              },
                                              child: Text("Delete"),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: Text("Cancel"),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),

      // ✅ Bottom Navigation Bar with 3 buttons
      bottomNavigationBar: BottomAppBar(
        color: Colors.blueGrey[50],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 🗺 Optimized Delivery
              IconButton(
                tooltip: "Generate Optimized Delivery",
                icon: Icon(Icons.list_alt, color: Colors.green),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => OptimizedDeliveryScreen()),
                ),
              ),
                            // 📸 Scan
              IconButton(
                tooltip: "Scan Parcel",
                icon: Icon(Icons.camera_alt, color: Colors.deepPurple),
                onPressed: scanParcel,
              ),
              // 📍 View on Map
              IconButton(
                tooltip: "View Map",
                icon: Icon(Icons.map, color: Colors.blue),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MapScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
