import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'pages/customer_home_page.dart';
import 'pages/stylist_home_page.dart';
import 'pages/salon_owner_home_page.dart';

import 'services/auth_service.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService().initLocalNotifications();

  if (!kIsWeb) {
    await FirebaseService().initialize();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kuaför Uygulaması',

      // ───── TEMA DÜZELTİLDİ ─────
      theme: ThemeData(
        useMaterial3: true,

        scaffoldBackgroundColor: Colors.white,

        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0B132B),
          secondary: Color(0xFFB08D57),
          surface: Colors.white,
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B132B),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),

        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
        ),

        dialogTheme: const DialogTheme(
          backgroundColor: Colors.white,
        ),

        cardColor: Colors.white,

        canvasColor: Colors.white,

        dividerColor: Color(0xFFEAEAEA),

        floatingActionButtonTheme:
            const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFB08D57),
          foregroundColor: Colors.white,
        ),

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

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFB08D57),
              width: 1.5,
            ),
          ),
        ),
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