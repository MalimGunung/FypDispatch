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
import 'dart:async'; // <-- Add this import for Timer

class ParcelScanning extends StatefulWidget {
  final String userEmail;
  ParcelScanning({Key? key, required this.userEmail}) : super(key: key);

  @override
  _ParcelScanningState createState() => _ParcelScanningState();
}

class _ParcelScanningState extends State<ParcelScanning> {
  final EnhancedMLKitOCR mlkitOCR = EnhancedMLKitOCR();
  final FirebaseService firebaseService = FirebaseService();
  List<Map<String, dynamic>> addressList = [];
  bool isLoading = false;
  Set<String> selectedItems = {};
  bool selectionMode = false;
  Position? currentPosition;
  List<double?> orsDistances = []; // Store ORS distances for each address
  String searchQuery = '';

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

  // Use two ORS API keys for improved reliability
  static const List<String> _orsApiKeys = [
    '5b3ce3597851110001cf6248014503d6bb042740758494cf91a36816644b5aba3fbc5e56ca3d9bfb',
    '5b3ce3597851110001cf6248dab480f8ea3f4444be33bffab7bd37cb'
  ];

  // Add a static counter for round-robin API key usage
  static int _orsApiKeyIndex = 0;

  // Helper to get the next ORS API key in round-robin fashion
  String _nextORSApiKey() {
    final key = _orsApiKeys[_orsApiKeyIndex % _orsApiKeys.length];
    _orsApiKeyIndex++;
    return key;
  }

  // Remove the old calculateDistance method (Haversine)
  Future<double?> _getORSRoadDistance(
      double lat1, double lon1, double lat2, double lon2) async {
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
    // Sort by scanOrder if present, else fallback to id as timestamp
    storedAddresses.sort((a, b) {
      int orderA = a["scanOrder"] ?? 0;
      int orderB = b["scanOrder"] ?? 0;
      if (orderA != 0 && orderB != 0) {
        return orderA.compareTo(orderB);
      }
      int idA = int.tryParse(a["id"].toString()) ?? 0;
      int idB = int.tryParse(b["id"].toString()) ?? 0;
      return idA.compareTo(idB);
    });
    addressList = List.from(storedAddresses); // keep scan order
    setState(() {
      addressList = addressList;
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
      setState(() => isLoading = true); // Show loader
      final imagePath = pickedFile.path;

      String address = await mlkitOCR.extractTextFromImage(imagePath);

      if (address.isEmpty || address == "No valid address detected") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("❌ No valid address detected. Please try again.")),
        );
        setState(() => isLoading = false); // Hide loader
        return;
      }

      // Show confirmation dialog with editable address
      String? confirmedAddress = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          TextEditingController controller =
              TextEditingController(text: address);
          final formKey = GlobalKey<FormState>();
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0)),
            backgroundColor: Color(0xFFFDFEFE),
            title: Row(
              children: [
                Icon(Icons.markunread_mailbox_outlined,
                    color: Colors.blueAccent.shade700, size: 26),
                SizedBox(width: 12),
                Text(
                  "Confirm Parcel Address",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Colors.blueGrey[800],
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: "Parcel Address",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Address cannot be empty.";
                  }
                  if (value.trim().length < 10) {
                    return "Address seems too short. Please provide more details.";
                  }
                  return null;
                },
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14.5,
                  color: Colors.blueGrey[700],
                  height: 1.4,
                ),
              ),
            ),
            actions: [
              TextButton(
                child: Text(
                  "CANCEL",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[600],
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(null),
              ),
              ElevatedButton(
                child: Text(
                  "CONFIRM",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(context).pop(controller.text.trim());
                  }
                },
              ),
            ],
          );
        },
      );

      if (confirmedAddress == null) {
        setState(() => isLoading = false);
        return;
      }
      address = confirmedAddress;

      // --- Remove label logic: do NOT add "scan one: ..." etc. ---
      // address = "scan $labelWord: $address"; // <-- REMOVE this line

      // Improved duplicate address check
      final normalizedNewAddress = _normalizeAddress(address);
      bool isDuplicate = addressList.any((existingAddress) =>
          _normalizeAddress(existingAddress["address"].toString()) ==
          normalizedNewAddress);

      if (isDuplicate) {
        setState(() => isLoading = false); // Hide loader before showing dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              backgroundColor: Color(0xFFFDFEFE), // Light background
              titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0.0),
              contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
              actionsPadding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 16.0),
              title: Row(
                children: [
                  Icon(
                    Icons.copy_all_outlined, // Changed icon
                    color: Colors.orange.shade600, // Slightly softer orange
                    size: 26,
                  ),
                  SizedBox(width: 12),
                  Text(
                    "Duplicate Parcel", // More concise
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600, // Semi-bold
                      fontSize: 18,
                      color: Colors.blueGrey[800], // Darker for contrast
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min, // Important for content sizing
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "This parcel address already exists in your list:",
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      color: Colors.blueGrey[600], // Softer text color
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Colors.orange.withOpacity(0.05), // Subtle highlight
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.orange.shade100, width: 1),
                    ),
                    child: Text(
                      "\"$address\"",
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        color: Colors.orange.shade800, // Emphasize address
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center, // Center the address
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Please scan a different parcel or check your existing list.",
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      color: Colors.blueGrey[600],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    backgroundColor:
                        Colors.blueAccent.shade700.withOpacity(0.1),
                  ),
                  child: Text(
                    "GOT IT", // More modern CTA
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent.shade700, // Theme color
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
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
        setState(() => isLoading = false); // Hide loader
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

      // Optimistically add the new address at the bottom for instant UI feedback
      setState(() {
        addressList.add({
          "id": DateTime.now().millisecondsSinceEpoch.toString(),
          "address": address,
          "latitude": latitude,
          "longitude": longitude,
        });
        // _sortAddressList(); // <-- REMOVE this line to keep scan order
        isLoading = false;
      });

      // Invalidate optimization cache after adding a parcel
      OptimizedDeliveryScreen.invalidateCache();

      // Fetch from backend to ensure list is accurate and IDs are correct
      await fetchStoredAddresses();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Parcel Added Successfully!")),
      );
      // isLoading is set to false by fetchStoredAddresses
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
    // Invalidate optimization cache after deleting a parcel
    OptimizedDeliveryScreen.invalidateCache();
    await fetchStoredAddresses(); // Refresh UI
  }

  // ✅ Edit an address
  Future<void> editAddress(String documentId, String currentAddress) async {
    TextEditingController addressController =
        TextEditingController(text: currentAddress);
    final formKey = GlobalKey<FormState>();
    List<String> suggestions = [];
    bool isLoadingSuggestions = false;
    int lastRequestId = 0;

    // Debounce mechanism for suggestions
    _DebounceTimer? debounceTimer;

    Future<void> fetchSuggestionsWithDebounce(
        String query, void Function(void Function()) setStateDialog) async {
      debounceTimer?.cancel();
      debounceTimer = _DebounceTimer(Duration(milliseconds: 400), () async {
        final int requestId = ++lastRequestId;
        if (query.trim().length < 3) {
          // Minimum characters to trigger search
          setStateDialog(() {
            suggestions = [];
            isLoadingSuggestions = false;
          });
          return;
        }
        setStateDialog(() {
          isLoadingSuggestions = true;
        });
        try {
          String searchQuery = query;
          if (!searchQuery.toLowerCase().contains('malaysia')) {
            searchQuery = '$searchQuery, Malaysia';
          }
          List<Location> locations = await locationFromAddress(searchQuery);
          List<String> newSuggestions = [];
          if (locations.isNotEmpty) {
            for (var loc in locations.take(5)) {
              // Limit suggestions
              final placemarks =
                  await placemarkFromCoordinates(loc.latitude, loc.longitude);
              if (placemarks.isNotEmpty) {
                final p = placemarks.first;
                if ((p.country ?? '').toLowerCase().contains('malaysia')) {
                  String addr = [
                    if (p.name != null && p.name!.isNotEmpty) p.name,
                    if (p.street != null &&
                        p.street!.isNotEmpty &&
                        p.name != p.street)
                      p.street,
                    if (p.subLocality != null && p.subLocality!.isNotEmpty)
                      p.subLocality,
                    if (p.locality != null && p.locality!.isNotEmpty)
                      p.locality,
                    if (p.postalCode != null && p.postalCode!.isNotEmpty)
                      p.postalCode,
                    if (p.administrativeArea != null &&
                        p.administrativeArea!.isNotEmpty)
                      p.administrativeArea,
                  ]
                      .where((s) => s != null && s.isNotEmpty)
                      .toSet()
                      .toList()
                      .join(', ');
                  if (addr.isNotEmpty && !newSuggestions.contains(addr))
                    newSuggestions.add(addr); // Ensure unique suggestions
                }
              }
            }
          }
          if (requestId == lastRequestId) {
            // Ensure this is the latest request
            setStateDialog(() {
              suggestions = newSuggestions.toSet().toList();
              isLoadingSuggestions = false;
            });
          }
        } catch (e) {
          print("Suggestion fetch error: $e");
          if (requestId == lastRequestId) {
            setStateDialog(() {
              suggestions = [];
              isLoadingSuggestions = false;
            });
          }
        }
      });
    }

    showDialog(
      context: context,
      barrierDismissible: true, // Allow dismissing by tapping outside
      builder: (context) {
        return StatefulBuilder(
          // Use StatefulBuilder for dialog's own state
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16)), // Standardized radius
              elevation: 5,
              backgroundColor: Color(0xFFFDFEFE), // Slightly off-white
              child: SingleChildScrollView(
                // Important for small screens with keyboard
                child: Padding(
                  padding: const EdgeInsets.all(22.0), // Consistent padding
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch, // Stretch buttons
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.shade100.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.edit_location_alt_outlined,
                              color: Colors.blueAccent.shade700, size: 28),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Edit Parcel Address",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18, // Slightly reduced
                            fontFamily: 'Montserrat',
                            color: Colors.blueGrey[800],
                          ),
                        ),
                        SizedBox(height: 20),
                        TextFormField(
                          controller: addressController,
                          minLines: 2,
                          maxLines: 4, // Max 4 lines for consistency
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: "Enter full address details...",
                            labelText: "Full Address",
                            labelStyle: TextStyle(
                                color: Colors.blueGrey[500],
                                fontFamily: 'Montserrat',
                                fontSize: 14),
                            prefixIcon: Icon(Icons.markunread_mailbox_outlined,
                                color: Colors.blueGrey[300], size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: Colors.blueGrey.shade100)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: Colors.blueGrey.shade100)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: Colors.blueAccent.shade400,
                                    width: 1.5)),
                            filled: true,
                            fillColor: Colors.white, // Cleaner fill
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            alignLabelWithHint: true,
                            suffixIcon: isLoadingSuggestions
                                ? Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 1.8,
                                            valueColor: AlwaysStoppedAnimation<
                                                    Color>(
                                                Colors.blueAccent.shade200))),
                                  )
                                : addressController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear, color: const Color.fromARGB(255, 242, 47, 47)),
                                        tooltip: 'Clear',
                                        onPressed: () {
                                          setStateDialog(() {
                                            addressController.clear();
                                            suggestions = [];
                                          });
                                        },
                                      )
                                    : null,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Address cannot be empty.";
                            }
                            if (value.trim().length < 10) {
                              return "Address seems too short. Please provide more details.";
                            }
                            return null;
                          },
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 14.5, // Adjusted
                            color: Colors.blueGrey[700],
                            height: 1.4, // Line height
                          ),
                          onChanged: (value) {
                            fetchSuggestionsWithDebounce(value, setStateDialog);
                          },
                        ),
                        if (suggestions.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(
                                top: 8, bottom: 8), // Adjusted margin
                            constraints: BoxConstraints(
                                maxHeight: 120), // Adjusted height
                            decoration: BoxDecoration(
                                color: Colors.grey
                                    .shade50, // Lighter background for suggestions
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.blueGrey.shade100
                                        .withOpacity(0.7))),
                            child: ListView.separated(
                              // Added separator
                              shrinkWrap: true,
                              itemCount: suggestions.length,
                              separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  color: Colors.blueGrey.shade100
                                      .withOpacity(0.5)),
                              itemBuilder: (context, idx) {
                                return InkWell(
                                  borderRadius: BorderRadius.circular(
                                      6), // Match inner radius
                                  onTap: () {
                                    setStateDialog(() {
                                      addressController.text = suggestions[idx];
                                      addressController.selection =
                                          TextSelection.fromPosition(
                                              TextPosition(
                                                  offset: addressController
                                                      .text.length));
                                      suggestions =
                                          []; // Clear suggestions after selection
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0,
                                        vertical: 9.0), // Adjusted padding
                                    child: Text(
                                      suggestions[idx],
                                      style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 13,
                                          color: Colors
                                              .blueGrey[700]), // Adjusted style
                                      maxLines:
                                          1, // Ensure single line for cleaner look
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        SizedBox(height: 24), // Increased spacing
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                child: Text("CANCEL",
                                    style: TextStyle(
                                        color: Colors.blueGrey[600],
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Montserrat',
                                        fontSize: 13.5)),
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                          color: Colors.blueGrey.shade200)),
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 12), // Increased spacing
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.save_alt_rounded, size: 16),
                                label: Text("SAVE",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Montserrat',
                                        fontSize: 13.5,
                                        letterSpacing: 0.5)),
                                onPressed: () async {
                                  if (formKey.currentState!.validate()) {
                                    String newAddress =
                                        addressController.text.trim();
                                    // Show loading indicator
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (BuildContext context) {
                                        return Dialog(
                                          backgroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 20, horizontal: 24),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircularProgressIndicator(
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                                Color>(
                                                            Colors.blueAccent
                                                                .shade700)),
                                                SizedBox(width: 24),
                                                Text("Updating Address...",
                                                    style: TextStyle(
                                                        fontFamily:
                                                            'Montserrat',
                                                        fontSize: 15,
                                                        color: Colors
                                                            .blueGrey[700])),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );

                                    var coordinates =
                                        await getCoordinates(newAddress);
                                    Navigator.pop(
                                        context); // Dismiss loading indicator

                                    if (coordinates != null) {
                                      await firebaseService.updateParcel(
                                        widget.userEmail,
                                        documentId,
                                        newAddress,
                                        coordinates["latitude"]!,
                                        coordinates["longitude"]!,
                                      );
                                      // Invalidate optimization cache after editing a parcel
                                      OptimizedDeliveryScreen.invalidateCache();
                                      await fetchStoredAddresses(); // Refresh list and distances
                                      Navigator.pop(
                                          context); // Dismiss edit dialog
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                "✅ Address updated successfully!")),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text(
                                            "❌ Could not find location for the new address. Please verify and try again."),
                                        duration: Duration(seconds: 3),
                                      ));
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent.shade700,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                      vertical: 12), // Consistent padding
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          8)), // Consistent radius
                                  elevation: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Utility to normalize address for duplicate checking
  String _normalizeAddress(String address) {
    return address
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Collapse whitespace
        .trim()
        .toLowerCase();
  }

  Future<void> markDeliveriesComplete() async {
    if (selectedItems.isEmpty) return;

    try {
      // Set delivery status as complete for all selected parcels
      for (final id in selectedItems) {
        await firebaseService.updateDeliveryStatus(
            widget.userEmail, id, "complete");
      }

      // Update status and move to history
      await firebaseService.moveToHistory(
          widget.userEmail, selectedItems.toList());

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
    final bodyGradient = BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color(0xFFF3F5F9),
          Color(0xFFE8EFF5)
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );

    // Filtered list for search
    final filteredList = searchQuery.isEmpty
        ? addressList
        : addressList.where((item) => item["address"].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: selectionMode
            ? IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    selectionMode = false;
                    selectedItems.clear();
                  });
                },
              )
            : IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
        title: selectionMode
            ? Row(
                children: [
                  Text(
                    "${selectedItems.length} Selected",
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.select_all_rounded, color: Colors.white),
                    tooltip: selectedItems.length == addressList.length && addressList.isNotEmpty ? 'Deselect All' : 'Select All',
                    onPressed: () {
                      setState(() {
                        if (selectedItems.length == addressList.length && addressList.isNotEmpty) {
                          selectedItems.clear();
                        } else {
                          selectedItems = addressList.map((item) => item["id"].toString()).toSet();
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.done_all_sharp, color: Colors.white),
                    tooltip: 'Mark as Complete',
                    onPressed: selectedItems.isNotEmpty ? () { markDeliveriesComplete(); } : null,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_forever_outlined, color: Colors.white),
                    tooltip: 'Delete',
                    onPressed: selectedItems.isNotEmpty ? () async {
                      bool? confirmDelete = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text("Confirm Deletion", style: TextStyle(fontFamily: 'Montserrat', color: Colors.blueGrey[800])),
                            content: Text("Delete {selectedItems.length} selected parcel(s)? This cannot be undone.", style: TextStyle(fontFamily: 'Montserrat', color: Colors.blueGrey[600])),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            actions: <Widget>[
                              TextButton(
                                child: Text("CANCEL", style: TextStyle(fontFamily: 'Montserrat', color: Colors.blueGrey[500], fontWeight: FontWeight.w600)),
                                onPressed: () => Navigator.of(context).pop(false),
                              ),
                              TextButton(
                                child: Text("DELETE", style: TextStyle(fontFamily: 'Montserrat', color: Colors.red.shade600, fontWeight: FontWeight.w600)),
                                onPressed: () => Navigator.of(context).pop(true),
                              ),
                            ],
                          );
                        },
                      );
                      if (confirmDelete == true) {
                        for (var id in selectedItems) {
                          await firebaseService.deleteParcel(widget.userEmail, id);
                        }
                        OptimizedDeliveryScreen.invalidateCache();
                        setState(() {
                          selectedItems.clear();
                          selectionMode = false;
                        });
                        fetchStoredAddresses();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("✅ ${selectedItems.length} parcel(s) deleted.")),
                        );
                      }
                    } : null,
                  ),
                ],
              )
            : TextField(
                onChanged: (val) => setState(() => searchQuery = val),
                style: TextStyle(color: Colors.white, fontFamily: 'Montserrat', fontSize: 18, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Search parcels...',
                  hintStyle: TextStyle(color: Colors.white70, fontFamily: 'Montserrat'),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.white70),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.white),
                          onPressed: () => setState(() => searchQuery = ''),
                        )
                      : null,
                ),
              ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [themeBlue, Colors.blueAccent.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [],
      ),
      body: Container(
        decoration: bodyGradient,
        child: isLoading && addressList.isEmpty
            ? Center(
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(themeBlue),
                      strokeWidth: 3),
                  SizedBox(height: 22),
                  Text("Fetching Parcels...",
                      style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 15,
                          color: Colors.blueGrey[500])),
                ],
              ))
            : filteredList.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(35.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Placeholder for engaging illustration
                          Icon(Icons.local_shipping, size: 80, color: Colors.blueAccent.shade100),
                          SizedBox(height: 22),
                          Text(
                            "No Parcels Found",
                            style: TextStyle(
                              fontSize: 19,
                              color: Colors.blueGrey[600],
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            "Use the '+' button to scan and add new delivery items to your list.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.blueGrey[400],
                                fontFamily: 'Montserrat',
                                height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: fetchStoredAddresses,
                    color: themeBlue,
                    backgroundColor: Colors.white,
                    strokeWidth: 2.5,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 85),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final item = filteredList[index];
                        final id = item["id"].toString();
                        final selected = selectedItems.contains(id);
                        double? distance = (orsDistances.length > index) ? orsDistances[index] : null;
                        return Dismissible(
                          key: Key(id),
                          background: Container(
                            alignment: Alignment.centerLeft,
                            color: Colors.red.shade100,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 20.0),
                              child: Icon(Icons.delete, color: Colors.red.shade700),
                            ),
                          ),
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            color: Colors.blueAccent.shade100,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 20.0),
                              child: Icon(Icons.edit, color: Colors.blueAccent.shade700),
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              // Delete
                              bool? confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Delete Parcel?', style: TextStyle(fontFamily: 'Montserrat')),
                                  content: Text('Are you sure you want to delete this parcel?', style: TextStyle(fontFamily: 'Montserrat')),
                                  actions: [
                                    TextButton(child: Text('Cancel'), onPressed: () => Navigator.pop(context, false)),
                                    TextButton(child: Text('Delete', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.pop(context, true)),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await deleteAddress(id);
                                return true;
                              }
                              return false;
                            } else {
                              // Edit
                              editAddress(item["id"], item["address"]);
                              return false;
                            }
                          },
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: Card(
                              elevation: selected ? 4 : 1.5,
                              margin: EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: selected
                                    ? BorderSide(color: themeBlue.withOpacity(0.7), width: 1.5)
                                    : BorderSide(color: Colors.grey.shade200, width: 0.8),
                              ),
                              color: selected ? themeBlue.withOpacity(0.04) : Colors.white,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onLongPress: () {
                                  setState(() {
                                    selectionMode = true;
                                    if (selected) {
                                      selectedItems.remove(id);
                                      if (selectedItems.isEmpty) selectionMode = false;
                                    } else {
                                      selectedItems.add(id);
                                    }
                                  });
                                  // Haptic feedback
                                  Feedback.forLongPress(context);
                                },
                                onTap: () {
                                  if (selectionMode) {
                                    setState(() {
                                      if (selected) {
                                        selectedItems.remove(id);
                                        if (selectedItems.isEmpty) selectionMode = false;
                                      } else {
                                        selectedItems.add(id);
                                      }
                                    });
                                    Feedback.forTap(context);
                                  } else {
                                    editAddress(item["id"], item["address"]);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    leading: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: selected ? themeBlue.withOpacity(0.1) : Colors.grey.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        selected ? Icons.check_circle_outline : Icons.local_shipping_outlined,
                                        color: selected ? themeBlue : Colors.blueGrey[400],
                                        size: 26,
                                      ),
                                    ),
                                    title: Text(
                                      item["address"],
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                        color: Colors.blueGrey[700],
                                        fontFamily: 'Montserrat',
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 5.0),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: distance != null ? Colors.deepPurple.shade50 : Colors.blueGrey.shade50,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.near_me_outlined, size: 15, color: distance != null ? Colors.deepPurple.shade300 : Colors.blueGrey[300]),
                                                SizedBox(width: 5),
                                                Text(
                                                  distance != null ? "${distance.toStringAsFixed(1)} km away" : "Calculating...",
                                                  style: TextStyle(
                                                    color: distance != null ? Colors.deepPurple.shade300 : Colors.blueGrey[300],
                                                    fontSize: 14.5,
                                                    fontFamily: 'Montserrat',
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: selectionMode
                                        ? AbsorbPointer(
                                            child: Checkbox(
                                              value: selected,
                                              activeColor: themeBlue,
                                              onChanged: (bool? value) {},
                                              visualDensity: VisualDensity.compact,
                                              side: BorderSide(color: Colors.blueGrey.shade200, width: 1),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                                            ),
                                          )
                                        : Icon(Icons.chevron_right_rounded, color: Colors.blueGrey[200], size: 20),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: scanParcel,
        backgroundColor: themeBlue,
        child: Icon(Icons.add, color: Colors.white),
        tooltip: 'Scan Parcel',
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 10,
        color: Colors.blueAccent.shade700,
        shape: CircularNotchedRectangle(),
        notchMargin: 5.0,
        child: Container(
          height: 58,
          padding: EdgeInsets.symmetric(horizontal: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildBottomNavItem(Icons.ballot_outlined, "Optimize", 0, themeBlue),
              _buildBottomNavItem(Icons.explore_outlined, "View Route", 2, themeBlue),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }

  Widget _buildBottomNavItem(
      IconData icon, String label, int index, Color themeColor) {
    // This is a placeholder for active state, actual logic would depend on how navigation is managed
    // For now, it's always inactive as navigation pushes new screens.

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isLoading && index != 1)
              return; // Allow scan even if loading other things

            switch (index) {
              case 0:
                if (addressList.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text("Scan parcels before optimizing a route.")),
                  );
                  return;
                }
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => OptimizedDeliveryScreen(
                            userEmail: widget.userEmail)));
                break;
              case 1:
                scanParcel();
                break;
              case 2:
                if (addressList.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            "No parcels to show on map. Scan some first.")),
                  );
                  return;
                }
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            MapScreen(userEmail: widget.userEmail)));
                break;
            }
          },
          borderRadius: BorderRadius.circular(8), // For InkWell splash
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon,
                  color: Colors.white, // isActive is always false
                  size: 20), // Adjusted size and inactive color
              SizedBox(height: 3), // Reduced spacing
              Text(
                label,
                style: TextStyle(
                  color: Colors.white, // isActive is always false
                  fontSize: 10, // Smaller font for concise look
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.normal, // isActive is always false
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper class for debouncing text input
class _DebounceTimer {
  _DebounceTimer(this.delay, this.callback);
  final Duration delay;
  final VoidCallback callback;
  Timer? _timer;
  void cancel() => _timer?.cancel();
}