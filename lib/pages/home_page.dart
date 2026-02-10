import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/client.dart';
import '../models/cleaning_request.dart';
import '../models/employee.dart';
import '../models/job.dart';
import '../models/job_assignment.dart';
import '../models/location.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../theme/crud_modal_theme.dart';
import '../utils/date_format.dart';
import '../widgets/backend_banner.dart';
import '../widgets/brand_app_bar_title.dart';
import '../widgets/employee/employee_dashboard_cards.dart';
import '../widgets/employee/employee_job_card.dart';
import '../widgets/profile_menu_button.dart';
import '../widgets/theme_toggle_button.dart';
import '../utils/navigation_extensions.dart';
import '../utils/date_range_utils.dart';
import '../utils/photo_picker_utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color _lightPrimary = Color(0xFF296273);
  static const Color _lightSecondary = Color(0xFFA8D6F7);
  static const Color _lightAccent = Color(0xFF442E6F);
  static const Color _lightCta = Color(0xFFEE7E32);
  static const Color _darkBg = Color(0xFF2C2C2C);
  static const Color _darkText = Color(0xFFE4E4E4);
  static const Color _darkAccent1 = Color(0xFFA8DADC);
  static const Color _darkAccent2 = Color(0xFFFFC1CC);

  bool loading = true;
  String? error;
  List<Job> _adminPendingJobs = const [];
  List<Job> _cleanerJobs = const [];
  List<Location> _employeeLocations = const [];
  Employee? _employeeProfile;
  DateTimeRange _employeeDateRange = DateRangeUtils.currentWeekRange();
  List<Location> _clientLocations = const [];
  List<Job> _clientJobs = const [];
  Client? _clientProfile;
  DateTimeRange _clientDateRange = DateRangeUtils.last30DaysRange();
  Map<String, List<JobAssignment>> _clientAssignmentsByJob = const {};
  bool _photoHovering = false;
  bool _uploadingPhoto = false;

  AuthSessionState? get _session => AuthSession.current;
  bool get _isAdmin => _session?.user.isAdmin == true;
  bool get _isEmployee => _session?.user.isEmployee == true;
  bool get _isClient => _session?.user.isClient == true;

  @override
  void initState() {
    super.initState();
    if (_session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.navigateToLogin();
      });
      return;
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final valid = await _ensureSessionIsValid();
    if (!mounted) return;
    if (!valid) {
      context.navigateToLogin();
      return;
    }
    await _loadDashboard();
  }

  Future<bool> _ensureSessionIsValid() async {
    final session = _session;
    if (session == null) {
      return false;
    }
    try {
      final user = await ApiService().whoAmI(bearerToken: session.token);
      AuthSession.set(
        AuthSessionState(
          token: session.token,
          user: user,
          loginEmail: session.loginEmail,
          loginPassword: session.loginPassword,
        ),
      );
      return true;
    } catch (_) {
      final email = session.loginEmail;
      final password = session.loginPassword;
      if (email == null || password == null) {
        AuthSession.clear();
        return false;
      }
      try {
        final api = ApiService();
        final token = await api.fetchToken(email: email, password: password);
        final user = await api.whoAmI(bearerToken: token);
        AuthSession.set(
          AuthSessionState(
            token: token,
            user: user,
            loginEmail: email,
            loginPassword: password,
          ),
        );
        return true;
      } catch (_) {
        AuthSession.clear();
        return false;
      }
    }
  }

  Future<void> _loadDashboard() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = ApiService();
      final token = _session?.token ?? '';
      List<Job> adminPending = const [];
      List<Job> cleanerJobs = const [];
      List<Location> employeeLocations = const [];
      Employee? employeeProfile;
      List<Location> clientLocations = const [];
      List<Job> clientJobs = const [];
      Client? clientProfile;
      Map<String, List<JobAssignment>> clientAssignmentsByJob = const {};

      if (_isAdmin) {
        adminPending = await api.listJobs(
          statusFilter: const ['pending'],
          bearerToken: token,
        );
      } else if (_isEmployee) {
        cleanerJobs = await api.listJobs(bearerToken: token);
        employeeLocations = const [];
        try {
          final subjectId = _session?.user.subjectId ?? '';
          if (subjectId.isNotEmpty) {
            employeeProfile = await api.getEmployee(
              subjectId,
              bearerToken: token,
            );
          }
        } catch (_) {
          employeeProfile = null;
        }
      } else if (_isClient) {
        final subjectId = _session?.user.subjectId ?? '';
        if (subjectId.isNotEmpty) {
          try {
            clientProfile = await api.getClient(subjectId, bearerToken: token);
          } catch (_) {
            clientProfile = null;
          }
        }
        clientLocations = await api.listLocations(bearerToken: token);
        clientJobs = await api.listJobs(bearerToken: token);

        final assignmentsMap = <String, List<JobAssignment>>{};
        for (final job in clientJobs) {
          try {
            final assignments = await api.listJobAssignments(
              job.id,
              bearerToken: token,
            );
            assignmentsMap[job.id] = assignments;
          } catch (_) {
            assignmentsMap[job.id] = const [];
          }
        }
        clientAssignmentsByJob = assignmentsMap;
      }

      if (!mounted) return;
      setState(() {
        _adminPendingJobs = adminPending;
        _cleanerJobs = cleanerJobs;
        _employeeLocations = employeeLocations;
        _employeeProfile = employeeProfile;
        _clientLocations = clientLocations;
        _clientJobs = clientJobs;
        _clientProfile = clientProfile;
        _clientAssignmentsByJob = clientAssignmentsByJob;
      });
    } catch (loadError) {
      if (!mounted) return;
      setState(() {
        error = loadError.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Widget _cardList({
    required String title,
    required String empty,
    required List<Widget> children,
    Color? cardColor,
    Color? borderColor,
    Color? titleColor,
    Color? emptyColor,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        color: cardColor,
        shape: borderColor == null
            ? null
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor),
              ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 0.2,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 10),
              if (children.isEmpty)
                Text(
                  empty,
                  style: TextStyle(color: emptyColor ?? Colors.black54),
                ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  DateTime? _parseJobDate(String raw) {
    return parseFlexibleDate(raw);
  }

  bool _isCompletedStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'complete' ||
        normalized == 'completed' ||
        normalized == 'done';
  }

  bool _isCancelledStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'cancelled' || normalized == 'canceled';
  }

  List<Job> get _employeeAssignedJobs {
    final jobs = _cleanerJobs.where((job) {
      if (_isCompletedStatus(job.status) || _isCancelledStatus(job.status)) {
        return false;
      }
      final status = job.status.trim().toLowerCase();
      return status == 'assigned' ||
          status == 'in_progress' ||
          status == 'in-progress' ||
          status == 'in progress';
    }).toList();
    jobs.sort((a, b) {
      final ad = _parseJobDate(a.scheduledDate);
      final bd = _parseJobDate(b.scheduledDate);
      if (ad == null && bd == null) return a.jobNumber.compareTo(b.jobNumber);
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    return jobs;
  }

  List<Job> get _employeeCompletedJobs {
    final start = DateTime(
      _employeeDateRange.start.year,
      _employeeDateRange.start.month,
      _employeeDateRange.start.day,
    );
    final end = DateTime(
      _employeeDateRange.end.year,
      _employeeDateRange.end.month,
      _employeeDateRange.end.day,
      23,
      59,
      59,
    );
    final jobs = _cleanerJobs.where((job) {
      if (!_isCompletedStatus(job.status)) return false;
      final date = _parseJobDate(job.completedAt ?? job.scheduledDate);
      if (date == null) return true;
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
    jobs.sort((a, b) {
      final ad = _parseJobDate(a.scheduledDate);
      final bd = _parseJobDate(b.scheduledDate);
      if (ad == null && bd == null) return a.jobNumber.compareTo(b.jobNumber);
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return jobs;
  }

  List<Job> get _employeeAssignedJobsInRange {
    final start = DateTime(
      _employeeDateRange.start.year,
      _employeeDateRange.start.month,
      _employeeDateRange.start.day,
    );
    final end = DateTime(
      _employeeDateRange.end.year,
      _employeeDateRange.end.month,
      _employeeDateRange.end.day,
      23,
      59,
      59,
    );
    return _employeeAssignedJobs.where((job) {
      final date = _parseJobDate(job.scheduledDate);
      if (date == null) return true;
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  Location? _locationForJob(Job job) {
    if (job.locationAddress != null ||
        job.locationCity != null ||
        job.locationState != null ||
        job.locationZipCode != null) {
      return Location(
        id: job.locationId.toString(),
        locationNumber: '',
        status: '',
        type: '',
        clientId: 0,
        address: job.locationAddress,
        city: job.locationCity,
        state: job.locationState,
        zipCode: job.locationZipCode,
        latitude: job.locationLatitude,
        longitude: job.locationLongitude,
      );
    }
    for (final location in _employeeLocations) {
      if (location.id == job.locationId.toString()) return location;
    }
    return null;
  }

  String _distanceHintForJob(Job job) {
    final preciseMiles = _distanceMilesForJob(job);
    if (preciseMiles != null) {
      return '${preciseMiles.toStringAsFixed(1)} mi away';
    }
    final location = _locationForJob(job);
    final employee = _employeeProfile;
    if (location == null || employee == null) {
      return 'Distance unavailable';
    }
    final locationLat = location.latitude;
    final locationLon = location.longitude;
    final employeeLat = employee.latitude;
    final employeeLon = employee.longitude;
    if (locationLat != null &&
        locationLon != null &&
        employeeLat != null &&
        employeeLon != null) {
      final miles = _haversineMiles(
        employeeLat,
        employeeLon,
        locationLat,
        locationLon,
      );
      return '${miles.toStringAsFixed(1)} mi away';
    }
    final employeeZip = employee.zipCode?.trim() ?? '';
    final locationZip = location.zipCode?.trim() ?? '';
    if (employeeZip.isNotEmpty && locationZip.isNotEmpty) {
      if (employeeZip == locationZip) return 'Same ZIP area';
      return 'Different ZIP area';
    }
    final employeeCity = employee.city?.trim().toLowerCase() ?? '';
    final employeeState = employee.state?.trim().toLowerCase() ?? '';
    final locationCity = location.city?.trim().toLowerCase() ?? '';
    final locationState = location.state?.trim().toLowerCase() ?? '';
    if (employeeCity.isNotEmpty &&
        employeeState.isNotEmpty &&
        employeeCity == locationCity &&
        employeeState == locationState) {
      return 'Same city';
    }
    return 'Distance unavailable';
  }

  double? _distanceMilesForJob(Job job) {
    final location = _locationForJob(job);
    final employee = _employeeProfile;
    if (location == null || employee == null) {
      return null;
    }
    final locationLat = location.latitude;
    final locationLon = location.longitude;
    final employeeLat = employee.latitude;
    final employeeLon = employee.longitude;
    if (locationLat == null ||
        locationLon == null ||
        employeeLat == null ||
        employeeLon == null) {
      return null;
    }
    return _haversineMiles(employeeLat, employeeLon, locationLat, locationLon);
  }

  double _haversineMiles(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusMiles = 3958.8;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusMiles * c;
  }

  double _toRadians(double degrees) => degrees * (3.141592653589793 / 180.0);

  double _jobGridCardWidth(double maxWidth) {
    const spacing = 10.0;
    final columns = maxWidth >= 1200
        ? 4
        : maxWidth >= 900
        ? 3
        : maxWidth >= 620
        ? 2
        : 1;
    final computed = (maxWidth - (spacing * (columns - 1))) / columns;
    return computed.clamp(220.0, 320.0);
  }

  Future<void> _pickEmployeeStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _employeeDateRange.start,
      firstDate: DateTime(now.year - 2),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      final end = picked.isAfter(_employeeDateRange.end)
          ? picked
          : _employeeDateRange.end;
      _employeeDateRange = DateTimeRange(start: picked, end: end);
    });
  }

  Future<void> _pickEmployeeEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _employeeDateRange.end,
      firstDate: DateTime(now.year - 2),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      final start = picked.isBefore(_employeeDateRange.start)
          ? picked
          : _employeeDateRange.start;
      _employeeDateRange = DateTimeRange(start: start, end: picked);
    });
  }

  Future<void> _pickClientStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _clientDateRange.start,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      final end = picked.isAfter(_clientDateRange.end)
          ? picked
          : _clientDateRange.end;
      _clientDateRange = DateTimeRange(start: picked, end: end);
    });
  }

  Future<void> _pickClientEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _clientDateRange.end,
      firstDate: DateTime(now.year - 3),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      final start = picked.isBefore(_clientDateRange.start)
          ? picked
          : _clientDateRange.start;
      _clientDateRange = DateTimeRange(start: start, end: picked);
    });
  }

  List<Job> get _clientCompletedJobs {
    final start = DateTime(
      _clientDateRange.start.year,
      _clientDateRange.start.month,
      _clientDateRange.start.day,
    );
    final end = DateTime(
      _clientDateRange.end.year,
      _clientDateRange.end.month,
      _clientDateRange.end.day,
      23,
      59,
      59,
    );
    final jobs = _clientJobs.where((job) {
      if (!_isCompletedStatus(job.status)) return false;
      final date = _parseJobDate(job.completedAt ?? job.scheduledDate);
      if (date == null) return true;
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
    jobs.sort((a, b) {
      final ad = _parseJobDate(a.completedAt ?? a.scheduledDate);
      final bd = _parseJobDate(b.completedAt ?? b.scheduledDate);
      if (ad == null && bd == null) return a.jobNumber.compareTo(b.jobNumber);
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return jobs;
  }

  double _clientAverageFrequencyDays(List<Job> completedJobs) {
    if (completedJobs.length < 2) return 0;
    final dates =
        completedJobs
            .map((job) => _parseJobDate(job.completedAt ?? job.scheduledDate))
            .whereType<DateTime>()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    if (dates.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < dates.length; i++) {
      total += dates[i - 1].difference(dates[i]).inHours.abs() / 24.0;
    }
    return total / (dates.length - 1);
  }

  Future<void> _pickClientLocationPhoto(Location? location) async {
    if (location == null) return;
    final token = _session?.token ?? '';
    if (token.isEmpty) return;
    
    final dataUrl = await showPhotoPickerDialog(
      context,
      title: 'Update Location Photo',
      message: 'Select a new photo for your location.',
    );
    
    if (dataUrl == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      await ApiService().updateLocation(
        location.id,
        LocationUpdateInput(photoUrl: dataUrl),
        bearerToken: token,
      );
      await _loadDashboard();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location photo updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Photo upload failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  List<JobAssignment> _assignmentsForJob(String jobId) {
    return _clientAssignmentsByJob[jobId] ?? const [];
  }

  String _deviceMapLabel() {
    return 'Open in Maps';
  }

  Uri? _jobMapUri(Job job) {
    final addressParts = [
      job.locationAddress?.trim() ?? '',
      job.locationCity?.trim() ?? '',
      job.locationState?.trim() ?? '',
      job.locationZipCode?.trim() ?? '',
    ].where((p) => p.isNotEmpty).toList();
    final fullAddress = addressParts.join(', ');

    final hasCoords =
        job.locationLatitude != null && job.locationLongitude != null;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      if (hasCoords) {
        return Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${job.locationLatitude},${job.locationLongitude}',
        );
      }
      if (fullAddress.isNotEmpty) {
        return Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(fullAddress)}',
        );
      }
      return null;
    }
    if (hasCoords) {
      return Uri.parse(
        'http://maps.apple.com/?ll=${job.locationLatitude},${job.locationLongitude}',
      );
    }
    if (fullAddress.isNotEmpty) {
      return Uri.parse(
        'http://maps.apple.com/?q=${Uri.encodeComponent(fullAddress)}',
      );
    }
    return null;
  }

  Future<void> _openJobInMaps(Job job) async {
    final uri = _jobMapUri(job);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No address available for map link')),
      );
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to open map link: $uri')));
    }
  }

  Widget _buildAdminLanding() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/admin'),
              icon: const Icon(Icons.badge),
              label: const Text('Employees'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/clients'),
              icon: const Icon(Icons.business),
              label: const Text('Clients'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/locations'),
              icon: const Icon(Icons.location_on),
              label: const Text('Locations'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/jobs'),
              icon: const Icon(Icons.work),
              label: const Text('Jobs'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _cardList(
          title: 'Pending Jobs Overview',
          empty: 'No pending jobs',
          children: _adminPendingJobs
              .map(
                (job) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.schedule),
                  title: Text(job.jobNumber),
                  subtitle: Text(
                    'Location #${job.locationId} • ${formatDateMdy(job.scheduledDate)}',
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildCleanerLanding() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final assigned = _employeeAssignedJobsInRange;
    final completed = _employeeCompletedJobs;
    final employeeDisplayName =
        (_employeeProfile?.name.trim().isNotEmpty ?? false)
        ? _employeeProfile!.name.trim()
        : 'Employee';
    final assignedMinutes = assigned
        .where((j) => j.estimatedDurationMinutes != null)
        .fold<int>(0, (sum, j) => sum + (j.estimatedDurationMinutes ?? 0));
    final completedMinutes = completed
        .where((j) => j.actualDurationMinutes != null)
        .fold<int>(0, (sum, j) => sum + (j.actualDurationMinutes ?? 0));
    final completedDistanceMiles = completed.fold<double>(0, (sum, job) {
      final miles = _distanceMilesForJob(job);
      return miles == null ? sum : sum + miles;
    });
    final sectionCardBg = dark ? const Color(0xFF2F313A) : null;
    final sectionBorder = dark ? const Color(0xFF4A4D5A) : null;
    final sectionTitleColor = dark ? _darkAccent1 : null;
    final sectionEmptyColor = dark ? const Color(0xFFBFC3CC) : null;
    final panelBg = dark ? const Color(0xFF333740) : const Color(0xFFE8F3FA);
    final panelBorder = dark ? const Color(0xFF4A525F) : _lightSecondary;
    final panelTitle = dark ? const Color(0xFFB39CD0) : _lightAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: panelBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: panelBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final controls = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Date Range',
                      style: TextStyle(
                        color: panelTitle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickEmployeeStartDate,
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(
                        '${_employeeDateRange.start.month}-${_employeeDateRange.start.day}-${_employeeDateRange.start.year}',
                      ),
                    ),
                    const Text('to'),
                    OutlinedButton.icon(
                      onPressed: _pickEmployeeEndDate,
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(
                        '${_employeeDateRange.end.month}-${_employeeDateRange.end.day}-${_employeeDateRange.end.year}',
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(
                        () => _employeeDateRange = DateRangeUtils.currentWeekRange(),
                      ),
                      child: const Text('Current week'),
                    ),
                  ],
                );

                final welcome = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _employeeWelcomeAvatar(),
                    const SizedBox(width: 10),
                    Text(
                      'Welcome, $employeeDisplayName',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: panelTitle,
                      ),
                    ),
                  ],
                );

                if (constraints.maxWidth < 900) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [welcome, const SizedBox(height: 10), controls],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: welcome),
                    const Spacer(),
                    controls,
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        EmployeeJobDashboardCard(
          dark: dark,
          assignedCount: assigned.length,
          assignedHours: assigned.isEmpty
              ? 'N/A'
              : '${assignedMinutes ~/ 60}h ${assignedMinutes % 60}m',
          completedCount: completed.length,
          completedHours: completed.isEmpty
              ? 'N/A'
              : '${completedMinutes ~/ 60}h ${completedMinutes % 60}m',
          totalDistanceMiles: completed.isEmpty
              ? 'N/A'
              : '${completedDistanceMiles.toStringAsFixed(1)} mi',
          cardColor: sectionCardBg,
          borderColor: sectionBorder,
          titleColor: sectionTitleColor,
        ),
        const SizedBox(height: 12),
        _cardList(
          title: 'Assigned Jobs',
          empty: 'No jobs assigned',
          cardColor: sectionCardBg,
          borderColor: sectionBorder,
          titleColor: sectionTitleColor,
          emptyColor: sectionEmptyColor,
          children: [
            if (assigned.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = _jobGridCardWidth(constraints.maxWidth);
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: assigned
                        .map(
                          (job) => EmployeeJobCard(
                            job: job,
                            completedCard: false,
                            cardWidth: cardWidth,
                            primaryDateLabel:
                                'Scheduled: ${formatDateMdy(job.scheduledDate)}',
                            distanceLabel: _distanceHintForJob(job),
                            mapsLabel: _deviceMapLabel(),
                            onOpenMaps: () => _openJobInMaps(job),
                            onOpenDetails: () => Navigator.pushNamed(
                              context,
                              '/jobs',
                              arguments: <String, dynamic>{
                                'jobId': job.id,
                                'source': 'employee_home',
                              },
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        _cardList(
          title: 'Completed Jobs',
          empty: 'No completed jobs in selected range',
          cardColor: sectionCardBg,
          borderColor: sectionBorder,
          titleColor: sectionTitleColor,
          emptyColor: sectionEmptyColor,
          children: [
            if (completed.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = _jobGridCardWidth(constraints.maxWidth);
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: completed
                        .map(
                          (job) => EmployeeJobCard(
                            job: job,
                            completedCard: true,
                            cardWidth: cardWidth,
                            primaryDateLabel:
                                'Completed: ${formatDateMdy(job.completedAt ?? job.scheduledDate)}',
                            distanceLabel: _distanceHintForJob(job),
                            onOpenMaps: () => _openJobInMaps(job),
                            onOpenDetails: () => Navigator.pushNamed(
                              context,
                              '/jobs',
                              arguments: <String, dynamic>{
                                'jobId': job.id,
                                'source': 'employee_home',
                              },
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _employeeWelcomeAvatar() {
    final photoUrl = _employeeProfile?.photoUrl?.trim() ?? '';
    ImageProvider<Object> provider;
    if (photoUrl.startsWith('/assets/')) {
      provider = AssetImage(photoUrl.substring(1));
    } else if (photoUrl.isNotEmpty) {
      provider = NetworkImage(photoUrl);
    } else {
      provider = const AssetImage(
        'assets/images/profiles/employee_john_cleaner.png',
      );
    }
    return CircleAvatar(
      radius: 27,
      backgroundColor: const Color(0xFFA8D6F7),
      backgroundImage: provider,
    );
  }

  Widget _buildClientLanding() {
    final completedJobs = _clientCompletedJobs;
    final scheduledJobs = _clientJobs.where((job) {
      final status = job.status.trim().toLowerCase();
      return status == 'assigned' ||
          status == 'in_progress' ||
          status == 'in-progress' ||
          status == 'in progress';
    }).length;
    final start = DateTime(
      _clientDateRange.start.year,
      _clientDateRange.start.month,
      _clientDateRange.start.day,
    );
    final end = DateTime(
      _clientDateRange.end.year,
      _clientDateRange.end.month,
      _clientDateRange.end.day,
      23,
      59,
      59,
    );
    final jobsInRange =
        _clientJobs.where((job) {
          final status = job.status.trim().toLowerCase();
          final date = _parseJobDate(
            _isCompletedStatus(status)
                ? (job.completedAt ?? job.scheduledDate)
                : job.scheduledDate,
          );
          if (date == null) return true;
          return !date.isBefore(start) && !date.isAfter(end);
        }).toList()..sort((a, b) {
          final ad = _parseJobDate(
            _isCompletedStatus(a.status)
                ? (a.completedAt ?? a.scheduledDate)
                : a.scheduledDate,
          );
          final bd = _parseJobDate(
            _isCompletedStatus(b.status)
                ? (b.completedAt ?? b.scheduledDate)
                : b.scheduledDate,
          );
          if (ad == null && bd == null) {
            return a.jobNumber.compareTo(b.jobNumber);
          }
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        });
    final averageDurationMinutes = completedJobs
        .where((job) => job.actualDurationMinutes != null)
        .fold<int>(0, (sum, job) => sum + (job.actualDurationMinutes ?? 0));
    final durationCount = completedJobs
        .where((job) => job.actualDurationMinutes != null)
        .length;
    final averageDuration = durationCount == 0
        ? 'N/A'
        : '${(averageDurationMinutes ~/ durationCount) ~/ 60}h ${(averageDurationMinutes ~/ durationCount) % 60}m';
    final averageFrequencyDays = _clientAverageFrequencyDays(completedJobs);
    final nextCleaning =
        _clientJobs
            .where((job) => !_isCompletedStatus(job.status))
            .map((job) => _parseJobDate(job.scheduledDate))
            .whereType<DateTime>()
            .toList()
          ..sort((a, b) => a.compareTo(b));
    final primaryLocation = _clientLocations.isNotEmpty
        ? _clientLocations.first
        : null;
    final welcomeName = _clientProfile?.name.trim().isNotEmpty == true
        ? _clientProfile!.name.trim()
        : 'Client';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final panelBg = dark ? const Color(0xFF333740) : const Color(0xFFE8F3FA);
    final panelBorder = dark ? const Color(0xFF4A525F) : _lightSecondary;
    final panelTitle = dark ? _darkAccent1 : _lightAccent;
    final panelText = dark ? _darkText : _lightPrimary;
    final chipBg = dark ? const Color(0xFF5B4432) : const Color(0xFFFFEDD9);
    final chipBorder = dark ? const Color(0xFFE9A36C) : const Color(0xFFEE7E32);
    final chipText = dark ? _darkText : _lightAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: panelBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: panelBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 640) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, $welcomeName',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: panelTitle,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _requestCleaningButton(dark),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Welcome, $welcomeName',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: panelTitle,
                        ),
                      ),
                    ),
                    _requestCleaningButton(dark),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: panelBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: panelBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Center(
              child: _buildClientLocationPhoto(
                primaryLocation,
                large: true,
                onEditPhoto: () => _pickClientLocationPhoto(primaryLocation),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: Card(
            color: panelBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: panelBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final chipsRow = SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _clientStatChip(
                              label: 'Next Cleaning',
                              value: nextCleaning.isEmpty
                                  ? 'Not scheduled'
                                  : '${nextCleaning.first.month}-${nextCleaning.first.day}-${nextCleaning.first.year}',
                              bg: chipBg,
                              text: chipText,
                              border: chipBorder,
                              width: 230,
                            ),
                            const SizedBox(width: 10),
                            _clientStatChip(
                              label: 'Scheduled Jobs',
                              value: scheduledJobs.toString(),
                              bg: chipBg,
                              text: chipText,
                              border: chipBorder,
                              width: 230,
                            ),
                            const SizedBox(width: 10),
                            _clientStatChip(
                              label: 'Average Duration',
                              value: averageDuration,
                              bg: chipBg,
                              text: chipText,
                              border: chipBorder,
                              width: 230,
                            ),
                            const SizedBox(width: 10),
                            _clientStatChip(
                              label: 'Cleaning Frequency',
                              value: averageFrequencyDays == 0
                                  ? 'N/A'
                                  : 'Every ${averageFrequencyDays.toStringAsFixed(1)} days',
                              bg: chipBg,
                              text: chipText,
                              border: chipBorder,
                              width: 260,
                            ),
                          ],
                        ),
                      );
                      final jobCards = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (jobsInRange.isEmpty)
                            Text(
                              'No jobs in selected filter range',
                              style: TextStyle(color: panelText),
                            )
                          else
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.start,
                              children: jobsInRange
                                  .map(
                                    (job) =>
                                        _clientJobCard(job: job, dark: dark),
                                  )
                                  .toList(),
                            ),
                        ],
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(child: chipsRow),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Job Filter',
                                style: TextStyle(
                                  color: panelText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _pickClientStartDate,
                                icon: const Icon(Icons.date_range, size: 16),
                                label: Text(
                                  '${_clientDateRange.start.month}-${_clientDateRange.start.day}-${_clientDateRange.start.year}',
                                ),
                              ),
                              const Text('to'),
                              OutlinedButton.icon(
                                onPressed: _pickClientEndDate,
                                icon: const Icon(Icons.date_range, size: 16),
                                label: Text(
                                  '${_clientDateRange.end.month}-${_clientDateRange.end.day}-${_clientDateRange.end.year}',
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _clientDateRange = DateRangeUtils.last30DaysRange();
                                  });
                                },
                                child: const Text('Default range'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          jobCards,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _requestCleaningButton(bool dark) {
    return FilledButton.icon(
      onPressed: _showScheduleRequestModal,
      icon: const Icon(Icons.add_task),
      label: const Text('Request to schedule a cleaning'),
      style: FilledButton.styleFrom(
        backgroundColor: dark ? const Color(0xFFB39CD0) : _lightPrimary,
        foregroundColor: dark ? _darkBg : Colors.white,
      ),
    );
  }

  String _formatLocationAddress(Location? location) {
    if (location == null) return 'No location on file';
    final parts = [
      location.address?.trim() ?? '',
      location.city?.trim() ?? '',
      location.state?.trim() ?? '',
      location.zipCode?.trim() ?? '',
    ].where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'No location on file';
    return parts.join(', ');
  }

  Widget _buildClientLocationPhoto(
    Location? location, {
    bool large = false,
    VoidCallback? onEditPhoto,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final photoUrl = location?.photoUrl?.trim() ?? '';
    Widget? image;
    if (photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('data:image/')) {
        final comma = photoUrl.indexOf(',');
        if (comma > 0 && comma < photoUrl.length - 1) {
          try {
            image = Image.memory(
              base64Decode(photoUrl.substring(comma + 1)),
              fit: BoxFit.cover,
            );
          } catch (_) {
            image = null;
          }
        }
      } else if (photoUrl.startsWith('/assets/')) {
        image = Image.asset(photoUrl.replaceFirst('/', ''), fit: BoxFit.cover);
      } else {
        image = Image.network(photoUrl, fit: BoxFit.cover);
      }
    }
    final width = large ? 700.0 : 320.0;
    final height = large ? 380.0 : 200.0;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _photoHovering = true),
            onExit: (_) => setState(() => _photoHovering = false),
            child: Stack(
              children: [
                Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: dark ? const Color(0xFF657184) : _lightSecondary,
                    ),
                    color: dark
                        ? const Color(0xFF2F3742)
                        : const Color(0xFFD7EAF4),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child:
                      image ??
                      const Center(child: Icon(Icons.photo_outlined, size: 48)),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: AnimatedOpacity(
                    opacity: (!kIsWeb || _photoHovering || _uploadingPhoto)
                        ? 1
                        : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _uploadingPhoto ? null : onEditPhoto,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: dark
                                ? const Color(0xCC2C2C2C)
                                : const Color(0xCCFFFFFF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: dark
                                  ? const Color(0xFF657184)
                                  : _lightSecondary,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_uploadingPhoto)
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                const Icon(Icons.edit, size: 14),
                              const SizedBox(width: 5),
                              const Text(
                                'Edit',
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatLocationAddress(location),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: dark ? _darkAccent1 : _lightAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientStatChip({
    required String label,
    required String value,
    required Color bg,
    required Color text,
    required Color border,
    double width = 250,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: text,
            ),
            textAlign: TextAlign.center,
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientJobCard({required Job job, required bool dark}) {
    final assignments = _assignmentsForJob(job.id);
    final latestAssignment = assignments.isNotEmpty ? assignments.first : null;
    final cleaner = latestAssignment?.employeeName ?? 'Unassigned';
    final normalized = job.status.trim().toLowerCase();
    final completed =
        normalized == 'completed' ||
        normalized == 'complete' ||
        normalized == 'done';
    final scheduledLike =
        normalized == 'pending' ||
        normalized == 'assigned' ||
        normalized == 'in_progress' ||
        normalized == 'in-progress' ||
        normalized == 'in progress';
    final statusLabel = completed ? 'COMPLETED' : 'SCHEDULED';
    final dateLabel = completed
        ? 'Completed: ${formatDateMdy(job.completedAt ?? job.scheduledDate)}'
        : 'Scheduled: ${formatDateMdy(job.scheduledDate)}';
    final minutes = completed
        ? job.actualDurationMinutes
        : job.estimatedDurationMinutes;
    final duration = minutes == null
        ? 'Duration: N/A'
        : 'Duration: ${minutes ~/ 60}h ${minutes % 60}m';
    final statusBg = completed
        ? (dark ? const Color(0xFF3B465D) : const Color(0xFFDCEEFF))
        : (dark ? const Color(0xFF3B4F3F) : const Color(0xFFDDF6EA));
    final statusFg = completed
        ? (dark ? _darkAccent1 : _lightPrimary)
        : (dark ? const Color(0xFFBFEED4) : const Color(0xFF1D7B53));

    return SizedBox(
      width: 300,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: dark ? const Color(0xFF657184) : const Color(0xFF8BB3D8),
          ),
        ),
        color: dark ? const Color(0xFF353844) : const Color(0xFFF2F8FC),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(
                    backgroundColor: statusBg,
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      scheduledLike || completed
                          ? statusLabel
                          : job.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusFg,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: dark ? _darkText : _lightAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                job.jobNumber,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text('Cleaner: $cleaner', style: const TextStyle(fontSize: 12)),
              Text(duration, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/jobs',
                    arguments: <String, dynamic>{
                      'jobId': job.id,
                      'locationId': job.locationId,
                      'source': 'client_home',
                    },
                  ),
                  icon: const Icon(Icons.chevron_right, size: 16),
                  label: const Text('Details'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showScheduleRequestModal() async {
    final result = await showDialog<_ScheduleRequestFormData>(
      context: context,
      builder: (context) => _ScheduleRequestDialog(
        initialName: _clientProfile?.name ?? '',
        initialEmail: _clientProfile?.email ?? '',
        initialPhone: _clientProfile?.phoneNumber ?? '',
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    final token = _session?.token ?? '';
    if (token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in again.')));
      return;
    }

    final locationId = int.tryParse(
      _clientLocations.isNotEmpty ? _clientLocations.first.id : '',
    );
    final clientId = int.tryParse(_clientProfile?.id ?? '');
    final requestedDate =
        '${result.date.year.toString().padLeft(4, '0')}-${result.date.month.toString().padLeft(2, '0')}-${result.date.day.toString().padLeft(2, '0')}';
    final requestedTime =
        '${result.time.hour.toString().padLeft(2, '0')}:${result.time.minute.toString().padLeft(2, '0')}';

    try {
      await ApiService().createCleaningRequest(
        CleaningRequestCreateInput(
          clientId: clientId,
          locationId: locationId,
          requesterName: result.name,
          requesterEmail: result.email,
          requesterPhone: result.phone,
          requestedDate: requestedDate,
          requestedTime: requestedTime,
          cleaningDetails: result.notes,
        ),
        bearerToken: token,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Theme(
          data: buildCrudModalTheme(context),
          child: AlertDialog(
            title: const Text('Request Submitted'),
            content: const Text(
              'Your cleaning request was sent successfully. Our team will follow up shortly.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      );
    } catch (requestError) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Theme(
          data: buildCrudModalTheme(context),
          child: AlertDialog(
            title: const Text('Request Not Sent'),
            content: Text(
              'We could not submit the cleaning request right now.\n\n${requestError.toString()}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final showRoleSurface = _isEmployee || _isClient;
    return Scaffold(
      bottomNavigationBar: const SafeArea(top: false, child: BackendBanner()),
      appBar: AppBar(
        title: const BrandAppBarTitle(),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          ProfileMenuButton(onProfileUpdated: _loadDashboard),
        ],
      ),
      body: Container(
        decoration: showRoleSurface
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? const [_darkBg, Color(0xFF26262B), Color(0xFF30303A)]
                      : const [
                          Colors.white,
                          _lightSecondary,
                          Color(0xFFE7F3FB),
                        ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              )
            : null,
        child: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: SelectionArea(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (error != null)
                          Card(
                            color: dark
                                ? const Color(0xFF3A2F30)
                                : const Color(0xFFFDECE9),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                error!,
                                style: TextStyle(
                                  color: dark ? _darkAccent2 : _lightCta,
                                ),
                              ),
                            ),
                          ),
                        if (_isAdmin) _buildAdminLanding(),
                        if (_isEmployee) _buildCleanerLanding(),
                        if (_isClient) _buildClientLanding(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ScheduleRequestFormData {
  const _ScheduleRequestFormData({
    required this.name,
    required this.email,
    required this.phone,
    required this.date,
    required this.time,
    required this.notes,
  });

  final String name;
  final String email;
  final String phone;
  final DateTime date;
  final TimeOfDay time;
  final String notes;
}

class _ScheduleRequestDialog extends StatefulWidget {
  const _ScheduleRequestDialog({
    required this.initialName,
    required this.initialEmail,
    required this.initialPhone,
  });

  final String initialName;
  final String initialEmail;
  final String initialPhone;

  @override
  State<_ScheduleRequestDialog> createState() => _ScheduleRequestDialogState();
}

class _ScheduleRequestDialogState extends State<_ScheduleRequestDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked == null) return;
    setState(() => _selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Theme(
      data: buildCrudModalTheme(context),
      child: AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Request Cleaning',
                style: TextStyle(
                  color: dark ? const Color(0xFFB39CD0) : const Color(0xFF442E6F),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                'assets/images/logo.png',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          'Date: ${_selectedDate.month}-${_selectedDate.day}-${_selectedDate.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.access_time),
                        label: Text('Time: ${_selectedTime.format(context)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Cleaning Details',
                    hintText: 'Add cleaning details for this request.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = _nameController.text.trim();
              final email = _emailController.text.trim();
              final phone = _phoneController.text.trim();
              if (name.isEmpty || email.isEmpty || phone.isEmpty) {
                return;
              }
              Navigator.pop(
                context,
                _ScheduleRequestFormData(
                  name: name,
                  email: email,
                  phone: phone,
                  date: _selectedDate,
                  time: _selectedTime,
                  notes: _notesController.text.trim(),
                ),
              );
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }
}
