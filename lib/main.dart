import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'parcel_scanner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Smart Route",
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Color(0xFFF8FAFD),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF2C3E50),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            fontFamily: 'Inter',
          ),
        ),
        textTheme: TextTheme(
          headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C3E50),
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF34495E),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: Color(0xFF7F8C8D),
          ),
        ),
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedTabIndex = 0;
  final tabs = ["Dispatch Summary", "News"];
  bool _isButtonPressed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Smart Dispatch",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2C3E50), // Dark blue-grey color
          ),
        ),
        actions: [
          if (selectedTabIndex == 0)
            Container(
              margin: EdgeInsets.only(right: 20, top: 12),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.indigo[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "16 PARCELS",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo[800],
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Toggle Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
            child: Row(
              children: [
                for (int i = 0; i < tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: ChoiceChip(
                      label: Text(
                        tabs[i],
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: selectedTabIndex == i,
                      onSelected: (_) => setState(() => selectedTabIndex = i),
                      selectedColor: Colors.indigo[600],
                      backgroundColor: Colors.grey[100],
                      labelStyle: TextStyle(
                        color: selectedTabIndex == i
                            ? Colors.white
                            : Colors.grey[800],
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 300),
                child: selectedTabIndex == 0
                    ? buildDispatchList()
                    : buildNewsList(),
              ),
            ),
          ),
        ],
      ),

      // Floating Action Button
      floatingActionButton: GestureDetector(
        onTapDown: (_) => setState(() => _isButtonPressed = true),
        onTapUp: (_) => setState(() => _isButtonPressed = false),
        onTapCancel: () => setState(() => _isButtonPressed = false),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ParcelScanning()),
          );
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 200),
            tween: Tween(begin: 1.0, end: _isButtonPressed ? 0.95 : 1.0),
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Container(
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.indigo[600],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.directions_car,
                            size: 20, color: Colors.white),
                      ),
                      SizedBox(width: 8),
                      Text(
                        "DISPATCH",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // 📦 Dispatch Summary Tab
  Widget buildDispatchList() {
    return ListView(
      physics: BouncingScrollPhysics(),
      children: [
        SizedBox(height: 8),
        ParcelCard(
          title: "Total Distance Covered Today",
          date: "234.5 kilometers",
          color: Colors.blue[50],
          status: "Active",
          statusColor: Colors.blue,
        ),
        ParcelCard(
          title: "Average Delivery Time",
          date: "45 minutes per parcel",
          color: Colors.green[50],
          status: "Good",
          statusColor: Colors.green,
        ),
        ParcelCard(
          title: "Fuel Consumption",
          date: "32.4 liters used today",
          color: Colors.amber[50],
          status: "Normal",
          statusColor: Colors.orange,
        ),
        ParcelCard(
          title: "Successful Deliveries",
          date: "16 out of 16 parcels",
          color: Colors.purple[50],
          status: "100%",
          statusColor: Colors.purple,
        ),
        ParcelCard(
          title: "Carbon Footprint",
          date: "75.2 kg CO₂ emissions",
          color: Colors.teal[50],
          status: "-12%",
          statusColor: Colors.teal,
        ),
      ],
    );
  }

  // 📰 News Tab
  Widget buildNewsList() {
    return ListView(
      physics: BouncingScrollPhysics(),
      children: [
        SizedBox(height: 8),
        NewsCard(
          title: "New Feature: AI Route Optimization",
          date: "April 5, 2025",
          snippet:
              "Our latest update introduces smart AI that automatically optimizes multi-stop routes, saving up to 30% delivery time.",
          icon: Icons.auto_awesome,
          color: Colors.indigo[100],
        ),
        NewsCard(
          title: "Smart Route Reaches 1K Daily Users!",
          date: "April 2, 2025",
          snippet:
              "Thanks to our amazing community of dispatchers and logistics partners for helping us reach this milestone!",
          icon: Icons.celebration,
          color: Colors.amber[100],
        ),
        NewsCard(
          title: "Sustainability Initiative Launched",
          date: "March 28, 2025",
          snippet:
              "Join our green logistics program to reduce carbon emissions through optimized routing.",
          icon: Icons.eco,
          color: Colors.teal[100],
        ),
      ],
    );
  }
}

// 🧾 Parcel Card Widget
class ParcelCard extends StatelessWidget {
  final String title;
  final String date;
  final Color? color;
  final String status;
  final Color statusColor;

  const ParcelCard({
    super.key,
    required this.title,
    required this.date,
    this.color,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color ?? Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    date,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 📰 News Card Widget
class NewsCard extends StatelessWidget {
  final String title;
  final String date;
  final String snippet;
  final IconData icon;
  final Color? color;

  const NewsCard({
    super.key,
    required this.title,
    required this.date,
    required this.snippet,
    this.icon = Icons.article,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 32),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, size: 20, color: Colors.indigo),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        date,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 18,
                      ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                SizedBox(height: 8),
                Text(
                  snippet,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      child: Text(
                        "Read more →",
                        style: TextStyle(
                          color: Colors.indigo,
                          fontWeight: FontWeight.w600,
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
  }
}
