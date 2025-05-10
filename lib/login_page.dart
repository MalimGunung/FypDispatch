import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main.dart'; // Ensure HomeScreen is imported
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MaterialApp(
      home: LoginPage(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> signInWithGoogle(BuildContext context) async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return; // Cancelled

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await FirebaseAuth.instance.signInWithCredential(credential);

    // Redirect to home after login
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen()),
    );
  }

  Future<void> signInWithEmail(BuildContext context) async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeBlue = Colors.blueAccent.shade700; // Consistent with parcel_scanner.dart
    final gradientBg = BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color(0xFFF3F5F9),
          Color(0xFFE8EFF5)
        ], // Matching parcel_scanner.dart body gradient
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: gradientBg,
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9), // Slightly more opaque, similar to dialogs
                borderRadius: BorderRadius.circular(16), // Consistent with parcel_scanner.dart cards/dialogs
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07), // Softer shadow
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: Colors.grey.shade300.withOpacity(0.5), // Subtle border
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20), // Slightly less rounded
                      boxShadow: [
                        BoxShadow(
                          color: themeBlue.withOpacity(0.12),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        'https://media-hosting.imagekit.io/432ca6550fc64f3f/Smart%20Dispatch.png?Expires=1840895419&Key-Pair-Id=K2ZIVPTIP2VGHC&Signature=J~Rq~qO8MU~HDZHGn4w9vQ6XBTgIXN5jQkUxuxuWpZdapm4QRdAu~iqcwubKo6mrrbumTOej6Bny0ZtW1o6lPQFFtYjlwRlKmnZtad0Dd8HMXHhuL0LBdk8TMSA87krsPwQnIxnMnllOd6HqhaycE5QV3N5JPwuxHirA5UCqERUI3BSvKzPbpY4NztJp67hiTCj64-N48G0rncgUUUnwxzMqIoIxuzBJU8gjew7URC1pNV-zYOo2cuHWNPQwKiNhuMYrXpISyyEfS9HwPd0C~pv3kthG7AfUjfTWcm4Aqdedm884QcfAzoEy5uvOR25HmwMQWfPgGgnUmT--DrXYMw__',
                        height: 110,
                        width: 110,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(height: 18),
                  Text(
                    "Smart Dispatch",
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      color: themeBlue,
                      letterSpacing: 0.8,
                      shadows: [
                        Shadow(
                          color: themeBlue.withOpacity(0.08),
                          blurRadius: 5,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Welcome back! Please login to continue.",
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13.5,
                      color: Colors.blueGrey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 26),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: "Email Address",
                      labelStyle: TextStyle(fontFamily: 'Montserrat', color: themeBlue.withOpacity(0.9), fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), // Consistent radius
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: themeBlue, width: 1.5),
                      ),
                      prefixIcon: Icon(Icons.alternate_email, color: themeBlue.withOpacity(0.7), size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, color: Colors.black87),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: "Password",
                      labelStyle: TextStyle(fontFamily: 'Montserrat', color: themeBlue.withOpacity(0.9), fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: themeBlue, width: 1.5),
                      ),
                      prefixIcon: Icon(Icons.lock_outline, color: themeBlue.withOpacity(0.7), size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                    ),
                    obscureText: true,
                    style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, color: Colors.black87),
                  ),
                  SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading
                          ? null
                          : () => signInWithEmail(context),
                      child: _loading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : Text("Login", style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Consistent radius
                        elevation: 3,
                        shadowColor: themeBlue.withOpacity(0.25),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300, thickness: 0.7)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text("OR", style: TextStyle(color: Colors.grey[500], fontFamily: 'Montserrat', fontWeight: FontWeight.w500, fontSize: 12.5)),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300, thickness: 0.7)),
                    ],
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => signInWithGoogle(context),
                      icon: Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                        height: 18,
                        width: 18,
                        fit: BoxFit.contain,
                      ),
                      label: Text(
                        "Sign in with Google",
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black.withOpacity(0.75),
                        padding: EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300, width: 1) 
                        ),
                        elevation: 1.5,
                        shadowColor: Colors.grey.withOpacity(0.15),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      // TODO: Implement forgot password navigation
                    },
                    child: Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: themeBlue.withOpacity(0.85),
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor: themeBlue.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
