import 'package:flutter/material.dart';

class DeliveryListScreen extends StatelessWidget {
  final List<Map<String, dynamic>> addressList;

  // Constructor to accept scanned addresses
  DeliveryListScreen({required this.addressList});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Optimized Delivery List")),
      body: addressList.isEmpty
          ? Center(child: Text("No addresses added yet!"))
          : ListView.builder(
              itemCount: addressList.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Icon(Icons.location_pin),
                  title: Text(addressList[index]["address"]),
                  subtitle: Text(
                      "Lat: ${addressList[index]["latitude"]}, Lon: ${addressList[index]["longitude"]}"),
                );
              },
            ),
    );
  }
}
