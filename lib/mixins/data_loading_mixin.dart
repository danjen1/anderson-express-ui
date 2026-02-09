import 'package:flutter/material.dart';

/// Mixin for handling common data loading patterns with error handling.
mixin DataLoadingMixin<T extends StatefulWidget> on State<T> {
  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadData(Future<void> Function() loader) async {
    if (!mounted) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await loader();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}
