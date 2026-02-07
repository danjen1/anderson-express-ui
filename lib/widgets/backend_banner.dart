import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../services/backend_runtime.dart';

class BackendBanner extends StatelessWidget implements PreferredSizeWidget {
  const BackendBanner({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(42);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: BackendRuntime.listenable,
      builder: (context, config, _) {
        return ValueListenableBuilder(
          valueListenable: AuthSession.listenable,
          builder: (context, session, _) {
            final role = switch (session?.user) {
              null => 'Guest',
              final user when user.isAdmin => 'Admin',
              final user when user.isEmployee => 'Cleaner',
              final user when user.isClient => 'Client',
              _ => 'Unknown',
            };
            return Container(
              height: preferredSize.height,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(
                  top: BorderSide(color: Colors.blue.shade100),
                  bottom: BorderSide(color: Colors.blue.shade100),
                ),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                'Active: ${config.label}  •  ${config.baseUrl}  •  Role: $role',
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
