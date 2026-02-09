/// API configuration constants for the Anderson Express application.
///
/// This file centralizes all API-related configuration values including
/// timeouts, retry policies, and endpoint paths.
library;

/// API timeout constants
class ApiTimeouts {
  /// Standard timeout for quick operations (8 seconds)
  /// Used for: authentication, fetching lists, simple CRUD operations
  static const standard = Duration(seconds: 8);

  /// Quick timeout for lightweight operations (5 seconds)
  /// Used for: logout, simple status checks
  static const quick = Duration(seconds: 5);

  /// Medium timeout for moderate operations (10 seconds)
  /// Used for: complex queries, bulk operations
  static const medium = Duration(seconds: 10);

  /// Long timeout for heavy operations (20 seconds)
  /// Used for: creating/updating jobs, file uploads, complex computations
  static const long = Duration(seconds: 20);
}

/// API endpoint configuration
class ApiEndpoints {
  // Authentication endpoints
  static const String login = '/login';
  static const String logout = '/logout';
  static const String register = '/register';

  // User management
  static const String employees = '/employees';
  static const String clients = '/clients';
  static const String profile = '/profile';

  // Job management
  static const String jobs = '/jobs';
  static const String jobAssignments = '/job-assignments';
  static const String jobTasks = '/job-tasks';

  // Locations
  static const String locations = '/locations';

  // Cleaning profiles
  static const String cleaningProfiles = '/cleaning-profiles';
  static const String profileTasks = '/profile-tasks';
  static const String taskDefinitions = '/task-definitions';
  static const String taskRules = '/task-rules';

  // Reports
  static const String cleaningRequests = '/cleaning-requests';
}

/// HTTP status codes
class HttpStatus {
  static const int ok = 200;
  static const int created = 201;
  static const int noContent = 204;
  static const int badRequest = 400;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int conflict = 409;
  static const int internalServerError = 500;
}
