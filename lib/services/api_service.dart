import 'package:http/http.dart' as http;

class ApiService {
  static const String rustBase = 'http://192.168.1.152:9000';
  static const String pythonBase = 'http://192.168.1.152:8000';
  static const String vaporBase = 'http://192.168.1.152:9001';

  Future<bool> checkHealth(String baseUrl) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/healthz'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
