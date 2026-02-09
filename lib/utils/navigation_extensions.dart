import 'package:flutter/material.dart';

/// Navigation helpers for common app routes.
/// 
/// Provides convenient methods to navigate between pages
/// without repeatedly typing pushReplacementNamed.
extension NavigationHelpers on BuildContext {
  /// Navigate to the home page, replacing current route.
  void navigateToHome() {
    Navigator.pushReplacementNamed(this, '/home');
  }

  /// Navigate to the login page, replacing current route.
  void navigateToLogin() {
    Navigator.pushReplacementNamed(this, '/');
  }

  /// Navigate to the admin page, replacing current route.
  void navigateToAdmin() {
    Navigator.pushReplacementNamed(this, '/admin');
  }

  /// Navigate to the jobs page, replacing current route.
  void navigateToJobs() {
    Navigator.pushReplacementNamed(this, '/jobs');
  }

  /// Navigate to the clients page, replacing current route.
  void navigateToClients() {
    Navigator.pushReplacementNamed(this, '/clients');
  }

  /// Navigate to the locations page, replacing current route.
  void navigateToLocations() {
    Navigator.pushReplacementNamed(this, '/locations');
  }

  /// Navigate to the profile page, replacing current route.
  void navigateToProfile() {
    Navigator.pushReplacementNamed(this, '/profile');
  }
}
