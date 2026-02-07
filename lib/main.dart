import 'package:flutter/material.dart';

import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/cleaner_page.dart';
import 'pages/admin_page.dart';
import 'pages/locations_page.dart';
import 'pages/qa_smoke_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cleaning Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(),
        '/home': (context) => HomePage(),
        '/cleaner': (context) => CleanerPage(),
        '/admin': (context) => AdminPage(),
        '/locations': (context) => LocationsPage(),
        '/qa-smoke': (context) => QaSmokePage(),
      },
    );
  }
}
