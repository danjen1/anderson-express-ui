import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import 'personal_profile_modal.dart';

class ProfileMenuButton extends StatelessWidget {
  const ProfileMenuButton({super.key, this.onProfileUpdated});

  final VoidCallback? onProfileUpdated;

  @override
  Widget build(BuildContext context) {
    final session = AuthSession.current;
    final email = session?.loginEmail ?? '';
    final initials = _initialsFromEmail(email);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final avatarBg = dark ? const Color(0xFFB39CD0) : const Color(0xFF442E6F);
    final avatarFg = dark ? const Color(0xFF1F1F1F) : Colors.white;
    final showKnowledgeBase = session?.user.isClient != true;

    return PopupMenuButton<String>(
      tooltip: 'Account menu',
      onSelected: (value) async {
        switch (value) {
          case 'profile':
            final updated = await showPersonalProfileModal(context);
            if (updated) {
              onProfileUpdated?.call();
            }
            break;
          case 'knowledge_base':
            Navigator.pushNamed(context, '/knowledge-base');
            break;
          case 'logout':
            AuthSession.clear();
            Navigator.pushReplacementNamed(context, '/');
            break;
        }
      },
      itemBuilder: (context) {
        return [
          const PopupMenuItem<String>(
            value: 'profile',
            child: ListTile(
              leading: Icon(Icons.person_outline),
              title: Text('My Profile'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (showKnowledgeBase)
            const PopupMenuItem<String>(
              value: 'knowledge_base',
              child: ListTile(
                leading: Icon(Icons.menu_book_outlined),
                title: Text('Knowledge Base'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'logout',
            child: ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ];
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: avatarBg,
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: avatarFg,
            ),
          ),
        ),
      ),
    );
  }

  String _initialsFromEmail(String email) {
    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) return '?';
    final parts = localPart
        .split(RegExp(r'[._\-\s]+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return parts.take(3).map((p) => p[0].toUpperCase()).join();
    }
    final token = parts.first;
    if (token.length == 1) return token.toUpperCase();
    return token.substring(0, 2).toUpperCase();
  }
}
