import 'package:flutter/material.dart';
import '../../../models/cleaning_profile.dart';
import '../../../models/profile_task.dart';
import '../../../models/task_definition.dart';
import '../../../models/task_rule.dart';
import '../../../services/app_env.dart';

class CleaningProfilesSection extends StatelessWidget {
  const CleaningProfilesSection({
    super.key,
    required this.cleaningProfiles,
    required this.selectedProfileTasks,
    required this.taskDefinitions,
    required this.taskRules,
    required this.selectedProfileId,
    required this.loadingProfileTasks,
    required this.onCreateProfile,
    required this.onCreateTaskDefinition,
    required this.onCreateTaskRule,
    required this.onAddProfileTask,
    required this.onSelectProfile,
    required this.onEditProfile,
    required this.onDeleteProfile,
    required this.onEditProfileTask,
    required this.onDeleteProfileTask,
    required this.getLocationLabel,
    required this.getTaskDefinitionLabel,
    required this.buildSectionHeader,
    required this.buildCenteredSection,
    required this.buildTableColumn,
  });

  final List<CleaningProfile> cleaningProfiles;
  final List<ProfileTask> selectedProfileTasks;
  final List<TaskDefinition> taskDefinitions;
  final List<TaskRule> taskRules;
  final String? selectedProfileId;
  final bool loadingProfileTasks;
  
  final VoidCallback onCreateProfile;
  final VoidCallback onCreateTaskDefinition;
  final VoidCallback onCreateTaskRule;
  final VoidCallback onAddProfileTask;
  final ValueChanged<String> onSelectProfile;
  final ValueChanged<CleaningProfile> onEditProfile;
  final ValueChanged<CleaningProfile> onDeleteProfile;
  final ValueChanged<ProfileTask> onEditProfileTask;
  final ValueChanged<ProfileTask> onDeleteProfileTask;
  
  final String Function(int) getLocationLabel;
  final String Function(int) getTaskDefinitionLabel;
  final Widget Function(String, String) buildSectionHeader;
  final Widget Function(Widget) buildCenteredSection;
  final DataColumn Function(String) buildTableColumn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionHeader(
          'Cleaning Profiles',
          'Define reusable cleaning profiles and seed task definitions/rules.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onCreateProfile,
              icon: const Icon(Icons.add_task),
              label: const Text('Create Profile'),
            ),
            OutlinedButton.icon(
              onPressed: onCreateTaskDefinition,
              icon: const Icon(Icons.playlist_add),
              label: const Text('Create Task Definition'),
            ),
            OutlinedButton.icon(
              onPressed: onCreateTaskRule,
              icon: const Icon(Icons.rule),
              label: const Text('Create Task Rule'),
            ),
            FilledButton.icon(
              onPressed: onAddProfileTask,
              icon: const Icon(Icons.link),
              label: const Text('Link Task To Selected Profile'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: buildCenteredSection(
            Column(
              children: [
                Expanded(
                  flex: 4,
                  child: Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: [
                            buildTableColumn('Profile'),
                            buildTableColumn('Location'),
                            buildTableColumn('Notes'),
                            buildTableColumn('Select'),
                            buildTableColumn('Actions'),
                          ],
                          rows: cleaningProfiles
                              .map(
                                (profile) => DataRow(
                                  selected: profile.id == selectedProfileId,
                                  cells: [
                                    DataCell(Text(profile.name)),
                                    DataCell(
                                      Text(getLocationLabel(profile.locationId)),
                                    ),
                                    DataCell(Text(profile.notes ?? '—')),
                                    DataCell(
                                      OutlinedButton(
                                        onPressed: profile.id == selectedProfileId
                                            ? null
                                            : () => onSelectProfile(profile.id),
                                        child: Text(
                                          profile.id == selectedProfileId
                                              ? 'Selected'
                                              : 'Select',
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            tooltip: 'Edit',
                                            onPressed: AppEnv.isDemoMode
                                                ? null
                                                : () => onEditProfile(profile),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            tooltip: 'Delete',
                                            onPressed: AppEnv.isDemoMode
                                                ? null
                                                : () => onDeleteProfile(profile),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (selectedProfileId != null)
                  Expanded(
                    flex: 3,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Profile Tasks (${selectedProfileTasks.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (loadingProfileTasks)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    columns: [
                                      buildTableColumn('Task'),
                                      buildTableColumn('Required'),
                                      buildTableColumn('Order'),
                                      buildTableColumn('Actions'),
                                    ],
                                    rows: selectedProfileTasks
                                        .map(
                                          (task) => DataRow(
                                            cells: [
                                              DataCell(
                                                Text(
                                                  getTaskDefinitionLabel(
                                                    task.taskDefinitionId,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(task.required ? 'Yes' : 'No'),
                                              ),
                                              DataCell(
                                                Text(
                                                  task.displayOrder?.toString() ?? '—',
                                                ),
                                              ),
                                              DataCell(
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.edit),
                                                      tooltip: 'Edit',
                                                      onPressed: AppEnv.isDemoMode
                                                          ? null
                                                          : () => onEditProfileTask(task),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete),
                                                      tooltip: 'Delete',
                                                      onPressed: AppEnv.isDemoMode
                                                          ? null
                                                          : () => onDeleteProfileTask(task),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  flex: 2,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Task Definitions (${taskDefinitions.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: taskDefinitions.length,
                                    itemBuilder: (context, index) {
                                      final item = taskDefinitions[index];
                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text('${item.code} • ${item.name}'),
                                        subtitle: Text(item.category),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Task Rules (${taskRules.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: taskRules.length,
                                    itemBuilder: (context, index) {
                                      final rule = taskRules[index];
                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text('Rule #${rule.id}'),
                                        subtitle: Text(rule.notesTemplate ?? 'No notes'),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
