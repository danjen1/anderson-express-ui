import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/employee.dart';
import '../models/job.dart';
import '../models/job_assignment.dart';
import '../models/location.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../utils/date_format.dart';
import '../widgets/backend_banner.dart';
import '../widgets/brand_app_bar_title.dart';
import '../widgets/employee/employee_dashboard_cards.dart';
import '../widgets/employee/employee_job_card.dart';
import '../widgets/profile_menu_button.dart';
import '../widgets/theme_toggle_button.dart';

DateTimeRange _currentWeekRange() {
  final now = DateTime.now();
  final daysSinceSunday = now.weekday % DateTime.daysPerWeek;
  final start = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: daysSinceSunday));
  final end = start.add(const Duration(days: 6));
  return DateTimeRange(start: start, end: end);
}

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
  DateTimeRange _employeeDateRange = _currentWeekRange();
  List<Location> _clientLocations = const [];
  List<Job> _clientJobs = const [];
  List<Job> _clientPendingJobs = const [];
  DateTime _clientCompletedSince = DateTime.now().subtract(
    const Duration(days: 30),
  );
  Map<String, List<JobAssignment>> _clientAssignmentsByJob = const {};

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
        Navigator.pushReplacementNamed(context, '/');
      });
      return;
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final valid = await _ensureSessionIsValid();
    if (!mounted) return;
    if (!valid) {
      Navigator.pushReplacementNamed(context, '/');
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
      List<Job> clientPending = const [];
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
        clientLocations = await api.listLocations(bearerToken: token);
        clientJobs = await api.listJobs(bearerToken: token);
        clientPending = clientJobs
            .where((job) => !_isCompletedStatus(job.status))
            .toList();

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
        _clientPendingJobs = clientPending;
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

  Future<void> _pickClientCompletedSinceDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _clientCompletedSince,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _clientCompletedSince = picked;
    });
  }

  List<Job> get _clientCompletedJobs {
    final start = DateTime(
      _clientCompletedSince.year,
      _clientCompletedSince.month,
      _clientCompletedSince.day,
    );
    final jobs = _clientJobs.where((job) {
      if (!_isCompletedStatus(job.status)) return false;
      final date = _parseJobDate(job.completedAt ?? job.scheduledDate);
      if (date == null) return true;
      final normalized = DateTime(date.year, date.month, date.day);
      return !normalized.isBefore(start);
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

  String _formatDateTimeShort(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    try {
      final parsed = DateTime.parse(raw).toLocal();
      final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
      final minute = parsed.minute.toString().padLeft(2, '0');
      final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
      return '${parsed.month}-${parsed.day}-${parsed.year} $hour:$minute $suffix';
    } catch (_) {
      return raw;
    }
  }

  List<JobAssignment> _assignmentsForJob(String jobId) {
    return _clientAssignmentsByJob[jobId] ?? const [];
  }

  Widget _metricTile({
    required String label,
    required String value,
    IconData? icon,
    Color? bg,
    Color? fg,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tileFg = fg ?? (dark ? _darkText : _lightAccent);
    return Container(
      constraints: const BoxConstraints(minWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: bg ?? (dark ? const Color(0xFF3A3A3A) : _lightSecondary),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: tileFg),
            const SizedBox(width: 6),
          ],
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w700, color: tileFg),
          ),
          Text(value, style: TextStyle(color: tileFg)),
        ],
      ),
    );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, $employeeDisplayName',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: dark ? _darkAccent1 : _lightPrimary,
          ),
        ),
        const SizedBox(height: 10),
        EmployeeDateRangeCard(
          dark: dark,
          range: _employeeDateRange,
          onPickStart: _pickEmployeeStartDate,
          onPickEnd: _pickEmployeeEndDate,
          onResetWeek: () =>
              setState(() => _employeeDateRange = _currentWeekRange()),
          cardColor: sectionCardBg,
          borderColor: sectionBorder,
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
                            onOpenDetails: () =>
                                Navigator.pushNamed(context, '/cleaner'),
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
                            onOpenDetails: () =>
                                Navigator.pushNamed(context, '/cleaner'),
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

  Widget _buildClientLanding() {
    final completedJobs = _clientCompletedJobs;
    final recentCleanings = completedJobs.length;
    final pendingJobs = _clientPendingJobs.length;
    final averageDuration = completedJobs
        .where((job) => job.actualDurationMinutes != null)
        .fold<int>(0, (sum, job) => sum + (job.actualDurationMinutes ?? 0));
    final durationCount = completedJobs
        .where((job) => job.actualDurationMinutes != null)
        .length;
    final averageFrequencyDays = _clientAverageFrequencyDays(completedJobs);
    final primaryLocation = _clientLocations.isNotEmpty
        ? _clientLocations.first
        : null;

    Widget historyTile(Job job) {
      final assignments = _assignmentsForJob(job.id);
      final latestAssignment = assignments.isNotEmpty
          ? assignments.first
          : null;
      final cleaner = latestAssignment?.employeeName ?? 'Unassigned';
      final startTime = _formatDateTimeShort(latestAssignment?.startTime);
      final endTime = _formatDateTimeShort(latestAssignment?.endTime);
      final duration = job.actualDurationMinutes == null
          ? 'N/A'
          : '${job.actualDurationMinutes! ~/ 60}h ${job.actualDurationMinutes! % 60}m';
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.jobNumber,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Cleaning date: ${formatDateMdy(job.completedAt ?? job.scheduledDate)}',
              ),
              Text('Cleaner: $cleaner'),
              Text('Start: $startTime'),
              Text('Stop: $endTime'),
              Text('Duration: $duration'),
              if ((job.locationAddress?.trim().isNotEmpty ?? false))
                Text(
                  'Location: ${[job.locationAddress?.trim() ?? '', job.locationCity?.trim() ?? '', job.locationState?.trim() ?? '', job.locationZipCode?.trim() ?? ''].where((p) => p.isNotEmpty).join(', ')}',
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _metricTile(
                    label: 'Recent Cleanings',
                    value: recentCleanings.toString(),
                    icon: Icons.cleaning_services_outlined,
                    bg: const Color.fromRGBO(231, 240, 255, 1),
                    fg: const Color.fromRGBO(35, 72, 138, 1),
                  ),
                  _metricTile(
                    label: 'Pending Jobs',
                    value: pendingJobs.toString(),
                    icon: Icons.pending_actions_outlined,
                    bg: const Color.fromRGBO(255, 247, 228, 1),
                    fg: const Color.fromRGBO(132, 92, 18, 1),
                  ),
                  _metricTile(
                    label: 'Avg Duration',
                    value: durationCount == 0
                        ? 'N/A'
                        : '${(averageDuration ~/ durationCount) ~/ 60}h ${(averageDuration ~/ durationCount) % 60}m',
                    icon: Icons.timer_outlined,
                    bg: const Color.fromRGBO(236, 246, 240, 1),
                    fg: const Color.fromRGBO(33, 94, 66, 1),
                  ),
                  _metricTile(
                    label: 'Cleaning Frequency',
                    value: averageFrequencyDays == 0
                        ? 'N/A'
                        : 'Every ${averageFrequencyDays.toStringAsFixed(1)} days',
                    icon: Icons.repeat,
                    bg: const Color.fromRGBO(238, 240, 253, 1),
                    fg: const Color.fromRGBO(55, 66, 132, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (primaryLocation != null)
          SizedBox(
            width: double.infinity,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 280,
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color.fromRGBO(234, 239, 246, 1),
                        border: Border.all(
                          color: const Color.fromRGBO(189, 202, 222, 1),
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.home_work_outlined, size: 52),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      primaryLocation.locationNumber,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${primaryLocation.type} • ${primaryLocation.address ?? 'No address on file'}',
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        _cardList(
          title: 'Pending Jobs',
          empty: 'No pending jobs',
          children: _clientPendingJobs.map((job) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.pending_actions),
              title: Text(job.jobNumber),
              subtitle: Text(
                '${job.status.replaceAll('_', ' ')} • ${formatDateMdy(job.scheduledDate)}',
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  Text(
                    'Cleaning details since ${_clientCompletedSince.month}-${_clientCompletedSince.day}-${_clientCompletedSince.year}',
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _clientCompletedSince = DateTime.now().subtract(
                          const Duration(days: 30),
                        );
                      });
                    },
                    child: const Text('Last 30 days'),
                  ),
                  FilledButton.tonal(
                    onPressed: _pickClientCompletedSinceDate,
                    child: const Text('Pick date'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _cardList(
          title: 'Cleaning History',
          empty: 'No completed cleanings in selected period',
          children: completedJobs.map(historyTile).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final showEmployeeSurface = _isEmployee;
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
          const ProfileMenuButton(),
        ],
      ),
      body: Container(
        decoration: showEmployeeSurface
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
