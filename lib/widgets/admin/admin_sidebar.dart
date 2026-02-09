import 'package:flutter/material.dart';

enum AdminSection {
  dashboard,
  jobs,
  cleaningProfiles,
  management,
  reports,
  knowledgeBase,
}

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.collapsed,
    required this.selectedSection,
    required this.onSectionChanged,
    this.forDrawer = false,
  });

  final bool collapsed;
  final AdminSection selectedSection;
  final ValueChanged<AdminSection> onSectionChanged;
  final bool forDrawer;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg = dark ? const Color(0xFF1F1F1F) : const Color(0xFFF7FCFE);
    final sidebarBorder = dark
        ? const Color(0xFF4A525F)
        : const Color(0xFF296273).withValues(alpha: 0.22);
    final navSelected = dark
        ? const Color(0xFFB39CD0).withValues(alpha: 0.24)
        : const Color(0xFFA8D6F7).withValues(alpha: 0.45);
    final navFg = dark ? const Color(0xFFE4E4E4) : const Color(0xFF442E6F);
    final navSelectedFg = dark
        ? const Color(0xFFB39CD0)
        : const Color(0xFF296273);

    Widget navTile({
      required AdminSection section,
      required IconData icon,
      required String title,
    }) {
      final selected = selectedSection == section;
      final tile = ListTile(
        dense: true,
        leading: Icon(icon, size: 24),
        iconColor: selected ? navSelectedFg : navFg,
        textColor: selected ? navSelectedFg : navFg,
        selectedTileColor: navSelected,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 14),
        title: collapsed ? null : Text(title),
        selected: selected,
        onTap: () {
          onSectionChanged(section);
          if (forDrawer) Navigator.pop(context);
        },
      );
      if (collapsed && !forDrawer) {
        return Tooltip(message: title, child: tile);
      }
      return tile;
    }

    return Container(
      width: collapsed && !forDrawer ? 78 : 260,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: sidebarBorder)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        children: [
          if (!forDrawer)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 2,
                runSpacing: 2,
                children: [
                  if (collapsed)
                    Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    )
                  else ...[
                    Image.asset(
                      'assets/images/logo.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Anderson Express Cleaning',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: navFg,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (collapsed && !forDrawer)
            const SizedBox(height: 2)
          else
            const SizedBox(height: 2),
          navTile(
            section: AdminSection.jobs,
            icon: Icons.work_outline,
            title: 'Jobs',
          ),
          navTile(
            section: AdminSection.cleaningProfiles,
            icon: Icons.checklist_rtl_outlined,
            title: 'Cleaning Profiles',
          ),
          navTile(
            section: AdminSection.management,
            icon: Icons.groups_outlined,
            title: 'People & Places',
          ),
          navTile(
            section: AdminSection.reports,
            icon: Icons.assessment_outlined,
            title: 'Reports',
          ),
          navTile(
            section: AdminSection.knowledgeBase,
            icon: Icons.menu_book_outlined,
            title: 'Knowledge Base',
          ),
          const Divider(height: 24),
          navTile(
            section: AdminSection.dashboard,
            icon: Icons.dashboard_outlined,
            title: 'Overview Dashboard',
          ),
        ],
      ),
    );
  }
}
