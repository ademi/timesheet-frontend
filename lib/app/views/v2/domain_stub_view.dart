import 'package:flutter/material.dart';

import '../../themes/app_colors.dart';

/// Placeholder screen for DOMAIN_V2 shell destinations (Phase 2 stubs).
class DomainStubView extends StatelessWidget {
  const DomainStubView({
    super.key,
    required this.title,
    this.subtitle =
        'Phase 2 stub — feature UI lands in Phase 3.',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction_rounded,
                  size: 48, color: AppColors.primary.withValues(alpha: 0.7)),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.textDark),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
