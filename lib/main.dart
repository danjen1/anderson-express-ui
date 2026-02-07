import 'package:flutter/material.dart';

import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/cleaner_page.dart';
import 'pages/admin_page.dart';
import 'pages/clients_page.dart';
import 'pages/jobs_page.dart';
import 'pages/locations_page.dart';
import 'pages/qa_smoke_page.dart';

const Color kBrandPurplePrimary = Color.fromRGBO(125, 113, 169, 1);
const Color kBrandPurpleDark = Color.fromRGBO(104, 88, 147, 1);
const Color kBrandPurpleSoft = Color.fromRGBO(199, 199, 215, 1);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Route<dynamic> _routeFor(RouteSettings settings) {
    final uri = Uri.tryParse(settings.name ?? "/") ?? Uri(path: "/");
    final path = uri.path.isEmpty ? "/" : uri.path;

    switch (path) {
      case "/":
        return MaterialPageRoute(
          builder: (_) => LoginPage(),
          settings: settings,
        );
      case "/home":
        return MaterialPageRoute(
          builder: (_) => HomePage(),
          settings: settings,
        );
      case "/register":
        return MaterialPageRoute(
          builder: (_) =>
              RegisterPage(initialEmail: uri.queryParameters["email"]),
          settings: settings,
        );
      case "/cleaner":
        return MaterialPageRoute(
          builder: (_) => CleanerPage(),
          settings: settings,
        );
      case "/admin":
        return MaterialPageRoute(
          builder: (_) => AdminPage(),
          settings: settings,
        );
      case "/clients":
        return MaterialPageRoute(
          builder: (_) => ClientsPage(),
          settings: settings,
        );
      case "/jobs":
        return MaterialPageRoute(
          builder: (_) => JobsPage(),
          settings: settings,
        );
      case "/locations":
        return MaterialPageRoute(
          builder: (_) => LocationsPage(),
          settings: settings,
        );
      case "/qa-smoke":
        return MaterialPageRoute(
          builder: (_) => QaSmokePage(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => LoginPage(),
          settings: settings,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: kBrandPurplePrimary,
      primary: kBrandPurplePrimary,
      secondary: kBrandPurpleDark,
      surface: Colors.white,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Anderson Cleaning Express Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color.fromRGBO(246, 244, 252, 1),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: kBrandPurpleDark,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color.fromRGBO(225, 221, 236, 1)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: kBrandPurpleSoft.withValues(alpha: 0.45),
          selectedColor: kBrandPurplePrimary.withValues(alpha: 0.2),
          labelStyle: const TextStyle(
            color: kBrandPurpleDark,
            fontWeight: FontWeight.w600,
          ),
          side: const BorderSide(color: Color.fromRGBO(213, 205, 231, 1)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color.fromRGBO(211, 204, 230, 1),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color.fromRGBO(211, 204, 230, 1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: kBrandPurplePrimary,
              width: 1.4,
            ),
          ),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      onGenerateRoute: _routeFor,
    );
  }
}
