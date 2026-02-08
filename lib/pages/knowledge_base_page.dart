import 'package:flutter/material.dart';

import '../widgets/backend_banner.dart';
import '../widgets/profile_menu_button.dart';
import '../widgets/theme_toggle_button.dart';

class KnowledgeBasePage extends StatefulWidget {
  const KnowledgeBasePage({super.key});

  @override
  State<KnowledgeBasePage> createState() => _KnowledgeBasePageState();
}

class _KnowledgeBasePageState extends State<KnowledgeBasePage> {
  static const _guides = <_GuideEntry>[
    _GuideEntry(
      id: 'oven',
      title: 'Deep Clean: Oven',
      icon: Icons.kitchen_outlined,
      audience: 'Employees',
      sections: [
        _GuideSection(
          heading: 'Safety',
          body:
              'Confirm oven is cool, use gloves, and ventilate area before applying cleaner.',
        ),
        _GuideSection(
          heading: 'Procedure',
          body:
              '1) Remove racks. 2) Apply approved degreaser. 3) Dwell time. 4) Scrub. 5) Rinse and dry.',
        ),
        _GuideSection(
          heading: 'Finish Standard',
          body:
              'No residue, no standing cleaner, and no visible carbon debris on interior surfaces.',
        ),
      ],
    ),
    _GuideEntry(
      id: 'bathroom',
      title: 'Bathroom Sanitization',
      icon: Icons.shower_outlined,
      audience: 'Employees',
      sections: [
        _GuideSection(
          heading: 'Sequence',
          body:
              'Mirrors and counters first, then fixtures, then floors to avoid cross-contamination.',
        ),
        _GuideSection(
          heading: 'Dwell Time',
          body:
              'Disinfectants must remain wet for labeled contact time before wiping.',
        ),
      ],
    ),
    _GuideEntry(
      id: 'handoff',
      title: 'Client Handoff Standards',
      icon: Icons.assignment_turned_in_outlined,
      audience: 'Employees + Admin',
      sections: [
        _GuideSection(
          heading: 'Before Closeout',
          body:
              'Take completion photos, verify checklist completion, and leave notes for exceptions.',
        ),
        _GuideSection(
          heading: 'Client Communication',
          body:
              'Use concise status language: completed areas, unresolved items, follow-up actions.',
        ),
      ],
    ),
    _GuideEntry(
      id: 'ops',
      title: 'Operational SOPs',
      icon: Icons.rule_folder_outlined,
      audience: 'Admin',
      sections: [
        _GuideSection(
          heading: 'Scheduling',
          body:
              'Assignments are prioritized by due date, route efficiency, and cleaner availability.',
        ),
        _GuideSection(
          heading: 'Escalation',
          body:
              'Escalate blocked jobs to admin queue with reason, timestamp, and client impact summary.',
        ),
      ],
    ),
  ];

  String _selectedGuideId = _guides.first.id;

  _GuideEntry get _selectedGuide {
    return _guides.firstWhere((guide) => guide.id == _selectedGuideId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge Base'),
        bottom: const BackendBanner(),
        actions: const [ThemeToggleButton(), ProfileMenuButton()],
      ),
      body: SelectionArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 900;
            final sidebar = Container(
              width: isCompact ? double.infinity : 260,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  right: BorderSide(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Guide Library',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  ..._guides.map((guide) {
                    final selected = _selectedGuideId == guide.id;
                    return ListTile(
                      leading: Icon(guide.icon),
                      title: Text(guide.title),
                      selected: selected,
                      onTap: () => setState(() => _selectedGuideId = guide.id),
                    );
                  }),
                ],
              ),
            );
            final content = ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  _selectedGuide.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Chip(label: Text('Audience: ${_selectedGuide.audience}')),
                const SizedBox(height: 12),
                ..._selectedGuide.sections.map(
                  (section) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.heading,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(section.body),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
            if (isCompact) {
              return Column(
                children: [
                  SizedBox(height: 240, child: sidebar),
                  Expanded(child: content),
                ],
              );
            }
            return Row(
              children: [
                sidebar,
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GuideEntry {
  const _GuideEntry({
    required this.id,
    required this.title,
    required this.icon,
    required this.audience,
    required this.sections,
  });

  final String id;
  final String title;
  final IconData icon;
  final String audience;
  final List<_GuideSection> sections;
}

class _GuideSection {
  const _GuideSection({required this.heading, required this.body});

  final String heading;
  final String body;
}
