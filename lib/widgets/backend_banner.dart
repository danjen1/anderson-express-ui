import 'package:flutter/material.dart';

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
            'Active: ${config.label}  •  ${config.baseUrl}',
            style: TextStyle(
              color: Colors.blue.shade900,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}
