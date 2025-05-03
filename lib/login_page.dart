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
    final themeBlue = Colors.blueAccent.shade700;
    final gradientBg = BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFe0eafc), Color(0xFFcfdef3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
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
            padding: EdgeInsets.all(24),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: themeBlue.withOpacity(0.13),
                    blurRadius: 32,
                    offset: Offset(0, 16),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.35),
                  width: 1.5,
                ),
                // Glassmorphism effect
                backgroundBlendMode: BlendMode.overlay,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lorry logo: much bigger, curved, and shadowed
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: themeBlue.withOpacity(0.18),
                          blurRadius: 32,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: Image.network(
                        'https://media-hosting.imagekit.io/432ca6550fc64f3f/Smart%20Dispatch.png?Expires=1840895419&Key-Pair-Id=K2ZIVPTIP2VGHC&Signature=J~Rq~qO8MU~HDZHGn4w9vQ6XBTgIXN5jQkUxuxuWpZdapm4QRdAu~iqcwubKo6mrrbumTOej6Bny0ZtW1o6lPQFFtYjlwRlKmnZtad0Dd8HMXHhuL0LBdk8TMSA87krsPwQnIxnMnllOd6HqhaycE5QV3N5JPwuxHirA5UCqERUI3BSvKzPbpY4NztJp67hiTCj64-N48G0rncgUUUnwxzMqIoIxuzBJU8gjew7URC1pNV-zYOo2cuHWNPQwKiNhuMYrXpISyyEfS9HwPd0C~pv3kthG7AfUjfTWcm4Aqdedm884QcfAzoEy5uvOR25HmwMQWfPgGgnUmT--DrXYMw__',
                        height: 150,
                        width: 150,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(height: 22),
                  Text(
                    "Smart Dispatch",
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                      color: themeBlue,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: themeBlue.withOpacity(0.08),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Welcome back! Please login to continue.",
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 15,
                      color: Colors.blueGrey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 32),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      labelStyle: TextStyle(fontFamily: 'Montserrat', color: themeBlue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: themeBlue.withOpacity(0.18)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: themeBlue.withOpacity(0.13)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: themeBlue, width: 2),
                      ),
                      prefixIcon: Icon(Icons.email, color: themeBlue),
                      filled: true,
                      fillColor: Colors.blueGrey[50]?.withOpacity(0.7),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(fontFamily: 'Montserrat', fontSize: 17),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: "Password",
                      labelStyle: TextStyle(fontFamily: 'Montserrat', color: themeBlue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: themeBlue.withOpacity(0.18)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: themeBlue.withOpacity(0.13)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: themeBlue, width: 2),
                      ),
                      prefixIcon: Icon(Icons.lock, color: themeBlue),
                      filled: true,
                      fillColor: Colors.blueGrey[50]?.withOpacity(0.7),
                    ),
                    obscureText: true,
                    style: TextStyle(fontFamily: 'Montserrat', fontSize: 17),
                  ),
                  SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading
                          ? null
                          : () => signInWithEmail(context),
                      child: _loading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text("Login with Email", style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 17)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 6,
                        shadowColor: themeBlue.withOpacity(0.22),
                      ),
                    ),
                  ),
                  SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.blueGrey[200], thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text("OR", style: TextStyle(color: Colors.grey[700], fontFamily: 'Montserrat', fontWeight: FontWeight.w600)),
                      ),
                      Expanded(child: Divider(color: Colors.blueGrey[200], thickness: 1)),
                    ],
                  ),
                  SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => signInWithGoogle(context),
                      icon: Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/4/4a/Logo_2013_Google.png',
                        height: 22,
                        width: 22,
                        fit: BoxFit.contain,
                      ),
                      label: Text(
                        "Sign in with Google",
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 7, 168, 232),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 5,
                        shadowColor: Colors.red[200],
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      // TODO: Implement forgot password navigation
                    },
                    child: Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: themeBlue,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        decoration: TextDecoration.underline,
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
