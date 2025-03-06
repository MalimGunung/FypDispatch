import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'parcel_scanner.dart'; // Import the Parcel Scanner page

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
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(), // Use a separate HomeScreen widget
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Smart Route App")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Hello, Welcome to Smart Route!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ParcelScanning()),
                );
              },
              child: Text("Scan Parcel"),
            ),
          ],
        ),
      ),
    );
  }
}
