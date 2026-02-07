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
      routes: {
        '/': (context) => LoginPage(),
        '/home': (context) => HomePage(),
        '/register': (context) => RegisterPage(),
        '/cleaner': (context) => CleanerPage(),
        '/admin': (context) => AdminPage(),
        '/clients': (context) => ClientsPage(),
        '/jobs': (context) => JobsPage(),
        '/locations': (context) => LocationsPage(),
        '/qa-smoke': (context) => QaSmokePage(),
      },
    );
  }
}
