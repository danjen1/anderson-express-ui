import 'dart:convert';
import 'package:http/http.dart' as http;
import './api_service.dart';
import './auth_session.dart';

/// Service for validating user input (emails, addresses, etc.)
class ValidationService {
  /// Check if email already exists in the database
  /// 
  /// Returns:
  /// - `null` if email is unique (valid)
  /// - Error message string if email already exists
  /// 
  /// [currentEmail] - When editing, skip validation if email hasn't changed
  static Future<String?> validateEmailUniqueness(
    String email, {
    String? currentEmail,
    bool checkClients = true,
    bool checkEmployees = true,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    final currentTrimmed = currentEmail?.trim().toLowerCase();

    // Skip validation if email unchanged
    if (currentTrimmed != null && trimmedEmail == currentTrimmed) {
      return null;
    }

    try {
      final api = ApiService();
      final token = AuthSession.current?.token;

      // Check clients if requested
      if (checkClients) {
        final clients = await api.listClients(bearerToken: token);
        
        final duplicate = clients.any(
          (c) => c.email?.toLowerCase() == trimmedEmail,
        );
        
        if (duplicate) {
          return 'Email already exists in Clients';
        }
      }

      // Check employees if requested
      if (checkEmployees) {
        final employees = await api.listEmployees(bearerToken: token);
        
        final duplicate = employees.any(
          (e) => e.email?.toLowerCase() == trimmedEmail,
        );
        
        if (duplicate) {
          return 'Email already exists in Employees';
        }
      }

      return null; // Email is unique
    } catch (e) {
      // On error, fail open (allow save)
      return null;
    }
  }

  /// Validate and geocode an address
  /// 
  /// Returns:
  /// - `AddressValidationResult.valid()` if address is valid
  /// - `AddressValidationResult.suggestion()` if address found but formatted differently
  /// - `AddressValidationResult.invalid()` if address cannot be verified
  /// - `AddressValidationResult.incomplete()` if partial address provided
  /// 
  /// [address], [city], [state], [zipCode] - Address components
  static Future<AddressValidationResult> validateAddress({
    String? address,
    String? city,
    String? state,
    String? zipCode,
  }) async {
    final addressTrimmed = address?.trim();
    final cityTrimmed = city?.trim();
    final stateTrimmed = state?.trim();
    final zipTrimmed = zipCode?.trim();

    // Check if any address fields are filled
    final hasAnyAddress = [addressTrimmed, cityTrimmed, stateTrimmed, zipTrimmed]
        .any((field) => field != null && field.isNotEmpty);

    if (!hasAnyAddress) {
      // No address provided - that's okay, address is optional
      return AddressValidationResult.valid();
    }

    // Check if all address fields are filled
    final hasAllFields = addressTrimmed != null &&
        addressTrimmed.isNotEmpty &&
        cityTrimmed != null &&
        cityTrimmed.isNotEmpty &&
        stateTrimmed != null &&
        stateTrimmed.isNotEmpty &&
        zipTrimmed != null &&
        zipTrimmed.isNotEmpty;

    if (!hasAllFields) {
      return AddressValidationResult.incomplete(
        message: 'For billing purposes, a complete address is required:\n'
            '• Street Address\n'
            '• City\n'
            '• State\n'
            '• Zip Code\n\n'
            'Either fill all fields or clear them.',
      );
    }

    // Geocode using production-grade approach
    try {
      // Parse street address into components
      final streetParts = _parseStreetAddress(addressTrimmed);
      
      // Try structured search first (most reliable)
      var results = await _geocodeStructured(
        houseNumber: streetParts.houseNumber,
        street: streetParts.street,
        city: cityTrimmed,
        state: stateTrimmed,
        zipCode: zipTrimmed,
      );

      // Fallback: Try without directional/suffix normalization
      if (results.isEmpty && streetParts.hasDirectionalOrSuffix) {
        results = await _geocodeStructured(
          houseNumber: streetParts.houseNumber,
          street: streetParts.rawStreet, // Use original street name
          city: cityTrimmed,
          state: stateTrimmed,
          zipCode: zipTrimmed,
        );
      }

      // Fallback: Try free-text search
      if (results.isEmpty) {
        results = await _geocodeFreeText(
          '$addressTrimmed, $cityTrimmed, $stateTrimmed, $zipTrimmed',
        );
      }

      if (results.isEmpty) {
        return AddressValidationResult.invalid(
          message: 'Unable to verify the address:\n\n'
              '$addressTrimmed\n'
              '$cityTrimmed, $stateTrimmed $zipTrimmed\n\n'
              'For billing purposes, we need a valid address. '
              'Please check the address and try again.',
          enteredAddress: '$addressTrimmed, $cityTrimmed, $stateTrimmed $zipTrimmed',
        );
      }

      // Score results and pick the best match
      final bestMatch = _scoreBestMatch(
        results,
        houseNumber: streetParts.houseNumber,
        street: streetParts.street,
        city: cityTrimmed,
        state: stateTrimmed,
        zipCode: zipTrimmed,
      );

      if (bestMatch == null) {
        return AddressValidationResult.invalid(
          message: 'Unable to verify the address:\n\n'
              '$addressTrimmed\n'
              '$cityTrimmed, $stateTrimmed $zipTrimmed\n\n'
              'For billing purposes, we need a valid address. '
              'Please check the address and try again.',
          enteredAddress: '$addressTrimmed, $cityTrimmed, $stateTrimmed $zipTrimmed',
        );
      }

      final lat = double.parse(bestMatch['lat'] as String);
      final lon = double.parse(bestMatch['lon'] as String);
      final addressDetails = bestMatch['address'] as Map<String, dynamic>?;

      if (addressDetails == null) {
        // No structured data, but we have lat/lon
        return AddressValidationResult.valid(latitude: lat, longitude: lon);
      }

      // Extract structured address components
      String? suggestedStreet;
      String? suggestedCity;
      String? suggestedState;
      String? suggestedZip;

      if (addressDetails['house_number'] != null && addressDetails['road'] != null) {
        suggestedStreet = '${addressDetails['house_number']} ${addressDetails['road']}';
      } else if (addressDetails['road'] != null) {
        suggestedStreet = addressDetails['road'];
      }

      suggestedCity = addressDetails['city'] ?? 
                     addressDetails['town'] ?? 
                     addressDetails['village'];
      suggestedState = addressDetails['state'];
      suggestedZip = addressDetails['postcode'];

      // Check if suggestion differs from input
      if (suggestedStreet != null && suggestedCity != null && suggestedState != null) {
        final enteredNormalized = _normalizeForComparison(
          '$addressTrimmed $cityTrimmed $stateTrimmed $zipTrimmed',
        );
        final suggestedNormalized = _normalizeForComparison(
          '$suggestedStreet $suggestedCity $suggestedState $suggestedZip',
        );

        if (enteredNormalized != suggestedNormalized) {
          return AddressValidationResult.suggestion(
            enteredAddress: '$addressTrimmed, $cityTrimmed, $stateTrimmed $zipTrimmed',
            suggestedAddress: '$suggestedStreet, $suggestedCity, $suggestedState $suggestedZip',
            suggestedStreet: suggestedStreet,
            suggestedCity: suggestedCity,
            suggestedState: suggestedState,
            suggestedZip: suggestedZip,
            latitude: lat,
            longitude: lon,
          );
        }
      }

      // Address matches - valid!
      return AddressValidationResult.valid(latitude: lat, longitude: lon);
    } catch (e) {
      // Network error or timeout - fail open
      return AddressValidationResult.valid();
    }
  }

  /// Parse street address into house number and street name
  static _StreetParts _parseStreetAddress(String address) {
    final trimmed = address.trim();
    
    // Extract house number (digits at start)
    final match = RegExp(r'^(\d+)\s+(.+)$').firstMatch(trimmed);
    if (match == null) {
      return _StreetParts(houseNumber: null, rawStreet: trimmed, street: trimmed);
    }

    final houseNumber = match.group(1);
    final streetPart = match.group(2)!;
    final normalized = _normalizeStreetName(streetPart);

    return _StreetParts(
      houseNumber: houseNumber,
      rawStreet: streetPart,
      street: normalized.street,
      hasDirectionalOrSuffix: normalized.wasModified,
    );
  }

  /// Normalize street name (remove directionals, standardize suffixes)
  static ({String street, bool wasModified}) _normalizeStreetName(String street) {
    var normalized = street.trim();
    var wasModified = false;

    // Remove leading directionals (North, South, East, West, N, S, E, W)
    final withoutLeadingDir = normalized.replaceFirst(
      RegExp(r'^(North|South|East|West|N|S|E|W)\s+', caseSensitive: false),
      '',
    );
    if (withoutLeadingDir != normalized) {
      normalized = withoutLeadingDir;
      wasModified = true;
    }

    // Remove trailing directionals
    final withoutTrailingDir = normalized.replaceFirst(
      RegExp(r'\s+(North|South|East|West|N|S|E|W)$', caseSensitive: false),
      '',
    );
    if (withoutTrailingDir != normalized) {
      normalized = withoutTrailingDir;
      wasModified = true;
    }

    // Standardize suffixes
    final suffixes = {
      RegExp(r'\b(Street|St\.?)$', caseSensitive: false): 'St',
      RegExp(r'\b(Avenue|Ave\.?)$', caseSensitive: false): 'Ave',
      RegExp(r'\b(Circle|Cir\.?|Circ\.?)$', caseSensitive: false): 'Cir',
      RegExp(r'\b(Drive|Dr\.?)$', caseSensitive: false): 'Dr',
      RegExp(r'\b(Boulevard|Blvd\.?)$', caseSensitive: false): 'Blvd',
      RegExp(r'\b(Road|Rd\.?)$', caseSensitive: false): 'Rd',
      RegExp(r'\b(Lane|Ln\.?)$', caseSensitive: false): 'Ln',
      RegExp(r'\b(Court|Ct\.?)$', caseSensitive: false): 'Ct',
      RegExp(r'\b(Way|Wy\.?)$', caseSensitive: false): 'Way',
      RegExp(r'\b(Place|Pl\.?)$', caseSensitive: false): 'Pl',
    };

    for (final entry in suffixes.entries) {
      final withSuffix = normalized.replaceFirst(entry.key, entry.value);
      if (withSuffix != normalized) {
        normalized = withSuffix;
        wasModified = true;
        break;
      }
    }

    return (street: normalized, wasModified: wasModified);
  }

  /// Geocode using structured parameters (most reliable)
  static Future<List<Map<String, dynamic>>> _geocodeStructured({
    String? houseNumber,
    required String street,
    required String city,
    required String state,
    String? zipCode,
  }) async {
    try {
      final params = {
        'street': houseNumber != null ? '$houseNumber $street' : street,
        'city': city,
        'state': state,
        if (zipCode != null) 'postalcode': zipCode,
        'country': 'US',
        'format': 'json',
        'addressdetails': '1',
        'limit': '5',
        'dedupe': '1',
      };

      final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Geocode using free-text query (fallback)
  static Future<List<Map<String, dynamic>>> _geocodeFreeText(String query) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'limit': '5',
        'dedupe': '1',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Score results and return best match
  static Map<String, dynamic>? _scoreBestMatch(
    List<Map<String, dynamic>> results, {
    String? houseNumber,
    required String street,
    required String city,
    required String state,
    String? zipCode,
  }) {
    if (results.isEmpty) return null;

    // Score each result
    final scored = results.map((result) {
      var score = 0;
      final address = result['address'] as Map<String, dynamic>?;
      
      if (address == null) return (result: result, score: 0);

      // House number match (critical)
      if (houseNumber != null && address['house_number'] == houseNumber) {
        score += 100;
      }

      // Street name match (important)
      final resultRoad = address['road']?.toString().toLowerCase() ?? '';
      final inputStreet = street.toLowerCase();
      if (resultRoad.contains(inputStreet) || inputStreet.contains(resultRoad)) {
        score += 50;
      }

      // City match
      final resultCity = (address['city'] ?? address['town'] ?? address['village'])
          ?.toString().toLowerCase() ?? '';
      if (resultCity == city.toLowerCase()) {
        score += 30;
      }

      // State match
      final resultState = address['state']?.toString().toLowerCase() ?? '';
      if (resultState == state.toLowerCase()) {
        score += 20;
      }

      // Zip code match
      if (zipCode != null && address['postcode'] == zipCode) {
        score += 10;
      }

      return (result: result, score: score);
    }).toList();

    // Sort by score descending
    scored.sort((a, b) => b.score.compareTo(a.score));

    // Return best match if score is reasonable
    final best = scored.first;
    return best.score >= 50 ? best.result : null;
  }

  /// Normalize address for comparison (lowercase, remove punctuation, extra spaces)
  static String _normalizeForComparison(String address) {
    return address
        .toLowerCase()
        .replaceAll(RegExp(r'[.,\-]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

/// Street address components
class _StreetParts {
  final String? houseNumber;
  final String rawStreet;
  final String street;
  final bool hasDirectionalOrSuffix;

  _StreetParts({
    this.houseNumber,
    required this.rawStreet,
    required this.street,
    this.hasDirectionalOrSuffix = false,
  });
}

/// Result of address validation
class AddressValidationResult {
  final AddressValidationStatus status;
  final String? message;
  final String? enteredAddress;
  final String? suggestedAddress;
  final String? suggestedStreet;
  final String? suggestedCity;
  final String? suggestedState;
  final String? suggestedZip;
  final double? latitude;
  final double? longitude;

  AddressValidationResult._({
    required this.status,
    this.message,
    this.enteredAddress,
    this.suggestedAddress,
    this.suggestedStreet,
    this.suggestedCity,
    this.suggestedState,
    this.suggestedZip,
    this.latitude,
    this.longitude,
  });

  factory AddressValidationResult.valid({
    double? latitude,
    double? longitude,
  }) {
    return AddressValidationResult._(
      status: AddressValidationStatus.valid,
      latitude: latitude,
      longitude: longitude,
    );
  }

  factory AddressValidationResult.suggestion({
    required String enteredAddress,
    required String suggestedAddress,
    String? suggestedStreet,
    String? suggestedCity,
    String? suggestedState,
    String? suggestedZip,
    double? latitude,
    double? longitude,
  }) {
    return AddressValidationResult._(
      status: AddressValidationStatus.suggestion,
      enteredAddress: enteredAddress,
      suggestedAddress: suggestedAddress,
      suggestedStreet: suggestedStreet,
      suggestedCity: suggestedCity,
      suggestedState: suggestedState,
      suggestedZip: suggestedZip,
      latitude: latitude,
      longitude: longitude,
    );
  }

  factory AddressValidationResult.invalid({
    required String message,
    String? enteredAddress,
  }) {
    return AddressValidationResult._(
      status: AddressValidationStatus.invalid,
      message: message,
      enteredAddress: enteredAddress,
    );
  }

  factory AddressValidationResult.incomplete({
    required String message,
  }) {
    return AddressValidationResult._(
      status: AddressValidationStatus.incomplete,
      message: message,
    );
  }
}

enum AddressValidationStatus {
  valid,
  suggestion,
  invalid,
  incomplete,
}
