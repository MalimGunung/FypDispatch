import 'package:flutter/material.dart';
import 'greedy_algorithm.dart';
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
          "Optimized Delivery Route",
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
              SizedBox(height: kToolbarHeight + 32), // Increased from +8 to +32
              // Decorative/Instruction Container
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
                                    subtitle: Text(
                                      "📍 Lat: ${delivery["latitude"]}, Lon: ${delivery["longitude"]}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.blueGrey[700],
                                        fontFamily: 'Montserrat',
                                      ),
                                    ),
                                    trailing: Icon(
                                      Icons.chevron_right,
                                      color: Colors.blueAccent.shade200,
                                    ),
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