import 'package:flutter/material.dart';

import '../services/auth_session.dart';

class ProfileMenuButton extends StatelessWidget {
  const ProfileMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AuthSession.current;
    final email = session?.loginEmail ?? '';
    final initials = _initialsFromEmail(email);
    final showKnowledgeBase = session?.user.isClient != true;

    return PopupMenuButton<String>(
      tooltip: 'Account menu',
      onSelected: (value) {
        switch (value) {
          case 'profile':
            Navigator.pushNamed(context, '/profile');
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
          child: Text(
            initials,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
