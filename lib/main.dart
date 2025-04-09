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
      title: "Smart Route App",
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Color(0xFFF6F6F6),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Smart Dispatch",
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (selectedTabIndex == 0)
            Padding(
              padding: const EdgeInsets.only(right: 20.0, top: 12),
              child: Text(
                "16 PARCELS",
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Toggle Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                for (int i = 0; i < tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(tabs[i]),
                      selected: selectedTabIndex == i,
                      onSelected: (_) => setState(() => selectedTabIndex = i),
                      selectedColor: Colors.black,
                      backgroundColor: Colors.grey[200],
                      labelStyle: TextStyle(
                        color:
                            selectedTabIndex == i ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 12),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child:
                  selectedTabIndex == 0 ? buildDispatchList() : buildNewsList(),
            ),
          ),
        ],
      ),

      // Floating Action Button
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Color.fromARGB(255, 255, 222, 123),
        icon: Icon(Icons.local_shipping), // Or use Icons.play_arrow
        label: Text("Start Dispatch"),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ParcelScanning()),
          );
        },
      ),
    );
  }

  // 📦 Dispatch Summary Tab
  Widget buildDispatchList() {
    return ListView(
      children: [
        ParcelCard(
          title: "Parcel to Kuala Lumpur",
          date: "2 days ago",
          color: Colors.deepPurple[100],
          image: "assets/box_delivery.png",
        ),
        ParcelCard(
          title: "Urgent Delivery to Johor",
          date: "5 days ago",
          color: Colors.green[100],
          image: "assets/express.png",
        ),
      ],
    );
  }

  // 📰 News Tab
  Widget buildNewsList() {
    return ListView(
      children: [
        NewsCard(
          title: "New feature: Auto-Route Optimization",
          date: "April 5, 2025",
          snippet:
              "Dispatchers can now auto-optimize multi-stop routes with Smart Route AI.",
        ),
        NewsCard(
          title: "Smart Route hits 1K daily users!",
          date: "April 2, 2025",
          snippet: "Thanks to our loyal users! Keep scanning and optimizing!",
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
  final String image;

  const ParcelCard({
    super.key,
    required this.title,
    required this.date,
    this.color,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color ?? Colors.grey[200],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Image.asset(image, height: 50, width: 50),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(date),
        trailing: Icon(Icons.more_vert),
      ),
    );
  }
}

// 📰 News Card Widget
class NewsCard extends StatelessWidget {
  final String title;
  final String date;
  final String snippet;

  const NewsCard({
    super.key,
    required this.title,
    required this.date,
    required this.snippet,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            SizedBox(height: 4),
            Text(title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 6),
            Text(snippet, style: TextStyle(color: Colors.grey[800])),
          ],
        ),
      ),
    );
  }
}
