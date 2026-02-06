import 'package:flutter/material.dart';

import 'login_page.dart';
import 'home_page.dart';
import 'cleaner_page.dart';
import 'admin_page.dart';

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
      },
    );
  }
}
