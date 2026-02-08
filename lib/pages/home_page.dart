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
import '../widgets/profile_menu_button.dart';
import '../widgets/theme_toggle_button.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool loading = true;
  String? error;
  List<Job> _adminPendingJobs = const [];
  List<Job> _cleanerJobs = const [];
  List<Location> _employeeLocations = const [];
  Employee? _employeeProfile;
  DateTime _completedSince = DateTime.now().subtract(const Duration(days: 30));
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
  }) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),
              if (children.isEmpty)
                Text(empty, style: const TextStyle(color: Colors.black54)),
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
    final jobs = _cleanerJobs
        .where(
          (job) =>
              !_isCompletedStatus(job.status) &&
              !_isCancelledStatus(job.status),
        )
        .toList();
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
      _completedSince.year,
      _completedSince.month,
      _completedSince.day,
    );
    final jobs = _cleanerJobs.where((job) {
      if (!_isCompletedStatus(job.status)) return false;
      final date = _parseJobDate(job.completedAt ?? job.scheduledDate);
      if (date == null) return true;
      final normalized = DateTime(date.year, date.month, date.day);
      return !normalized.isBefore(start);
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

  Future<void> _pickCompletedSinceDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _completedSince,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _completedSince = picked;
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
    final tileFg = fg ?? const Color.fromRGBO(36, 36, 36, 1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg ?? const Color.fromRGBO(248, 248, 251, 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
    final assigned = _employeeAssignedJobs;
    final completed = _employeeCompletedJobs;
    final today = DateTime.now();
    final overdue = assigned.where((job) {
      final date = _parseJobDate(job.scheduledDate);
      if (date == null) return false;
      return date.isBefore(DateTime(today.year, today.month, today.day));
    }).length;
    final nextJobDate = assigned.isNotEmpty
        ? _parseJobDate(assigned.first.scheduledDate)
        : null;
    final locationCount = {for (final job in assigned) job.locationId}.length;
    final employeeDisplayName =
        (_employeeProfile?.name.trim().isNotEmpty ?? false)
        ? _employeeProfile!.name.trim()
        : 'Employee';

    Widget employeeJobCard(
      Job job, {
      required bool completedCard,
      required double cardWidth,
    }) {
      final clientName = (job.clientName?.trim().isNotEmpty ?? false)
          ? job.clientName!.trim()
          : 'Client unavailable';
      final locationType = (job.locationType ?? '').trim().toLowerCase();
      final whoLabel = locationType == 'commercial' ? 'Business' : 'Client';
      final mapsLabel = _deviceMapLabel();
      final duration = job.actualDurationMinutes == null
          ? 'Duration: N/A'
          : 'Duration: ${job.actualDurationMinutes! ~/ 60}h ${job.actualDurationMinutes! % 60}m';
      final primaryDate = completedCard
          ? formatDateMdy(job.completedAt ?? job.scheduledDate)
          : formatDateMdy(job.scheduledDate);
      final dateLabel = completedCard ? 'Completed' : 'Scheduled';
      final isCompact = MediaQuery.sizeOf(context).width < 480;
      final statusLabel = job.status.replaceAll('_', ' ').toUpperCase();
      final statusNormalized = job.status.trim().toLowerCase();
      final statusChipColor = switch (statusNormalized) {
        'pending' => const Color.fromRGBO(255, 247, 224, 1),
        'assigned' => const Color.fromRGBO(232, 241, 255, 1),
        _ => const Color.fromRGBO(240, 243, 249, 1),
      };
      final statusTextColor = switch (statusNormalized) {
        'pending' => const Color.fromRGBO(138, 92, 8, 1),
        'assigned' => const Color.fromRGBO(34, 73, 140, 1),
        _ => const Color.fromRGBO(67, 76, 98, 1),
      };

      return SizedBox(
        width: cardWidth,
        height: isCompact ? 248 : 260,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 10 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$whoLabel: $clientName',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  job.jobNumber,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$dateLabel: $primaryDate',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color.fromRGBO(22, 67, 121, 1),
                  ),
                ),
                if ((job.locationAddress?.trim().isNotEmpty ?? false) ||
                    (job.locationCity?.trim().isNotEmpty ?? false) ||
                    (job.locationState?.trim().isNotEmpty ?? false) ||
                    (job.locationZipCode?.trim().isNotEmpty ?? false))
                  Text(
                    [
                      job.locationAddress?.trim() ?? '',
                      job.locationCity?.trim() ?? '',
                      job.locationState?.trim() ?? '',
                      job.locationZipCode?.trim() ?? '',
                    ].where((p) => p.isNotEmpty).join(', '),
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Chip(
                      backgroundColor: statusChipColor,
                      label: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusTextColor,
                        ),
                      ),
                    ),
                    if (!completedCard)
                      Chip(
                        avatar: const Icon(Icons.near_me_outlined, size: 14),
                        label: Text(_distanceHintForJob(job)),
                        labelStyle: const TextStyle(fontSize: 11),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (!completedCard)
                      FilledButton.icon(
                        onPressed: () => _openJobInMaps(job),
                        icon: const Icon(Icons.map, size: 16),
                        label: Text(mapsLabel),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(41, 98, 255, 1),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 7 : 8,
                            vertical: isCompact ? 3 : 4,
                          ),
                          textStyle: TextStyle(fontSize: isCompact ? 11 : 12),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/cleaner'),
                      icon: const Icon(Icons.chevron_right, size: 16),
                      label: const Text('Details'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 7 : 8,
                          vertical: isCompact ? 3 : 4,
                        ),
                        textStyle: TextStyle(fontSize: isCompact ? 11 : 12),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, $employeeDisplayName',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color.fromRGBO(21, 80, 58, 1),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Employee Dashboard',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _metricTile(
                        label: 'Assigned',
                        value: assigned.length.toString(),
                        icon: Icons.assignment,
                        bg: const Color.fromRGBO(255, 249, 224, 1),
                        fg: const Color.fromRGBO(138, 92, 8, 1),
                      ),
                      _metricTile(
                        label: 'Completed',
                        value: completed.length.toString(),
                        icon: Icons.check_circle_outline,
                        bg: const Color.fromRGBO(227, 241, 233, 1),
                        fg: const Color.fromRGBO(22, 89, 56, 1),
                      ),
                      _metricTile(
                        label: 'Overdue',
                        value: overdue.toString(),
                        icon: Icons.warning_amber_outlined,
                        bg: const Color.fromRGBO(255, 232, 238, 1),
                        fg: const Color.fromRGBO(156, 42, 74, 1),
                      ),
                      _metricTile(
                        label: 'Unique Locations',
                        value: locationCount.toString(),
                        icon: Icons.location_on_outlined,
                        bg: const Color.fromRGBO(236, 244, 240, 1),
                        fg: const Color.fromRGBO(45, 87, 73, 1),
                      ),
                      _metricTile(
                        label: 'Next Job',
                        value: nextJobDate == null
                            ? 'None'
                            : formatDateMdy(
                                '${nextJobDate.year}-${nextJobDate.month.toString().padLeft(2, '0')}-${nextJobDate.day.toString().padLeft(2, '0')}',
                              ),
                        icon: Icons.event,
                        bg: const Color.fromRGBO(233, 246, 241, 1),
                        fg: const Color.fromRGBO(29, 102, 76, 1),
                      ),
                      _metricTile(
                        label: 'Duration',
                        value: assigned.isEmpty
                            ? 'N/A'
                            : '${assigned.where((j) => j.actualDurationMinutes != null).fold<int>(0, (sum, j) => sum + (j.actualDurationMinutes ?? 0)) ~/ 60}h ${assigned.where((j) => j.actualDurationMinutes != null).fold<int>(0, (sum, j) => sum + (j.actualDurationMinutes ?? 0)) % 60}m',
                        icon: Icons.timer_outlined,
                        bg: const Color.fromRGBO(230, 245, 247, 1),
                        fg: const Color.fromRGBO(18, 103, 93, 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _cardList(
          title: 'YOUR ASSIGNED JOBS',
          empty: 'No jobs assigned',
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
                          (job) => employeeJobCard(
                            job,
                            completedCard: false,
                            cardWidth: cardWidth,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
          ],
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
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.filter_alt_outlined),
                  Text(
                    'Completed jobs since ${_completedSince.month}-${_completedSince.day}-${_completedSince.year}',
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _completedSince = DateTime.now().subtract(
                          const Duration(days: 30),
                        );
                      });
                    },
                    child: const Text('Last 30 days'),
                  ),
                  FilledButton.tonal(
                    onPressed: _pickCompletedSinceDate,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(226, 241, 236, 1),
                      foregroundColor: const Color.fromRGBO(29, 92, 70, 1),
                    ),
                    child: const Text('Pick date'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _cardList(
          title: 'COMPLETED JOBS',
          empty: 'No completed jobs in selected period',
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
                          (job) => employeeJobCard(
                            job,
                            completedCard: true,
                            cardWidth: cardWidth,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anderson Express Cleaning Service'),
        bottom: const BackendBanner(),
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
      body: SafeArea(
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
                          color: Colors.red.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              error!,
                              style: TextStyle(color: Colors.red.shade700),
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
    );
  }
}
