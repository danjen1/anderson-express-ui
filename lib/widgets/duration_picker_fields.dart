import 'package:flutter/material.dart';

class DurationPickerFields extends StatelessWidget {
  const DurationPickerFields({
    super.key,
    required this.label,
    required this.hours,
    required this.minutesStep,
    required this.onHoursChanged,
    required this.onMinutesChanged,
    this.maxHours = 12,
  });

  static const List<int> quarterHourSteps = [0, 15, 30, 45];

  final String label;
  final int hours;
  final int minutesStep;
  final int maxHours;
  final ValueChanged<int> onHoursChanged;
  final ValueChanged<int> onMinutesChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: hours,
                decoration: const InputDecoration(
                  labelText: 'Hours',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(maxHours + 1, (index) => index)
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  onHoursChanged(value);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: minutesStep,
                decoration: const InputDecoration(
                  labelText: 'Minutes',
                  border: OutlineInputBorder(),
                ),
                items: quarterHourSteps
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString().padLeft(2, '0')),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  onMinutesChanged(value);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
