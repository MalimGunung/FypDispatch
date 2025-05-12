import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'parcel_scanner.dart';
import 'login_page.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- Add this import
import 'firebase_service.dart'; // <-- Add this import

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
      ),
      home: AuthGate(), // ✅ Add AuthGate to handle login state
    );
  }
}

class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasData) {
          return HomeScreen(); // ✅ Logged in
        } else {
          return LoginPage(); // ❌ Not logged in
        }
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService firebaseService = FirebaseService();
  Map<String, dynamic>? routeSummary;
  List<Map<String, dynamic>> allRoutes = []; // Store all delivery summaries
  String selectedFilter = "All"; // Default filter
  bool isAscending = true; // Sorting order

  @override
  void initState() {
    super.initState();
    fetchRouteSummary();
    fetchAllRoutes();
  }

  Future<void> fetchRouteSummary() async {
    try {
      final summary = await firebaseService.getRouteSummary(FirebaseAuth.instance.currentUser?.email);
      setState(() {
        routeSummary = summary;
      });
    } catch (e) {
      print("❌ Error fetching route summary: $e");
    }
  }

  Future<void> fetchAllRoutes() async {
    try {
      final routes = await firebaseService.getAllRoutes(FirebaseAuth.instance.currentUser?.email);
      setState(() {
        allRoutes = routes;
      });
    } catch (e) {
      print("❌ Error fetching all routes: $e");
    }
  }

  int selectedTabIndex = 0;
  final tabs = ["Dispatch Summary", "News"];
  bool _isButtonPressed = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoURL = user?.photoURL;

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
          if (user != null) // Ensure user is not null before showing PopupMenuButton
            Padding(
              padding: const EdgeInsets.only(right: 16.0, top: 6.0, bottom: 6.0), // Increased right padding
              child: PopupMenuButton<String>(
                offset: const Offset(0, 50), // Slightly increased offset
                elevation: 3.0, // Add a subtle shadow
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0), // Softer corners
                ),
                tooltip: "Account options",
                onSelected: (value) async {
                  if (value == 'logout') {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                      (route) => false,
                    );
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                  enabled: false,
                  padding: EdgeInsets.zero,
                  child: Container(
                    // width: 250, // Removed to allow gradient to fill item width
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                    decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo.shade400, Colors.blue.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    ),
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: 4), // Reduced top space
                      CircleAvatar(
                      radius: 34, // Slightly increased radius for prominence
                      backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
                      backgroundColor: photoURL == null ? Colors.white.withOpacity(0.25) : Colors.transparent,
                      child: photoURL == null ? Icon(Icons.person_outline, size: 34, color: Colors.white) : null,
                      ),
                      SizedBox(height: 14), // Adjusted spacing
                      if (user.displayName != null && user.displayName!.isNotEmpty)
                      Text(
                        user.displayName!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18, // Slightly increased font size
                        color: Colors.white,
                        ),
                      ),
                      SizedBox(height: user.displayName != null && user.displayName!.isNotEmpty ? 6 : 0), // Conditional spacing
                      if (user.email != null)
                      Text(
                        user.email!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9), // Slightly more opaque
                        ),
                      ),
                      SizedBox(height: 10), // Reduced bottom space
                    ],
                    ),
                  ),
                  ),
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem<String>(
                  value: 'logout',
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0), // Adjusted padding
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                    Icon(Icons.exit_to_app_rounded, color: Colors.red[600], size: 22), // Slightly adjusted color for consistency
                    SizedBox(width: 14), // Adjusted spacing
                    Text(
                      'Logout',
                      style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      ),
                    ),
                    ],
                  ),
                  ),
                ],
                child: CircleAvatar( // This is the button child in AppBar
                  backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
                  backgroundColor: photoURL == null ? Colors.grey[200] : null,
                  child: photoURL == null ? Icon(Icons.person, color: Colors.indigo[600], size: 20) : null,
                  radius: 20, // Slightly larger avatar in AppBar
                ),
              ),
            )
          else // Fallback if user is somehow null, though AuthGate should prevent this
            IconButton(
              icon: Icon(Icons.login, color: Colors.indigo[700]),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                  (route) => false,
                );
              },
              tooltip: 'Login',
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
          final userEmail = FirebaseAuth.instance.currentUser?.email;
          if (userEmail != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ParcelScanning(userEmail: userEmail)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("User email not found. Please re-login.")),
            );
          }
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
                  margin: EdgeInsets.only(bottom: 16, right: 4), // Added right margin for better placement
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16), // Slightly more rounded
                    gradient: LinearGradient( // Applied gradient
                      colors: [Colors.indigo.shade500, Colors.indigo.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.4), // Enhanced shadow
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12), // Adjusted padding
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer( // Added animation for icon
                        duration: Duration(milliseconds: 150),
                        padding: EdgeInsets.all(_isButtonPressed ? 7 : 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.directions_car_filled_outlined, // Changed icon
                          size: _isButtonPressed ? 22 : 20, // Icon size change on press
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 10), // Adjusted spacing
                      Text(
                        "DISPATCH",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold, // Bolder text
                          fontSize: 13, // Slightly larger font
                          letterSpacing: 1.0, // Increased letter spacing
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
    List<Map<String, dynamic>> filteredRoutes = allRoutes;

    // Apply filter
    if (selectedFilter != "All") {
      filteredRoutes = filteredRoutes.where((route) {
        final routeDate = DateTime.parse(route['timestamp']);
        final today = DateTime.now();
        if (selectedFilter == "Today") {
          return routeDate.year == today.year &&
              routeDate.month == today.month &&
              routeDate.day == today.day;
        } else if (selectedFilter == "This Week") {
          final weekStart = today.subtract(Duration(days: today.weekday - 1));
          final weekEnd = weekStart.add(Duration(days: 6));
          return routeDate.isAfter(weekStart) && routeDate.isBefore(weekEnd);
        }
        return false;
      }).toList();
    }

    // Apply sorting
    filteredRoutes.sort((a, b) {
      final dateA = DateTime.parse(a['timestamp']);
      final dateB = DateTime.parse(b['timestamp']);
      return isAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });

    return ListView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.all(16),
      children: [
        // Previous Route Summary
        if (routeSummary != null)
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade50, Colors.indigo.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history, color: Colors.indigo[700], size: 28),
                        SizedBox(width: 12),
                        Text(
                          "Previous Route",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildSummaryRow(Icons.directions_car, "Distance: ${routeSummary!['distance']} km"),
                    _buildSummaryRow(Icons.timer_outlined, "Time: ${routeSummary!['time']} minutes"),
                    _buildSummaryRow(Icons.location_on_outlined, "Addresses: ${routeSummary!['totalAddresses']}"),
                  ],
                ),
              ),
            ),
          ),
        SizedBox(height: 16),

        // Total Routes Summary
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade50, Colors.deepPurple.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assessment, color: Colors.deepPurple[700], size: 28),
                      SizedBox(width: 12),
                      Text(
                        "Lifetime Summary",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildSummaryRow(Icons.directions_car, "Total Distance: ${allRoutes.fold<double>(0.0, (sum, route) => sum + ((route['distance'] as num?)?.toDouble() ?? 0.0)).toStringAsFixed(1)} km"),
                  _buildSummaryRow(Icons.timer_outlined, "Total Time: ${allRoutes.fold<int>(0, (sum, route) => sum + ((route['time'] as num?)?.toInt() ?? 0))} minutes"),
                  _buildSummaryRow(Icons.location_on_outlined, "Total Addresses: ${allRoutes.fold<int>(0, (sum, route) => sum + ((route['totalAddresses'] as num?)?.toInt() ?? 0))}"),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 20),
        Divider(thickness: 1, color: Colors.grey[300]),
        SizedBox(height: 10),

        // Filter and Sort Options
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedFilter,
                    icon: Icon(Icons.filter_list, color: Colors.indigo),
                    items: ["All", "Today", "This Week"]
                        .map((filter) => DropdownMenuItem(
                              value: filter,
                              child: Text(
                                filter,
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedFilter = value!;
                      });
                    },
                  ),
                ),
              ),
              TextButton.icon(
                icon: Icon(
                  isAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: Colors.indigo,
                  size: 20,
                ),
                label: Text(
                  isAscending ? "Oldest First" : "Newest First",
                  style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  setState(() {
                    isAscending = !isAscending;
                  });
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: Colors.indigo.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10),

        // Filtered Routes List
        if (filteredRoutes.isEmpty && selectedFilter != "All")
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                  SizedBox(height: 8),
                  Text(
                    "No routes found for '$selectedFilter'.",
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else if (allRoutes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.map_outlined, size: 48, color: Colors.grey[400]),
                  SizedBox(height: 8),
                  Text(
                    "No dispatch history yet.",
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Start a dispatch to see your routes here.",
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          )
        else
          ...filteredRoutes.map((route) {
            final routeDate = DateTime.parse(route['timestamp']);
            return Card(
              elevation: 2,
              margin: EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo[100],
                  child: Icon(Icons.route_outlined, color: Colors.indigo[700]),
                ),
                title: Text(
                  "Route on ${routeDate.toLocal().toString().split(' ')[0]}",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    Text("Distance: ${route['distance']} km"),
                    Text("Time: ${route['time']} minutes"),
                    Text("Addresses: ${route['totalAddresses']}"),
                  ],
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                onTap: () {
                  // Optional: Navigate to a detailed view of the route
                },
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildSummaryRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 15, color: Colors.black87)),
        ],
      ),
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
