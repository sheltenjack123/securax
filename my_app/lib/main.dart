import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import all screens
import 'screens/cinematic_splash.dart';
import 'screens/signup_page.dart';
import 'screens/app_lock_screen.dart';
import 'screens/main_screen.dart';
import 'screens/fake_home_page.dart';
import 'services/backend_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase not initialized (ignore if testing UI): $e");
  }

  // Make backend URL available to native Android code (CameraService).
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_base_url', BackendConfig.baseUrl);
  } catch (_) {}

  // Transparent status bar for a modern look.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Securax",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        primaryColor: Colors.greenAccent,
        useMaterial3: true,
        // Global app bar theme (consistency enforced here).
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 24, 110, 54),
          centerTitle: true,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),

      // Start flow: Splash -> Main
      home: const CinematicSplashScreen(),

      routes: {
        '/signup': (context) => const SignUpPage(),
        '/lock': (context) => const AppLockScreen(),
        '/home': (context) => const MainScreen(), // The mother container.
        '/fake_home': (context) => const FakeHomePage(),
      },
    );
  }
}
