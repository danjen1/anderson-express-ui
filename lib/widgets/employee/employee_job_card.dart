import 'package:flutter/material.dart';

import '../../models/job.dart';

class EmployeeJobCard extends StatelessWidget {
  const EmployeeJobCard({
    super.key,
    required this.job,
    required this.completedCard,
    required this.cardWidth,
    required this.primaryDateLabel,
    required this.distanceLabel,
    required this.onOpenDetails,
    required this.onOpenMaps,
    this.mapsLabel = 'Open in Maps',
  });

  final Job job;
  final bool completedCard;
  final double cardWidth;
  final String primaryDateLabel;
  final String distanceLabel;
  final VoidCallback onOpenDetails;
  final VoidCallback onOpenMaps;
  final String mapsLabel;

  static const Color _lightPrimary = Color(0xFF296273);
  static const Color _lightSecondary = Color(0xFFA8D6F7);
  static const Color _lightAccent = Color(0xFF442E6F);
  static const Color _lightCta = Color(0xFFEE7E32);

  static const Color _darkBg = Color(0xFF2C2C2C);
  static const Color _darkText = Color(0xFFE4E4E4);
  static const Color _darkAccent1 = Color(0xFFA8DADC);
  static const Color _darkAccent2 = Color(0xFFFFC1CC);
  static const Color _darkCta = Color(0xFFB39CD0);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final clientName = (job.clientName?.trim().isNotEmpty ?? false)
        ? job.clientName!.trim()
        : 'Client unavailable';
    final locationType = (job.locationType ?? '').trim().toLowerCase();
    final whoLabel = locationType == 'commercial' ? 'Business' : 'Client';
    final durationMinutes = completedCard
        ? job.actualDurationMinutes
        : job.estimatedDurationMinutes;
    final durationLabel = completedCard ? 'Duration' : 'Scheduled';
    final duration = durationMinutes == null
        ? '$durationLabel: N/A'
        : '$durationLabel: ${durationMinutes ~/ 60}h ${durationMinutes % 60}m';
    final isCompact = MediaQuery.sizeOf(context).width < 480;
    final actionWidth = isCompact ? 116.0 : 138.0;
    final statusLabel = job.status.replaceAll('_', ' ').toUpperCase();
    final statusNormalized = job.status.trim().toLowerCase();
    final statusChipColor = switch (statusNormalized) {
      'in_progress' ||
      'in-progress' ||
      'in progress' => dark ? const Color(0xFF4A3D54) : _lightCta,
      'assigned' => dark ? const Color(0xFF3C4960) : const Color(0xFFDDF3EA),
      _ => dark ? const Color(0xFF3A3A3A) : const Color(0xFFE7EEF4),
    };
    final statusTextColor = switch (statusNormalized) {
      'in_progress' ||
      'in-progress' ||
      'in progress' => dark ? _darkAccent2 : Colors.white,
      'assigned' => dark ? _darkAccent1 : _lightPrimary,
      _ => dark ? _darkText : _lightAccent,
    };
    final cardBg = dark ? const Color(0xFF353844) : const Color(0xFFF2F8FC);

    return SizedBox(
      width: cardWidth,
      child: Card(
        margin: EdgeInsets.zero,
        color: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: dark ? const Color(0xFF657184) : _lightSecondary,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 10 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, topConstraints) {
                  final statusChip = Chip(
                    backgroundColor: statusChipColor,
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusTextColor,
                      ),
                    ),
                  );
                  final scheduledChip = Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: dark
                        ? const Color(0xFF3A3A3A)
                        : const Color(0xFFEAF4FA),
                    label: Text(
                      primaryDateLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: dark ? _darkText : _lightAccent,
                      ),
                    ),
                  );
                  if (completedCard) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: scheduledChip,
                    );
                  }
                  if (topConstraints.maxWidth >= 250) {
                    return Row(
                      children: [statusChip, const Spacer(), scheduledChip],
                    );
                  }
                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [statusChip, scheduledChip],
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                '$whoLabel: $clientName',
                style: const TextStyle(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                job.jobNumber,
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? _darkText : _lightPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                duration,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: dark ? _darkAccent1 : _lightAccent,
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
              const SizedBox(height: 10),
              if (!completedCard) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          SizedBox(
                            width: actionWidth,
                            child: _distancePill(
                              context: context,
                              dark: dark,
                              width: actionWidth,
                            ),
                          ),
                          SizedBox(
                            width: actionWidth,
                            child: FilledButton.icon(
                              onPressed: onOpenMaps,
                              icon: const Icon(Icons.map, size: 16),
                              label: Text(mapsLabel),
                              style: FilledButton.styleFrom(
                                backgroundColor: dark
                                    ? _darkCta
                                    : _lightPrimary,
                                foregroundColor: dark ? _darkBg : Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isCompact ? 7 : 8,
                                  vertical: isCompact ? 3 : 4,
                                ),
                                textStyle: TextStyle(
                                  fontSize: isCompact ? 11 : 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: actionWidth,
                      child: _detailsButton(
                        context: context,
                        dark: dark,
                        isCompact: isCompact,
                      ),
                    ),
                  ],
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: SizedBox(
                        width: actionWidth,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: actionWidth,
                            child: _distancePill(
                              context: context,
                              dark: dark,
                              width: actionWidth,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: actionWidth,
                      child: _detailsButton(
                        context: context,
                        dark: dark,
                        isCompact: isCompact,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _distancePill({
    required BuildContext context,
    required bool dark,
    required double width,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF3A3A3A) : const Color(0xFFEAF4FA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: dark ? _darkCta : _lightAccent),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.near_me_outlined, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              distanceLabel,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: dark ? _darkText : _lightAccent,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsButton({
    required BuildContext context,
    required bool dark,
    required bool isCompact,
  }) {
    return OutlinedButton.icon(
      onPressed: onOpenDetails,
      icon: const Icon(Icons.chevron_right, size: 16),
      label: const Text('Details'),
      style: OutlinedButton.styleFrom(
        foregroundColor: dark ? _darkAccent1 : _lightAccent,
        side: BorderSide(color: dark ? _darkCta : _lightAccent),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 7 : 8,
          vertical: isCompact ? 3 : 4,
        ),
        textStyle: TextStyle(fontSize: isCompact ? 11 : 12),
      ),
    );
  }
}
