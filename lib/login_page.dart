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
    // Add this line to sign out from Google, forcing account selection
    await GoogleSignIn().signOut(); 
    
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
    final themeColor = Colors.indigo; // Using Indigo as the primary theme color
    final subtleTextColor = Colors.grey[600];

    return Scaffold(
      // backgroundColor: Colors.grey[50], // Softer background color // Will be overridden by Container's gradient
      body: Container( // Wrap with a Container for the gradient
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade300, Colors.blue.shade600], // Beautiful purple and blue gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24), // Increased padding
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 400), // Max width for larger screens
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 28, vertical: 36), // Adjusted padding
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24), // Softer border radius
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15), // Softer, more diffused shadow
                      blurRadius: 30,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo - Consider using a local asset for better performance and offline availability
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        'https://media-hosting.imagekit.io/c050505ecb994e3f/Smart%20Dispatch.jpg?Expires=1841588353&Key-Pair-Id=K2ZIVPTIP2VGHC&Signature=TVSztEB~TMpc-JqUfoN2o~vFbnKUxPkwdYwuUimopGtGc8mzZ5IdDBTi86fVpglNuyfAFvyWo-B-WKR1~s7UEn0lD~uoJHsgzmHLVjxqL9CxCIDYT5a115Y~z88Oqkgb3eFDRSqt~Y5Tgdx5PWKjo5VlbT0QTeKwYBTUda1FP3ngkDfhrOl0PV~YnrpJgASRruMUFNziZeqT3mr0bc5KtACGH6XACwGfQFDPYlkGhbEbPjtGB5nVB6T~yHZyzH9MDpnh8CqEuhVsZ4eHEGj1iAEd~WbmESq1kxNZX9G6~X7V9kKXaU1m-eNVdp683KsSS1LauWHB4RRtiUmN3RrC8Q__',
                        height: 90, // Adjusted size
                        width: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Smart Dispatch",
                      style: TextStyle(
                        fontFamily: 'Inter', // Using a more modern font
                        fontWeight: FontWeight.bold,
                        fontSize: 28, // Slightly larger
                        color: themeColor,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Welcome back! Please login to continue.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        color: subtleTextColor,
                      ),
                    ),
                    SizedBox(height: 32), // Increased spacing
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: "Email Address",
                        labelStyle: TextStyle(fontFamily: 'Inter', color: themeColor.withOpacity(0.8), fontSize: 14),
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
                          borderSide: BorderSide(color: themeColor, width: 2.0), // Thicker focus border
                        ),
                        prefixIcon: Icon(Icons.alternate_email_outlined, color: themeColor.withOpacity(0.7), size: 20),
                        filled: true,
                        fillColor: Colors.grey[50], // Light fill for text fields
                        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16), // Adjusted padding
                      ),
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Colors.black87),
                    ),
                    SizedBox(height: 18), // Adjusted spacing
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: "Password",
                        labelStyle: TextStyle(fontFamily: 'Inter', color: themeColor.withOpacity(0.8), fontSize: 14),
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
                          borderSide: BorderSide(color: themeColor, width: 2.0),
                        ),
                        prefixIcon: Icon(Icons.lock_outline, color: themeColor.withOpacity(0.7), size: 20),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      obscureText: true,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Colors.black87),
                    ),
                    SizedBox(height: 28), // Increased spacing
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading
                            ? null
                            : () => signInWithEmail(context),
                        child: _loading
                            ? SizedBox(
                                width: 20, // Slightly larger progress indicator
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : Text("Login", style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16), // Increased padding
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2, // Subtle elevation
                          shadowColor: themeColor.withOpacity(0.3),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text("OR", style: TextStyle(color: subtleTextColor, fontFamily: 'Inter', fontWeight: FontWeight.w500, fontSize: 13)),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => signInWithGoogle(context),
                        icon: Image.network( // Consider using a local asset or an SVG icon
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                          height: 20, // Adjusted size
                          width: 20,
                          fit: BoxFit.contain,
                        ),
                        label: Text(
                          "Sign in with Google",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 16, // Consistent font size
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.grey[700], // Darker grey for better contrast
                          padding: EdgeInsets.symmetric(vertical: 15), // Adjusted padding
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade300, width: 1.5) // Slightly thicker border
                          ),
                          elevation: 1, // Minimal elevation
                          shadowColor: Colors.grey.withOpacity(0.1),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        // TODO: Implement forgot password navigation
                      },
                      child: Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: themeColor.withOpacity(0.9),
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 14, // Adjusted size
                          decoration: TextDecoration.underline,
                          decorationColor: themeColor.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
