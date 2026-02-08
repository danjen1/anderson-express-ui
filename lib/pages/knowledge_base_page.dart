import 'package:flutter/material.dart';

import '../widgets/backend_banner.dart';
import '../widgets/profile_menu_button.dart';
import '../widgets/theme_toggle_button.dart';

class KnowledgeBasePage extends StatelessWidget {
  const KnowledgeBasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge Base'),
        bottom: const BackendBanner(),
        actions: const [ThemeToggleButton(), ProfileMenuButton()],
      ),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _GuideCard(
              title: 'Deep Clean: Oven',
              subtitle:
                  'Step-by-step safety checklist, approved chemicals, and finish standards.',
              audience: 'Employees',
            ),
            SizedBox(height: 12),
            _GuideCard(
              title: 'Bathroom Sanitization',
              subtitle:
                  'Sequence for disinfecting high-touch surfaces and mold-risk areas.',
              audience: 'Employees',
            ),
            SizedBox(height: 12),
            _GuideCard(
              title: 'Client Handoff Standards',
              subtitle:
                  'Close-out notes, photo expectations, and quality verification checklist.',
              audience: 'Employees + Admin',
            ),
            SizedBox(height: 12),
            _GuideCard(
              title: 'Operational SOPs',
              subtitle:
                  'Scheduling constraints, escalation contacts, and incident handling.',
              audience: 'Admin',
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.title,
    required this.subtitle,
    required this.audience,
  });

  final String title;
  final String subtitle;
  final String audience;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle),
            const SizedBox(height: 8),
            Chip(label: Text(audience)),
          ],
        ),
      ),
    );
  }
}
