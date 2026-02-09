import 'package:flutter/material.dart';

import '../models/backend_config.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../services/backend_runtime.dart';
import '../utils/error_text.dart';
import '../utils/navigation_extensions.dart';

/// Base mixin for API-backed pages with common functionality.
///
/// This mixin provides:
/// - Authentication and authorization checks
/// - Loading and error state management
/// - Backend configuration access
/// - Common UI builders (error display, backend override)
/// - Standardized data loading lifecycle
///
/// Usage:
/// ```dart
/// class MyPage extends StatefulWidget {
///   @override
///   State<MyPage> createState() => _MyPageState();
/// }
///
/// class _MyPageState extends State<MyPage> with BaseApiPageMixin<MyPage> {
///   List<MyModel> _items = [];
///
///   @override
///   Future<void> loadData() async {
///     _items = await api.getMyItems(token: token!);
///   }
///
///   @override
///   Widget buildContent(BuildContext context) {
///     return ListView.builder(...);
///   }
/// }
/// ```
mixin BaseApiPageMixin<T extends StatefulWidget> on State<T> {
  // ============================================================================
  // STATE VARIABLES
  // ============================================================================

  /// Whether data is currently being loaded
  bool _loading = true;

  /// Current error message, if any
  String? _error;

  /// Get current authentication token
  String? get token => AuthSession.current?.token.trim();

  /// Get API service instance
  ApiService get api => ApiService();

  /// Get current backend configuration
  BackendConfig get backend => BackendRuntime.config;

  // ============================================================================
  // GETTER METHODS
  // ============================================================================

  /// Whether page is currently loading
  bool get isLoading => _loading;

  /// Current error message
  String? get error => _error;

  // ============================================================================
  // LIFECYCLE METHODS
  // ============================================================================

  @override
  void initState() {
    super.initState();
    // Check authentication on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!checkAuth()) return;
      if (!checkAuthorization()) return;
      performInitialLoad();
    });
  }

  /// Check if user is authenticated
  ///
  /// Redirects to login if not authenticated.
  /// Returns true if authenticated, false otherwise.
  bool checkAuth() {
    if (AuthSession.current == null) {
      context.navigateToLogin();
      return false;
    }
    return true;
  }

  /// Check if user is authorized to view this page
  ///
  /// Override this method to implement custom authorization logic.
  /// Default implementation allows all authenticated users.
  /// Returns true if authorized, false otherwise.
  bool checkAuthorization() {
    return true; // Override in subclass for role-based access
  }

  /// Perform initial data load
  ///
  /// This method is called automatically after authentication check.
  void performInitialLoad() {
    loadDataSafe();
  }

  // ============================================================================
  // DATA LOADING METHODS
  // ============================================================================

  /// Abstract method to load page data
  ///
  /// Implement this in your page state class to load data from the API.
  /// Do not handle loading state or errors - this is done automatically.
  Future<void> loadData();

  /// Safely load data with error handling and loading state management
  ///
  /// This method wraps [loadData()] with:
  /// - Loading state management
  /// - Error handling
  /// - Mounted checks
  /// - User-facing error messages
  Future<void> loadDataSafe() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await loadData();

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingError(err);
      });
    }
  }

  /// Reload data (call this on pull-to-refresh, etc.)
  Future<void> reload() => loadDataSafe();

  // ============================================================================
  // UI BUILDER METHODS
  // ============================================================================

  /// Build error display widget
  ///
  /// Shows error message in a red container at the top of the content
  Widget buildError(BuildContext context) {
    if (_error == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _error!,
        style: TextStyle(color: Colors.red.shade900),
      ),
    );
  }

  /// Build loading indicator
  Widget buildLoading(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  /// Build main content
  ///
  /// Override this method to build your page content.
  /// This is called when data is loaded and there are no errors.
  Widget buildContent(BuildContext context);

  /// Build the complete body with loading, error, and content handling
  ///
  /// This method coordinates displaying loading indicator, errors, and content.
  Widget buildBody(BuildContext context) {
    if (_loading) {
      return buildLoading(context);
    }

    return Column(
      children: [
        buildError(context),
        Expanded(child: buildContent(context)),
      ],
    );
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Set loading state
  void setLoading(bool loading) {
    if (!mounted) return;
    setState(() {
      _loading = loading;
    });
  }

  /// Set error state
  void setError(String? error) {
    if (!mounted) return;
    setState(() {
      _error = error;
    });
  }

  /// Clear error
  void clearError() => setError(null);

  /// Execute an async operation with automatic error handling
  ///
  /// Example:
  /// ```dart
  /// await execute(() async {
  ///   await api.deleteItem(id: itemId, token: token!);
  ///   await loadData();
  /// }, loadingMessage: 'Deleting item...');
  /// ```
  Future<R?> execute<R>(
    Future<R> Function() operation, {
    String? loadingMessage,
    String? successMessage,
    bool reloadAfter = false,
  }) async {
    try {
      setLoading(true);
      clearError();

      final result = await operation();

      if (reloadAfter) {
        await loadData();
      }

      setLoading(false);

      if (successMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );
      }

      return result;
    } catch (err) {
      setLoading(false);
      setError(userFacingError(err));
      return null;
    }
  }
}
