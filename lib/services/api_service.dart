import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/backend_config.dart';
import '../models/auth_user.dart';
import '../models/client.dart';
import '../models/employee.dart';
import '../models/job.dart';
import '../models/job_assignment.dart';
import '../models/job_task.dart';
import '../models/location.dart';
import '../models/task_definition.dart';
import '../models/task_rule.dart';
import 'backend_runtime.dart';

class ApiService {
  ApiService({BackendConfig? backend})
    : _backend = backend ?? BackendRuntime.config;

  final BackendConfig _backend;

  static BackendConfig get rustConfig => BackendConfig.forKind(
    BackendKind.rust,
    host: BackendRuntime.host,
    scheme: BackendRuntime.scheme,
  );

  BackendConfig get backend => _backend;

  Future<String> fetchToken({
    required String email,
    required String password,
  }) async {
    final body =
        'username=${Uri.encodeQueryComponent(email)}&password=${Uri.encodeQueryComponent(password)}';
    final response = await http
        .post(
          Uri.parse('${_backend.baseUrl}/api/v1/auth/token'),
          headers: const {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to fetch auth token');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['access_token']?.toString() ?? '';
    if (token.isEmpty) {
      throw Exception('Auth response missing access_token');
    }
    return token;
  }

  Future<AuthUser> whoAmI({required String bearerToken}) async {
    final response = await http
        .get(
          Uri.parse('${_backend.baseUrl}/api/v1/auth/whoami'),
          headers: _headers(bearerToken),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to fetch current user');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthUser.fromJson(data);
  }

  Future<void> registerUser({
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('${_backend.baseUrl}/api/v1/auth/register'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 204) {
      return;
    }
    _throwIfError(response, fallbackMessage: 'Failed to register user');
  }

  Future<bool> checkHealth(BackendConfig backend) async {
    try {
      final response = await http
          .get(Uri.parse('${backend.baseUrl}${backend.healthPath}'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<Employee>> listEmployees({
    List<String>? employeeStatus,
    String? bearerToken,
  }) async {
    var uri = Uri.parse('${_backend.baseUrl}${_backend.employeesPath}');
    if (employeeStatus != null && employeeStatus.isNotEmpty) {
      final query = employeeStatus
          .map((value) => 'employee_status=${Uri.encodeQueryComponent(value)}')
          .join('&');
      uri = Uri.parse('${uri.toString()}?$query');
    }

    final response = await http
        .get(uri, headers: _headers(bearerToken))
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to list employees');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Employee.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Employee> getEmployee(String employeeId, {String? bearerToken}) async {
    final response = await http
        .get(
          Uri.parse('${_backend.baseUrl}${_backend.employeesPath}/$employeeId'),
          headers: _headers(bearerToken),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to fetch employee');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Employee.fromJson(data);
  }

  Future<Employee> createEmployee(
    EmployeeCreateInput input, {
    String? bearerToken,
  }) async {
    final response = await http
        .post(
          Uri.parse('${_backend.baseUrl}${_backend.employeesPath}'),
          headers: _headers(bearerToken),
          body: jsonEncode(input.toJson()),
        )
        .timeout(const Duration(seconds: 20));

    _throwIfError(response, fallbackMessage: 'Failed to create employee');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Employee.fromJson(data);
  }

  Future<Employee> updateEmployee(
    String employeeId,
    EmployeeUpdateInput input, {
    String? bearerToken,
  }) async {
    final payload = input.toJson();
    if (payload.isEmpty) {
      throw Exception('No update fields provided');
    }

    final response = await http
        .patch(
          Uri.parse('${_backend.baseUrl}${_backend.employeesPath}/$employeeId'),
          headers: _headers(bearerToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to update employee');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Employee.fromJson(data);
  }

  Future<String> deleteEmployee(
    String employeeId, {
    String? bearerToken,
  }) async {
    final response = await http
        .delete(
          Uri.parse('${_backend.baseUrl}${_backend.employeesPath}/$employeeId'),
          headers: _headers(bearerToken),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to delete employee');
    if (response.body.isEmpty) {
      return 'Employee deleted';
    }
    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic> && data['message'] != null) {
      return data['message'].toString();
    }
    return 'Employee deleted';
  }

  Future<List<Client>> listClients({String? bearerToken}) async {
    final response = await http
        .get(
          Uri.parse('${_backend.baseUrl}/api/v1/clients'),
          headers: _headers(bearerToken),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to list clients');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Client.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Client> createClient(
    ClientCreateInput input, {
    String? bearerToken,
  }) async {
    final response = await http
        .post(
          Uri.parse('${_backend.baseUrl}/api/v1/clients'),
          headers: _headers(bearerToken),
          body: jsonEncode(input.toJson()),
        )
        .timeout(const Duration(seconds: 20));

    _throwIfError(response, fallbackMessage: 'Failed to create client');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Client.fromJson(data);
  }

  Future<Client> updateClient(
    String clientId,
    ClientUpdateInput input, {
    String? bearerToken,
  }) async {
    final payload = input.toJson();
    if (payload.isEmpty) {
      throw Exception('No update fields provided');
    }

    final response = await http
        .patch(
          Uri.parse('${_backend.baseUrl}/api/v1/clients/$clientId'),
          headers: _headers(bearerToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to update client');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Client.fromJson(data);
  }

  Future<String> deleteClient(String clientId, {String? bearerToken}) async {
    final response = await http
        .delete(
          Uri.parse('${_backend.baseUrl}/api/v1/clients/$clientId'),
          headers: _headers(bearerToken),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to delete client');
    if (response.body.isEmpty) {
      return 'Client deleted';
    }
    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic> && data['message'] != null) {
      return data['message'].toString();
    }
    return 'Client deleted';
  }

  Future<List<Location>> listLocations({
    int? clientId,
    String? bearerToken,
  }) async {
    var uri = Uri.parse('${_backend.baseUrl}/api/v1/locations');
    if (clientId != null) {
      uri = uri.replace(queryParameters: {'client_id': clientId.toString()});
    }

    final response = await http
        .get(uri, headers: _headers(bearerToken))
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to list locations');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Location.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Location> createLocation(
    LocationCreateInput input, {
    String? bearerToken,
  }) async {
    final response = await http
        .post(
          Uri.parse('${_backend.baseUrl}/api/v1/locations'),
          headers: _headers(bearerToken),
          body: jsonEncode(input.toJson()),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to create location');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Location.fromJson(data);
  }

  Future<Location> updateLocation(
    String locationId,
    LocationUpdateInput input, {
    String? bearerToken,
  }) async {
    final payload = input.toJson();
    if (payload.isEmpty) {
      throw Exception('No update fields provided');
    }

    final response = await http
        .patch(
          Uri.parse('${_backend.baseUrl}/api/v1/locations/$locationId'),
          headers: _headers(bearerToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to update location');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Location.fromJson(data);
  }

  Future<String> deleteLocation(
    String locationId, {
    String? bearerToken,
  }) async {
    final response = await http
        .delete(
          Uri.parse('${_backend.baseUrl}/api/v1/locations/$locationId'),
          headers: _headers(bearerToken),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to delete location');
    if (response.body.isEmpty) {
      return 'Location deleted';
    }
    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic> && data['message'] != null) {
      return data['message'].toString();
    }
    return 'Location deleted';
  }

  Future<List<Job>> listJobs({
    List<String>? statusFilter,
    String? bearerToken,
  }) async {
    var uri = Uri.parse('${_backend.baseUrl}/api/v1/jobs');
    if (statusFilter != null && statusFilter.isNotEmpty) {
      final query = statusFilter
          .map((value) => 'status_filter=${Uri.encodeQueryComponent(value)}')
          .join('&');
      uri = Uri.parse('${uri.toString()}?$query');
    }

    final response = await http
        .get(uri, headers: _headers(bearerToken))
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to list jobs');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Job.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Job> createJob(JobCreateInput input, {String? bearerToken}) async {
    final response = await http
        .post(
          Uri.parse('${_backend.baseUrl}/api/v1/jobs'),
          headers: _headers(bearerToken),
          body: jsonEncode(input.toJson()),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to create job');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Job.fromJson(data);
  }

  Future<List<JobTask>> listJobTasks(
    String jobId, {
    String? bearerToken,
  }) async {
    final response = await http
        .get(
          Uri.parse('${_backend.baseUrl}/api/v1/jobs/$jobId/tasks'),
          headers: _headers(bearerToken),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to list job tasks');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => JobTask.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<JobTask> updateJobTask(
    String jobId,
    String taskId,
    JobTaskUpdateInput input, {
    String? bearerToken,
  }) async {
    final payload = input.toJson();
    if (payload.isEmpty) {
      throw Exception('No update fields provided');
    }

    final response = await http
        .patch(
          Uri.parse('${_backend.baseUrl}/api/v1/jobs/$jobId/tasks/$taskId'),
          headers: _headers(bearerToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to update job task');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return JobTask.fromJson(data);
  }

  Future<List<JobAssignment>> listJobAssignments(
    String jobId, {
    String? bearerToken,
  }) async {
    final response = await http
        .get(
          Uri.parse('${_backend.baseUrl}/api/v1/jobs/$jobId/assignments'),
          headers: _headers(bearerToken),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to list job assignments');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => JobAssignment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<JobAssignment> createJobAssignment(
    String jobId,
    JobAssignmentCreateInput input, {
    String? bearerToken,
  }) async {
    final response = await http
        .post(
          Uri.parse('${_backend.baseUrl}/api/v1/jobs/$jobId/assignments'),
          headers: _headers(bearerToken),
          body: jsonEncode(input.toJson()),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to create job assignment');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return JobAssignment.fromJson(data);
  }

  Future<List<TaskDefinition>> listTaskDefinitions({
    String? bearerToken,
  }) async {
    final response = await http
        .get(
          Uri.parse('${_backend.baseUrl}/api/v1/cleaning/task-definitions'),
          headers: _headers(bearerToken),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to list task definitions');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => TaskDefinition.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TaskDefinition> createTaskDefinition(
    TaskDefinitionCreateInput input, {
    String? bearerToken,
  }) async {
    final response = await http
        .post(
          Uri.parse('${_backend.baseUrl}/api/v1/cleaning/task-definitions'),
          headers: _headers(bearerToken),
          body: jsonEncode(input.toJson()),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(
      response,
      fallbackMessage: 'Failed to create task definition',
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return TaskDefinition.fromJson(data);
  }

  Future<List<TaskRule>> listTaskRules({String? bearerToken}) async {
    final response = await http
        .get(
          Uri.parse('${_backend.baseUrl}/api/v1/cleaning/task-rules'),
          headers: _headers(bearerToken),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to list task rules');
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => TaskRule.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TaskRule> createTaskRule(
    TaskRuleCreateInput input, {
    String? bearerToken,
  }) async {
    final response = await http
        .post(
          Uri.parse('${_backend.baseUrl}/api/v1/cleaning/task-rules'),
          headers: _headers(bearerToken),
          body: jsonEncode(input.toJson()),
        )
        .timeout(const Duration(seconds: 8));

    _throwIfError(response, fallbackMessage: 'Failed to create task rule');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return TaskRule.fromJson(data);
  }

  Map<String, String> _headers(String? bearerToken) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (bearerToken != null && bearerToken.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${bearerToken.trim()}';
    }
    return headers;
  }

  void _throwIfError(
    http.Response response, {
    required String fallbackMessage,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = fallbackMessage;
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        if (data['error'] != null) {
          message = data['error'].toString();
        } else if (data['detail'] != null) {
          message = data['detail'].toString();
        } else if (data['message'] != null) {
          message = data['message'].toString();
        }
      }
    } catch (_) {
      if (response.body.isNotEmpty) {
        message = response.body;
      }
    }

    throw Exception('HTTP ${response.statusCode}: $message');
  }
}
