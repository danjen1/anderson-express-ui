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
import 'services/theme_controller.dart';

const Color kBrandPrimary = Color.fromRGBO(32, 116, 84, 1);
const Color kBrandPrimaryDark = Color.fromRGBO(24, 86, 62, 1);
const Color kBrandSoft = Color.fromRGBO(202, 227, 217, 1);

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
    final lightScheme = ColorScheme.fromSeed(
      seedColor: kBrandPrimary,
      primary: kBrandPrimary,
      secondary: kBrandPrimaryDark,
      surface: Colors.white,
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: kBrandPrimary,
      primary: const Color.fromRGBO(112, 197, 165, 1),
      secondary: const Color.fromRGBO(85, 166, 136, 1),
      surface: const Color.fromRGBO(22, 28, 26, 1),
      brightness: Brightness.dark,
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.listenable,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Anderson Cleaning Express Demo',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            colorScheme: lightScheme,
            scaffoldBackgroundColor: const Color.fromRGBO(242, 248, 245, 1),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: kBrandPrimaryDark,
              elevation: 0,
              centerTitle: false,
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color.fromRGBO(211, 229, 221, 1)),
              ),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: kBrandSoft.withValues(alpha: 0.5),
              selectedColor: kBrandPrimary.withValues(alpha: 0.2),
              labelStyle: const TextStyle(
                color: kBrandPrimaryDark,
                fontWeight: FontWeight.w600,
              ),
              side: const BorderSide(color: Color.fromRGBO(188, 219, 206, 1)),
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
                  color: Color.fromRGBO(195, 220, 209, 1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color.fromRGBO(195, 220, 209, 1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBrandPrimary, width: 1.4),
              ),
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkScheme,
            scaffoldBackgroundColor: const Color.fromRGBO(16, 21, 20, 1),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color.fromRGBO(20, 26, 24, 1),
              foregroundColor: Color.fromRGBO(184, 232, 209, 1),
              elevation: 0,
              centerTitle: false,
            ),
            cardTheme: CardThemeData(
              color: const Color.fromRGBO(26, 34, 32, 1),
              surfaceTintColor: Colors.transparent,
              elevation: 0.2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color.fromRGBO(52, 70, 64, 1)),
              ),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: const Color.fromRGBO(44, 61, 55, 1),
              selectedColor: const Color.fromRGBO(53, 92, 76, 1),
              labelStyle: const TextStyle(
                color: Color.fromRGBO(205, 233, 221, 1),
                fontWeight: FontWeight.w600,
              ),
              side: const BorderSide(color: Color.fromRGBO(67, 92, 83, 1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color.fromRGBO(29, 38, 36, 1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color.fromRGBO(67, 92, 83, 1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color.fromRGBO(67, 92, 83, 1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color.fromRGBO(112, 197, 165, 1),
                  width: 1.4,
                ),
              ),
            ),
            useMaterial3: true,
          ),
          initialRoute: '/',
          onGenerateRoute: _routeFor,
        );
      },
    );
  }
}
