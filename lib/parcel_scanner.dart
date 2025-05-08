import 'package:flutter/material.dart';
import 'firebase_service.dart';
import 'mlkit_ocr.dart';
import 'package:geocoding/geocoding.dart';
import 'optimized_delivery_screen.dart';
import 'map_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart'; // <-- Add this import
import 'dart:convert';
import 'package:http/http.dart' as http;

class ParcelScanning extends StatefulWidget {
  final String userEmail;
  ParcelScanning({Key? key, required this.userEmail}) : super(key: key);

  @override
  _ParcelScanningState createState() => _ParcelScanningState();
}

class _ParcelScanningState extends State<ParcelScanning> {
  final MLKitOCR mlkitOCR = MLKitOCR();
  final FirebaseService firebaseService = FirebaseService();
  List<Map<String, dynamic>> addressList = [];
  bool isLoading = false;
  Set<String> selectedItems = {};
  bool selectionMode = false;
  Position? currentPosition;
  List<double?> orsDistances = []; // Store ORS distances for each address

  @override
  void initState() {
    super.initState();
    fetchStoredAddresses();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      currentPosition = await Geolocator.getCurrentPosition();
      setState(() {});
      // After getting location, update distances if addresses are loaded
      if (addressList.isNotEmpty) {
        await _updateORSDistances();
      }
    } catch (e) {
      print("❌ Error getting current location: $e");
    }
  }

  // Remove the old calculateDistance method (Haversine)
  Future<double?> _getORSRoadDistance(double lat1, double lon1, double lat2, double lon2) async {
    const String _orsApiKey = '5b3ce3597851110001cf6248c4f4ec157fda4aa7a289bd1c8e4ef93f';
    final url =
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$_orsApiKey&start=$lon1,$lat1&end=$lon2,$lat2';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final distanceMeters = data['features'][0]['properties']['segments'][0]['distance'];
        return distanceMeters / 1000.0; // return in KM
      } else {
        print("❌ ORS API Error: ${response.body}");
      }
    } catch (e) {
      print("❌ ORS Request Error: $e");
    }
    return null;
  }

  Future<void> _updateORSDistances() async {
    if (currentPosition == null || addressList.isEmpty) {
      setState(() {
        orsDistances = List.filled(addressList.length, null);
      });
      return;
    }
    List<double?> distances = [];
    for (final address in addressList) {
      double? dist = await _getORSRoadDistance(
        currentPosition!.latitude,
        currentPosition!.longitude,
        address["latitude"],
        address["longitude"],
      );
      distances.add(dist);
    }
    setState(() {
      orsDistances = distances;
    });
  }

  // ✅ Fetch stored addresses from Firebase
  Future<void> fetchStoredAddresses() async {
    setState(() => isLoading = true);
    List<Map<String, dynamic>> storedAddresses =
        await firebaseService.getStoredAddresses(widget.userEmail);
    setState(() {
      addressList = storedAddresses;
      isLoading = false;
    });
    // After fetching addresses, update ORS distances if location is available
    if (currentPosition != null && addressList.isNotEmpty) {
      await _updateORSDistances();
    }
  }

  // ✅ Capture and scan an address from an image
Future<void> scanParcel() async {
  final ImagePicker _picker = ImagePicker();
  final pickedFile = await _picker.pickImage(source: ImageSource.camera);

  if (pickedFile != null) {
    final imagePath = pickedFile.path;

    String address = await mlkitOCR.extractTextFromImage(imagePath);

    if (address.isEmpty || address == "No valid address detected") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ No valid address detected. Please try again.")),
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
      widget.userEmail,
      address,
      latitude,
      longitude,
    );

    fetchStoredAddresses(); // Refresh UI

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
    await firebaseService.deleteParcel(widget.userEmail, documentId);
    fetchStoredAddresses(); // Refresh UI
  }

  // ✅ Edit an address
  Future<void> editAddress(String documentId, String currentAddress) async {
    TextEditingController addressController =
        TextEditingController(text: currentAddress);
    final formKey = GlobalKey<FormState>();
    List<String> suggestions = [];
    bool isLoadingSuggestions = false;
    int lastRequestId = 0;

    Future<void> fetchSuggestions(String query, void Function(void Function()) setState) async {
      final int requestId = ++lastRequestId;
      if (query.trim().isEmpty) {
        setState(() {
          suggestions = [];
          isLoadingSuggestions = false;
        });
        return;
      }
      setState(() {
        isLoadingSuggestions = true;
      });
      try {
        // Focus autocomplete on Malaysia by appending ', Malaysia' if not present
        String searchQuery = query;
        if (!searchQuery.toLowerCase().contains('malaysia')) {
          searchQuery = '$searchQuery, Malaysia';
        }
        List<Location> locations = await locationFromAddress(searchQuery);
        List<String> newSuggestions = [];
        for (var loc in locations) {
          final placemarks = await placemarkFromCoordinates(loc.latitude, loc.longitude);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            // Only include suggestions in Malaysia
            if ((p.country ?? '').toLowerCase().contains('malaysia')) {
              String addr = [
                if (p.street != null && p.street!.isNotEmpty) p.street,
                if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality,
                if (p.locality != null && p.locality!.isNotEmpty) p.locality,
                if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) p.administrativeArea,
                if (p.country != null && p.country!.isNotEmpty) p.country,
              ].whereType<String>().join(', ');
              if (addr.isNotEmpty) newSuggestions.add(addr);
            }
          }
        }
        // Only update if this is the latest request
        if (requestId == lastRequestId) {
          setState(() {
            suggestions = newSuggestions.toSet().toList();
            isLoadingSuggestions = false;
          });
        }
      } catch (_) {
        if (requestId == lastRequestId) {
          setState(() {
            suggestions = [];
            isLoadingSuggestions = false;
          });
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_location_alt, color: Colors.blueAccent.shade700, size: 38),
                      SizedBox(height: 10),
                      Text(
                        "Edit Address",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          fontFamily: 'Montserrat',
                          color: Colors.blueAccent.shade700,
                        ),
                      ),
                      SizedBox(height: 18),
                      Stack(
                        children: [
                          TextFormField(
                            controller: addressController,
                            maxLines: 5, // Increased to 5 lines
                            decoration: InputDecoration(
                              labelText: "New Address",
                              prefixIcon: Padding(
                                padding: EdgeInsets.only(bottom: 80), // Increased padding
                                child: Icon(Icons.location_on_outlined),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.blueGrey[50],
                              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 25), // Increased padding
                              alignLabelWithHint: true,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Address cannot be empty";
                              }
                              return null;
                            },
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 18, // Increased font size
                              height: 1.6, // Increased line height
                            ),
                            onChanged: (value) {
                              fetchSuggestions(value, setState);
                            },
                          ),
                          if (isLoadingSuggestions)
                            Positioned(
                              right: 10,
                              top: 12,
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                        ],
                      ),
                      if (suggestions.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(top: 4),
                          constraints: BoxConstraints(maxHeight: 120),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.blueGrey.shade100),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: suggestions.length,
                            itemBuilder: (context, idx) {
                              return ListTile(
                                dense: true,
                                title: Text(
                                  suggestions[idx],
                                  style: TextStyle(fontFamily: 'Montserrat'),
                                ),
                                onTap: () {
                                  setState(() {
                                    addressController.text = suggestions[idx];
                                    suggestions = [];
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: Icon(Icons.save, color: Colors.green),
                            label: Text("Save", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                String newAddress = addressController.text.trim();
                                var coordinates = await getCoordinates(newAddress);
                                if (coordinates != null) {
                                  await firebaseService.updateParcel(
                                    widget.userEmail,
                                    documentId,
                                    newAddress,
                                    coordinates["latitude"]!,
                                    coordinates["longitude"]!,
                                  );
                                  fetchStoredAddresses();
                                  Navigator.pop(context);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            "❌ Failed to get location for the new address!")),
                                  );
                                }
                              }
                            },
                          ),
                          SizedBox(width: 8),
                          TextButton.icon(
                            icon: Icon(Icons.cancel, color: Colors.redAccent),
                            label: Text("Cancel", style: TextStyle(color: Colors.redAccent)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> markDeliveriesComplete() async {
    if (selectedItems.isEmpty) return;

    try {
      // Set delivery status as complete for all selected parcels
      for (final id in selectedItems) {
        await firebaseService.updateDeliveryStatus(widget.userEmail, id, "complete");
      }

      // Update status and move to history
      await firebaseService.moveToHistory(widget.userEmail, selectedItems.toList());

      // Clear selection and refresh list
      setState(() {
        selectedItems.clear();
        selectionMode = false;
      });
      
      fetchStoredAddresses();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Deliveries marked as completed")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error marking deliveries as complete: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeBlue = Colors.blueAccent.shade700;
    final gradientBg = BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFe0eafc), Color(0xFFcfdef3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.85),
        elevation: 2,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: const Color.fromARGB(255, 7, 7, 7)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Scan & Manage Parcels",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: themeBlue,
            fontFamily: 'Montserrat',
            letterSpacing: 1.1,
          ),
        ),
        iconTheme: IconThemeData(color: themeBlue),
        actions: selectionMode
            ? [
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: themeBlue),
                  tooltip: "Actions",
                  onSelected: (value) async {
                    switch (value) {
                      case 'select_all':
                        setState(() {
                          selectedItems = addressList
                              .map((item) => item["id"].toString())
                              .toSet();
                        });
                        break;
                      case 'deselect_all':
                        setState(() {
                          selectedItems.clear();
                        });
                        break;
                      case 'delete':
                        for (var id in selectedItems) {
                          await firebaseService.deleteParcel(widget.userEmail, id);
                        }
                        setState(() {
                          selectedItems.clear();
                          selectionMode = false;
                        });
                        fetchStoredAddresses();
                        break;
                      case 'mark_complete':
                        await markDeliveriesComplete();
                        break;
                      case 'cancel':
                        setState(() {
                          selectionMode = false;
                          selectedItems.clear();
                        });
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: selectedItems.length < addressList.length ? 'select_all' : 'deselect_all',
                      child: Row(
                        children: [
                          Icon(
                            selectedItems.length < addressList.length
                                ? Icons.select_all
                                : Icons.deselect,
                            color: Colors.green,
                          ),
                          SizedBox(width: 8),
                          Text(selectedItems.length < addressList.length ? "Select All" : "Deselect All"),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text("Delete Selected"),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'mark_complete',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text("Mark as Complete"),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'cancel',
                      child: Row(
                        children: [
                          Icon(Icons.cancel, color: themeBlue),
                          SizedBox(width: 8),
                          Text("Cancel Selection"),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : [],
      ),
      body: Container(
        decoration: gradientBg,
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : addressList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_rounded, size: 64, color: themeBlue.withOpacity(0.25)),
                        SizedBox(height: 18),
                        Text(
                          "📭 No parcels scanned yet.",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.blueGrey[700],
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                    child: ListView.builder(
                      itemCount: addressList.length,
                      itemBuilder: (context, index) {
                        final id = addressList[index]["id"].toString();
                        final selected = selectedItems.contains(id);

                        double? distance = (orsDistances.length > index) ? orsDistances[index] : null;

                        return Dismissible(
                          key: Key(id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            return await showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text("Confirm Delete"),
                                  content: Text("Are you sure you want to delete this address?"),
                                  actions: [
                                    TextButton(
                                      child: Text("Cancel"),
                                      onPressed: () => Navigator.of(context).pop(false),
                                    ),
                                    TextButton(
                                      child: Text("Delete", style: TextStyle(color: Colors.red)),
                                      onPressed: () => Navigator.of(context).pop(true),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          onDismissed: (direction) {
                            deleteAddress(id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Address deleted")),
                            );
                          },
                          background: Container(
                            color: Colors.red,
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            alignment: AlignmentDirectional.centerEnd,
                            child: Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          child: GestureDetector(
                            onLongPress: () {
                              setState(() {
                                selectionMode = true;
                                selectedItems.add(id);
                              });
                            },
                            onTap: () {
                              if (selectionMode) {
                                setState(() {
                                  if (selected) {
                                    selectedItems.remove(id);
                                  } else {
                                    selectedItems.add(id);
                                  }
                                });
                              } else {
                                editAddress(
                                  addressList[index]["id"],
                                  addressList[index]["address"],
                                );
                              }
                            },
                            child: Card(
                              elevation: selected ? 10 : 5,
                              shadowColor: themeBlue.withOpacity(0.13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              color: selected
                                  ? themeBlue.withOpacity(0.10)
                                  : Colors.white.withOpacity(0.97),
                              margin: EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: themeBlue.withOpacity(0.13),
                                  child: Icon(Icons.location_on, color: themeBlue),
                                ),
                                title: Text(
                                  addressList[index]["address"],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                    color: themeBlue,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: distance != null
                                      ? Text(
                                          "📏 Distance: ${distance.toStringAsFixed(2)} km",
                                          style: TextStyle(
                                            color: Colors.deepPurple,
                                            fontSize: 14,
                                            fontFamily: 'Montserrat',
                                          ),
                                        )
                                      : Text(
                                          "Distance: --",
                                          style: TextStyle(
                                            color: Colors.blueGrey[700],
                                            fontSize: 14,
                                            fontFamily: 'Montserrat',
                                          ),
                                        ),
                                ),
                                trailing: selectionMode
                                    ? Checkbox(
                                        value: selected,
                                        activeColor: themeBlue,
                                        onChanged: (value) {
                                          setState(() {
                                            if (value!) {
                                              selectedItems.add(id);
                                            } else {
                                              selectedItems.remove(id);
                                            }
                                          });
                                        },
                                      )
                                    : null, // Removed edit and delete buttons
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          boxShadow: [
            BoxShadow(
              color: themeBlue.withOpacity(0.08),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          selectedItemColor: themeBlue,
          unselectedItemColor: Colors.blueGrey[400],
          selectedLabelStyle: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
          unselectedLabelStyle: TextStyle(fontFamily: 'Montserrat'),
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt),
              label: "Delivery List",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt),
              label: "Scan",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map),
              label: "Map View",
            ),
          ],
          onTap: (index) {
            switch (index) {
              case 0:
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => OptimizedDeliveryScreen(userEmail: widget.userEmail)));
                break;
              case 1:
                scanParcel();
                break;
              case 2:
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => MapScreen(userEmail: widget.userEmail)));
                break;
            }
          },
        ),
      ),
    );
  }
}

