import 'package:flutter/material.dart';

class DeliveryCompleteScreen extends StatelessWidget {
  const DeliveryCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeGreen = Colors.green.shade700;

    return Scaffold(
      backgroundColor: Colors.green[50],
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.celebration_rounded,
                    size: 80, color: themeGreen),
                SizedBox(height: 20),
                Text(
                  "Deliveries Completed!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                    color: themeGreen,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  "All parcels have been successfully delivered and removed from the system.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.blueGrey[700],
                    fontFamily: 'Montserrat',
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 40),
                ElevatedButton.icon(
                  icon: Icon(Icons.home_rounded, size: 20),
                  label: Text(
                    "Back to Home",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeGreen,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
