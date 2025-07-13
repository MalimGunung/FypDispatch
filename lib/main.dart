import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'parcel_scanner.dart';
import 'login_page.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- Add this import
import 'firebase_service.dart'; // <-- Add this import
import 'dart:ui'; // <-- Add this import for ImageFilter

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
  const AuthGate({super.key});

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
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService firebaseService = FirebaseService();
  Map<String, dynamic>? routeSummary;
  List<Map<String, dynamic>> allRoutes = [];
  String selectedFilter = "All";
  bool isAscending = false;

  @override
  void initState() {
    super.initState();
    fetchAllRoutes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchAllRoutes();
  }

  // Call this after returning from any delivery/dispatch screen to refresh summary
  Future<void> refreshAfterDispatch() async {
    await fetchAllRoutes();
    setState(() {}); // Force rebuild to update UI
  }

  // Fetch the latest route summary for the current user (most recent)
  Future<void> fetchRouteSummary() async {
    try {
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      if (userEmail == null) return;
      final summary = await firebaseService.getRouteSummary(userEmail);
      setState(() {
        routeSummary = summary;
      });
    } catch (e) {
      print("❌ Error fetching route summary: $e");
    }
  }

  // Fetch all route summaries for the current user
  Future<void> fetchAllRoutes() async {
    try {
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      if (userEmail == null) return;
      final routes = await firebaseService.getAllRoutes(userEmail);
      setState(() {
        allRoutes = routes;
        routeSummary = routes.isNotEmpty ? routes.first : null;
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
      // Add a gradient background
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFe0e7ff), Color(0xFFf8fafc)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Decorative wave header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: _WaveClipper(),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade400, Colors.indigo.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Icon(Icons.local_shipping_rounded, color: Colors.white, size: 32), // Removed lorry logo
                          SizedBox(width: 0), // Remove spacing after icon
                          Text(
                            "Smart Dispatch",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontFamily: 'Inter',
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (user != null)
                        PopupMenuButton<String>(
                          offset: const Offset(0, 50),
                          elevation: 3.0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          tooltip: "Account options",
                          onSelected: (value) async {
                            if (value == 'logout') {
                              await FirebaseAuth.instance.signOut();
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => LoginPage()),
                                (route) => false,
                              );
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              enabled: false,
                              padding: EdgeInsets.zero,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 16.0),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.indigo.shade400,
                                      Colors.blue.shade300
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(height: 4),
                                    CircleAvatar(
                                      radius: 34,
                                      backgroundImage: photoURL != null
                                          ? NetworkImage(photoURL)
                                          : null,
                                      backgroundColor: photoURL == null
                                          ? Colors.white.withOpacity(0.25)
                                          : Colors.transparent,
                                      child: photoURL == null
                                          ? Icon(Icons.person_outline,
                                              size: 34, color: Colors.white)
                                          : null,
                                    ),
                                    SizedBox(height: 14),
                                    if (user.displayName != null &&
                                        user.displayName!.isNotEmpty)
                                      Text(
                                        user.displayName!,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                    SizedBox(
                                        height: user.displayName != null &&
                                                user.displayName!.isNotEmpty
                                            ? 6
                                            : 0),
                                    if (user.email != null)
                                      Text(
                                        user.email!,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                    SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            ),
                            const PopupMenuDivider(height: 1),
                            PopupMenuItem<String>(
                              value: 'logout',
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0, vertical: 14.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Icon(Icons.exit_to_app_rounded,
                                      color: Colors.red[600], size: 22),
                                  SizedBox(width: 14),
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
                          child: CircleAvatar(
                            backgroundImage: photoURL != null
                                ? NetworkImage(photoURL)
                                : null,
                            backgroundColor:
                                photoURL == null ? Colors.indigo[100] : null,
                            radius: 22,
                            child: photoURL == null
                                ? Icon(Icons.person,
                                    color: Colors.indigo[600], size: 20)
                                : null,
                          ),
                        )
                      else
                        IconButton(
                          icon: Icon(Icons.login, color: Colors.white),
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => LoginPage()),
                              (route) => false,
                            );
                          },
                          tooltip: 'Login',
                        ),
                    ],
                  ),
                ),
                // Toggle Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 12),
                  child: Row(
                    children: [
                      for (int i = 0; i < tabs.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: AnimatedScale(
                            scale: selectedTabIndex == i
                                ? 1.05
                                : 0.97, // Slightly smaller
                            duration: Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    16), // Slightly less rounded
                                gradient: selectedTabIndex == i
                                    ? LinearGradient(
                                        colors: [
                                          Colors.indigo.withOpacity(0.18),
                                          Colors.blue.withOpacity(0.10)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                border: Border.all(
                                  color: selectedTabIndex == i
                                      ? Colors.indigo.withOpacity(0.35)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: selectedTabIndex == i
                                    ? [
                                        BoxShadow(
                                          color:
                                              Colors.indigo.withOpacity(0.10),
                                          blurRadius: 12,
                                          offset: Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter: selectedTabIndex == i
                                      ? ImageFilter.blur(sigmaX: 8, sigmaY: 8)
                                      : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                                  child: ChoiceChip(
                                    label: Row(
                                      children: [
                                        Icon(
                                          i == 0
                                              ? Icons
                                                  .dashboard_customize_rounded
                                              : Icons.newspaper_rounded,
                                          color: selectedTabIndex == i
                                              ? Colors.indigo[700]
                                              : Colors.indigo[300],
                                          size: 17, // Smaller icon
                                        ),
                                        SizedBox(width: 5), // Less spacing
                                        Text(
                                          tabs[i],
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14, // Smaller font
                                            color: selectedTabIndex == i
                                                ? Colors.indigo[700]
                                                : Colors.indigo[300],
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    selected: selectedTabIndex == i,
                                    onSelected: (_) =>
                                        setState(() => selectedTabIndex = i),
                                    selectedColor: Colors.transparent,
                                    backgroundColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8), // Smaller padding
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 350),
                      switchInCurve: Curves.easeIn,
                      switchOutCurve: Curves.easeOut,
                      child: selectedTabIndex == 0
                          ? buildDispatchList()
                          : buildNewsList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Floating Action Button
      floatingActionButton: GestureDetector(
        onTapDown: (_) => setState(() => _isButtonPressed = true),
        onTapUp: (_) => setState(() => _isButtonPressed = false),
        onTapCancel: () => setState(() => _isButtonPressed = false),
        onTap: () async {
          final userEmail = FirebaseAuth.instance.currentUser?.email;
          if (userEmail != null) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ParcelScanning(userEmail: userEmail)),
            );
            // Ensure summary is refreshed after returning from dispatch
            await refreshAfterDispatch();
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
                  margin: EdgeInsets.only(bottom: 16, right: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [Colors.indigo.shade500, Colors.indigo.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.25),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: Duration(milliseconds: 150),
                        padding: EdgeInsets.all(_isButtonPressed ? 7 : 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.directions_car_filled_outlined,
                          size: _isButtonPressed ? 22 : 20,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "DISPATCH",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 1.2,
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

    // Calculate total summary for all routes
    double totalDistance = 0.0;
    int totalTime = 0;
    int totalAddresses = 0;
    for (final route in allRoutes) {
      totalDistance += (route['distance'] as num?)?.toDouble() ?? 0.0;
      totalTime += (route['time'] as num?)?.toInt() ?? 0;
      totalAddresses += (route['totalAddresses'] as num?)?.toInt() ?? 0;
    }

    return ListView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 24),
      children: [
        // Previous Route Summary
        if (routeSummary != null)
          Card(
            elevation: 8,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            margin: EdgeInsets.only(bottom: 18),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    Colors.indigo.shade400,
                    Colors.blue.shade500
                  ], // Changed color
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.2), // Changed color
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(24), // Reduced padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white
                                .withOpacity(0.25), // Changed style
                          ),
                          padding:
                              EdgeInsets.all(10), // Adjusted padding
                          child: Icon(Icons.history,
                              color: Colors.white,
                              size: 28), // Adjusted size
                        ),
                        SizedBox(width: 12), // Reduced size
                        Text(
                          "Previous Route",
                          style: TextStyle(
                            fontSize: 20, // Adjusted size
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // Changed color
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16), // Reduced size
                    _buildSummaryRow(Icons.directions_car,
                        "Distance: ${(routeSummary!['distance'] as num).toStringAsFixed(1)} km"),
                    _buildSummaryRow(Icons.timer_outlined,
                        "Time: ${routeSummary!['time']} minutes"),
                    _buildSummaryRow(Icons.location_on_outlined,
                        "Addresses: ${routeSummary!['totalAddresses']}"),
                  ],
                ),
              ),
            ),
          ),
        // Total Routes Summary
        Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          margin: EdgeInsets.only(bottom: 18),
          color: Colors.white, // Changed to solid color
          child: Padding(
            padding: EdgeInsets.all(24), // Reduced padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.indigo.shade50, // Changed style
                      ),
                      padding:
                          EdgeInsets.all(10), // Adjusted padding
                      child: Icon(Icons.assessment,
                          color: Colors.indigo.shade400,
                          size: 28), // Adjusted size
                    ),
                    SizedBox(width: 12), // Reduced size
                    Text(
                      "Lifetime Summary",
                      style: TextStyle(
                        fontSize: 20, // Adjusted size
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16), // Reduced size
                _buildSummaryRow(Icons.directions_car,
                    "Total Distance: ${totalDistance.toStringAsFixed(1)} km"),
                _buildSummaryRow(
                    Icons.timer_outlined, "Total Time: $totalTime minutes"),
                _buildSummaryRow(Icons.location_on_outlined,
                    "Total Addresses: $totalAddresses"),
              ],
            ),
          ),
        ),
        SizedBox(height: 16), // Reduced size
        Divider(thickness: 1, color: Colors.grey[300]),
        SizedBox(height: 10),

        // Filter and Sort Options
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.98),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.indigo.withOpacity(0.10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withOpacity(0.06),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Filter Dropdown (minimal)
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedFilter,
                    icon: Icon(Icons.filter_alt_rounded,
                        color: Colors.indigo[400], size: 22),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.indigo[700],
                      fontFamily: 'Inter',
                    ),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    items: [
                      DropdownMenuItem(
                        value: "All",
                        child: Row(
                          children: [
                            Icon(Icons.all_inclusive,
                                color: Colors.indigo[300], size: 18),
                            SizedBox(width: 6),
                            Text("All"),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: "Today",
                        child: Row(
                          children: [
                            Icon(Icons.today_rounded,
                                color: Colors.indigo[300], size: 18),
                            SizedBox(width: 6),
                            Text("Today"),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: "This Week",
                        child: Row(
                          children: [
                            Icon(Icons.calendar_view_week_rounded,
                                color: Colors.indigo[300], size: 18),
                            SizedBox(width: 6),
                            Text("This Week"),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedFilter = value!;
                      });
                    },
                  ),
                ),
                // Vertical divider
                Container(
                  height: 28,
                  width: 1,
                  color: Colors.indigo.withOpacity(0.10),
                  margin: EdgeInsets.symmetric(horizontal: 10),
                ),
                // Sort Button (minimal)
                TextButton.icon(
                  icon: Icon(
                    isAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: Colors.indigo[600],
                    size: 20,
                  ),
                  label: Text(
                    isAscending ? "Oldest" : "Newest",
                    style: TextStyle(
                      color: Colors.indigo[700],
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      fontFamily: 'Inter',
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      isAscending = !isAscending;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    backgroundColor: Colors.indigo.withOpacity(0.07),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                ),
              ],
            ),
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
                  Icon(Icons.search_off, size: 54, color: Colors.indigo[100]),
                  SizedBox(height: 10),
                  Text(
                    "No routes found for '$selectedFilter'.",
                    style: TextStyle(fontSize: 17, color: Colors.indigo[300]),
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
                  Icon(Icons.map_outlined,
                      size: 54, color: Colors.indigo[100]),
                  SizedBox(height: 10),
                  Text(
                    "No dispatch history yet.",
                    style: TextStyle(fontSize: 17, color: Colors.indigo[300]),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Start a dispatch to see your routes here.",
                    style: TextStyle(fontSize: 15, color: Colors.indigo[200]),
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
              shadowColor: Colors.indigo.withOpacity(0.1),
              margin: EdgeInsets.only(
                  bottom: 16, left: 2, right: 2), // Reduced bottom margin
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20), // Adjusted radius
                side: BorderSide(color: const Color.fromARGB(255, 40, 103, 138), width: 1),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12), // Adjusted padding
                leading: Container(
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50, // Changed style
                    borderRadius:
                        BorderRadius.circular(16), // Changed shape
                  ),
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.route_outlined,
                      color: Colors.indigo.shade400,
                      size: 28), // Changed color and size
                ),
                title: Padding(
                  padding:
                      const EdgeInsets.only(bottom: 4.0), // Adjusted padding
                  child: Text(
                    "Route on ${routeDate.toLocal().toString().split(' ')[0]}",
                    style: TextStyle(
                      fontWeight: FontWeight.w800, // Adjusted weight
                      fontSize: 16, // Adjusted size
                      color: Color(0xFF2C3E50), // Adjusted color
                    ),
                  ),
                ),
                subtitle: Padding(
                  padding:
                      const EdgeInsets.only(top: 4.0), // Adjusted padding
                  child: Row(
                    children: [
                      Icon(Icons.directions_car,
                          size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        "${(route['distance'] as num).toStringAsFixed(1)} km",
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.grey[800]), // Adjusted style
                      ),
                      SizedBox(width: 12), // Reduced size
                      Icon(Icons.timer_outlined,
                          size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text("${route['time']} min",
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.grey[800])), // Adjusted style
                      SizedBox(width: 12), // Reduced size
                      Icon(Icons.location_on_outlined,
                          size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text("${route['totalAddresses']}",
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.grey[800])), // Adjusted style
                    ],
                  ),
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey[400]), // Adjusted style
                onTap: () {
                  // Optional: Navigate to a detailed view of the route
                },
              ),
            );
          }),
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
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 32),
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
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.indigo.shade200,
                            Colors.indigo.shade400
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.indigo.withOpacity(0.10),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(icon, size: 24, color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        date,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.indigo[400],
                              fontWeight: FontWeight.w600,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[900],
                      ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                SizedBox(height: 8),
                Text(
                  snippet,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.indigo[700],
                      ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {},
                      icon: Icon(Icons.arrow_forward_rounded, color: Colors.indigo, size: 18),
                      label: Text(
                        "Read more",
                        style: TextStyle(
                          color: Colors.indigo,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

// Decorative wave clipper for header
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
        size.width / 2, size.height, size.width, size.height - 40);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
