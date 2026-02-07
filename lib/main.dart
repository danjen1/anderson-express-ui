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
    return MaterialApp(
      title: 'Anderson Cleaning Express Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      onGenerateRoute: _routeFor,
    );
  }
}
