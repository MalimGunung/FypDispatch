import 'package:flutter/material.dart';
import 'astar_algorithm.dart';
import 'map_screen.dart';

class OptimizedDeliveryScreen extends StatefulWidget {
  @override
  _OptimizedDeliveryScreenState createState() =>
      _OptimizedDeliveryScreenState();
}

class _OptimizedDeliveryScreenState extends State<OptimizedDeliveryScreen> {
  List<Map<String, dynamic>> deliveryList = [];
  bool isLoading = true;
  final AStarRouteOptimizer optimizer = AStarRouteOptimizer();

  @override
  void initState() {
    super.initState();
    fetchDeliveryList();
  }

  Future<void> fetchDeliveryList() async {
    try {
      List<Map<String, dynamic>> route =
          await optimizer.getOptimizedDeliverySequence();
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

  @override
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: Text("Optimized Delivery Route")),
    body: Column(
      children: [
        Expanded(
          child: isLoading
              ? Center(child: CircularProgressIndicator())
              : deliveryList.isEmpty
                  ? Center(
                      child: Text(
                        "❌ No deliveries found!\nCheck if addresses are scanned and stored properly.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.red),
                      ),
                    )
                  : ListView.builder(
                      itemCount: deliveryList.length,
                      itemBuilder: (context, index) {
                        final delivery = deliveryList[index];
                        return Card(
                          margin: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Icon(Icons.location_pin, color: Colors.red, size: 30),
                            title: Text(
                              "${index + 1}. ${delivery["address"]}",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "📍 Lat: ${delivery["latitude"]}, Lon: ${delivery["longitude"]}",
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // ✅ Navigate to MapScreen directly
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MapScreen()),
                );
              },
              icon: Icon(Icons.map),
              label: Text("View on Map"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 14),
                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}
