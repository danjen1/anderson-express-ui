import 'package:flutter/material.dart';

class CleanerPage extends StatelessWidget {
  const CleanerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cleaner')),
      body: const Center(
        child: Text(
          'Cleaner Dashboard\n(Coming Soon)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
