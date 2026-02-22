import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/navigation_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
          seedColor: const Color(0xFFAED581), // Pastel Light Green
          primary: const Color(0xFFAED581),
          secondary: const Color(0xFF81D4FA), // Pastel Light Blue
          surface: Colors.white,
          background: const Color(0xFFF1F8E9), // Pale Greenish-White
        ),
        textTheme: GoogleFonts.quicksandTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF1F8E9),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.quicksand(
            color: const Color(0xFF558B2F), // Darker Pastel Green for text
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: const IconThemeData(color: Color(0xFF558B2F)),
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
          return const NavigationWrapper();
        }

        // User is not logged in
        return const LoginScreen();
      },
    );
  }
}
