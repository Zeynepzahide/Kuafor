import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'pages/customer_home_page.dart';
import 'pages/stylist_home_page.dart';
import 'pages/salon_owner_home_page.dart';

import 'services/auth_service.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kuaför Uygulaması',

      theme: ThemeData(
        useMaterial3: true,

        // TÜM ARKA PLANLAR BEYAZ
        scaffoldBackgroundColor: Colors.white,
        canvasColor: Colors.white,
        cardColor: Colors.white,

        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0B132B),
          secondary: Color(0xFFB08D57),
        ),

        // APPBAR
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B132B),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),

        // BOTTOM SHEET
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
        ),

        // FLOATING ACTION BUTTON
        floatingActionButtonTheme:
            const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFB08D57),
          foregroundColor: Colors.white,
        ),

        // BUTTON
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB08D57),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // INPUT
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,

          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),

          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFB08D57),
              width: 1.5,
            ),
          ),
        ),

        dividerColor: const Color(0xFFEAEAEA),
      ),

      home: const SplashDecider(),
    );
  }
}

class SplashDecider extends StatefulWidget {
  const SplashDecider({super.key});

  @override
  State<SplashDecider> createState() =>
      _SplashDeciderState();
}

class _SplashDeciderState
    extends State<SplashDecider> {
  final AuthService _authService =
      AuthService();

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final token =
        await _authService.getToken();

    // Token yoksa misafir giriş
    if (token == null || token.isEmpty) {
      _goTo(
        const CustomerHomePage(
          guestMode: true,
        ),
      );
      return;
    }

    final user =
        await _authService.getUserInfo(token);

    if (user == null) {
      await _authService.deleteToken();

      _goTo(
        const CustomerHomePage(
          guestMode: true,
        ),
      );

      return;
    }

    final role =
        user['role']?.toString() ?? '';

    final page =
        _getHomePageByRole(role);

    if (page != null) {
      _goTo(page);
    } else {
      await _authService.deleteToken();

      _goTo(
        const CustomerHomePage(
          guestMode: true,
        ),
      );
    }
  }

  Widget? _getHomePageByRole(
      String role) {
    switch (role) {
      case 'Customer':
        return const CustomerHomePage(
          guestMode: false,
        );

      case 'Hairdresser':
        return const StylistHomePage();

      case 'SalonOwner':
        return const SalonOwnerHomePage();

      default:
        return const CustomerHomePage(
          guestMode: false,
        );
    }
  }

  void _goTo(Widget page) {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFB08D57),
        ),
      ),
    );
  }
}