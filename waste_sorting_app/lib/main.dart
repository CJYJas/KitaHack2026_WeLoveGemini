import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const WasteSortingApp());
}

/// Main Application Widget
/// PolarGuard - AI-powered waste classification and recycling rewards app
class WasteSortingApp extends StatelessWidget {
  const WasteSortingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeLoveGemini - PolarGuard',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // Forest Green
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFF81C784),
          surface: const Color(0xFFF1F8E9),
          background: Colors.white,
        ),
        textTheme: GoogleFonts.quicksandTextTheme(),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: GoogleFonts.quicksand(
            color: const Color(0xFF2E7D32),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: const IconThemeData(color: Color(0xFF2E7D32)),
        ),
      ),
      home: const AuthenticationWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Authentication Wrapper
/// Handles routing based on user authentication state
class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2E7D32),
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          // User is logged in
          return const HomeScreen();
        }

        // User is not logged in
        return const LoginScreen();
      },
    );
  }
}
