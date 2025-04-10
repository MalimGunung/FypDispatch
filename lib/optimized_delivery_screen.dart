import 'package:flutter/material.dart';
import 'astar_algorithm.dart';
import 'map_screen.dart';

class OptimizedDeliveryScreen extends StatefulWidget {
  @override
  _OptimizedDeliveryScreenState createState() => _OptimizedDeliveryScreenState();
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Optimized Delivery Route",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black87),
      ),
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
                            margin: EdgeInsets.symmetric(
                                horizontal: 15, vertical: 10),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                delivery["address"],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                "📍 Lat: ${delivery["latitude"]}, Lon: ${delivery["longitude"]}",
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[700]),
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
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
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.2),
                    blurRadius: 10,
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
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 24),
                    SizedBox(width: 12),
                    Text(
                      "VIEW ON MAP",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}