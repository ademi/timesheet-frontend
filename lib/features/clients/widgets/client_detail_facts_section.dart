import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../utils/client_quick_facts.dart';

class ClientDetailFactsSection extends StatelessWidget {
  const ClientDetailFactsSection({super.key, required this.facts});

  final ClientQuickFacts? facts;

  @override
  Widget build(BuildContext context) {
    if (facts == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _row('Status', facts!.status),
        if (facts!.clientTypeName != null)
          _row('Type', facts!.clientTypeName!),
        if (facts!.dob != null) _row('Date of birth', facts!.dob!),
        if (facts!.ndisNumber != null) _row('NDIS', facts!.ndisNumber!),
        if (facts!.email != null) _row('Email', facts!.email!),
        if (facts!.phone != null) _row('Phone', facts!.phone!),
      ],
    );
  }
}

Widget _row(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );
}
