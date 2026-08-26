import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../../clients/data/models/support_plan_models.dart';

/// Read-only contractor shift brief (Phase 1 — before Tasks, no budget UI).
class ShiftBriefPanel extends StatelessWidget {
  const ShiftBriefPanel({
    super.key,
    this.brief,
    this.isLoading = false,
    this.errorMessage,
  });

  final ShiftBriefDto? brief;
  final bool isLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        Text('Shift brief', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (errorMessage != null && errorMessage!.isNotEmpty)
          _ErrorNotice(message: errorMessage!)
        else if (brief == null)
          const Text(
            'No shift brief available.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          )
        else
          _BriefBody(brief: brief!),
      ],
    );
  }
}

class _BriefBody extends StatelessWidget {
  const _BriefBody({required this.brief});

  final ShiftBriefDto brief;

  @override
  Widget build(BuildContext context) {
    final invalid = brief.planBodyInvalid;
    final allergy = brief.allergies?.trim();
    final meds = brief.medicationSchedule?.trim();
    final hasBsp = brief.behaviourSupportPlan == true;
    final access = brief.accessNotes?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (brief.clientName.trim().isNotEmpty) ...[
          Text(
            brief.clientName.trim(),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (invalid) ...[
          const _UnavailableNotice(),
          const SizedBox(height: 12),
        ],
        if (allergy != null && allergy.isNotEmpty) ...[
          _AmberNotice(message: 'Allergies: $allergy'),
          const SizedBox(height: 8),
        ],
        if (!invalid && meds != null && meds.isNotEmpty) ...[
          _AmberNotice(message: 'Medication: $meds'),
          const SizedBox(height: 8),
        ],
        if (!invalid && hasBsp) ...[
          const _AmberNotice(
            message: 'Behaviour support plan (BSP) in place',
          ),
          const SizedBox(height: 8),
        ],
        if (!invalid) ...[
          _CommunicationSection(brief: brief),
          _GoalsSection(goals: brief.goals),
          _RiskSection(brief: brief),
          if (_hasPreferences(brief)) ...[
            const _SectionTitle('Preferences'),
            if (_nonEmpty(brief.routines))
              _SoftField(label: 'Routines', value: brief.routines!),
            if (_nonEmpty(brief.preferredSupportStyle))
              _SoftField(
                label: 'Preferred support style',
                value: brief.preferredSupportStyle!,
              ),
            if (_nonEmpty(brief.informalSupports))
              _SoftField(
                label: 'Informal supports',
                value: brief.informalSupports!,
              ),
            if (_nonEmpty(brief.mobilityNeeds))
              _SoftField(label: 'Mobility', value: brief.mobilityNeeds!),
            if (brief.supportIntensity != null &&
                brief.supportIntensity!.trim().isNotEmpty)
              _SoftField(
                label: 'Support intensity',
                value: brief.supportIntensity!,
              ),
            if (brief.serviceCategories.isNotEmpty)
              _SoftField(
                label: 'Service categories',
                value: brief.serviceCategories.join(', '),
              ),
          ],
        ],
        if (access != null && access.isNotEmpty) ...[
          const _SectionTitle('Access notes'),
          _SoftInfoBox(message: access),
        ],
      ],
    );
  }

  static bool _hasPreferences(ShiftBriefDto b) =>
      _nonEmpty(b.routines) ||
      _nonEmpty(b.preferredSupportStyle) ||
      _nonEmpty(b.informalSupports) ||
      _nonEmpty(b.mobilityNeeds) ||
      (b.supportIntensity != null && b.supportIntensity!.trim().isNotEmpty) ||
      b.serviceCategories.isNotEmpty;

  static bool _nonEmpty(String? s) => s != null && s.trim().isNotEmpty;
}

class _CommunicationSection extends StatelessWidget {
  const _CommunicationSection({required this.brief});

  final ShiftBriefDto brief;

  @override
  Widget build(BuildContext context) {
    final methods = brief.communicationMethods
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (methods.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Communication'),
        _SoftField(label: 'Methods', value: methods.join(', ')),
      ],
    );
  }
}

class _GoalsSection extends StatelessWidget {
  const _GoalsSection({required this.goals});

  final List<Map<String, dynamic>> goals;

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Goals & instructions'),
        for (final g in goals) ...[
          if (_str(g, 'ndis_goal') != null)
            Text(
              _str(g, 'ndis_goal')!,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          if (_str(g, 'strategy') != null)
            Text(
              'Strategy: ${_str(g, 'strategy')}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          if (_str(g, 'worker_instructions') != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _str(g, 'worker_instructions')!,
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ],
    );
  }

  static String? _str(Map<String, dynamic> g, String key) {
    final v = g[key]?.toString().trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }
}

class _RiskSection extends StatelessWidget {
  const _RiskSection({required this.brief});

  final ShiftBriefDto brief;

  @override
  Widget build(BuildContext context) {
    final fields = <(String, String)>[
      if (_nonEmpty(brief.behavioursOfConcern))
        ('Behaviours of concern', brief.behavioursOfConcern!),
      if (_nonEmpty(brief.triggers)) ('Triggers', brief.triggers!),
      if (_nonEmpty(brief.deEscalation)) ('De-escalation', brief.deEscalation!),
      if (_nonEmpty(brief.crisisResponse))
        ('Crisis response', brief.crisisResponse!),
    ];
    if (fields.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Risk'),
        for (final f in fields) _SoftField(label: f.$1, value: f.$2),
      ],
    );
  }

  static bool _nonEmpty(String? s) => s != null && s.trim().isNotEmpty;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}

class _SoftField extends StatelessWidget {
  const _SoftField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _AmberNotice extends StatelessWidget {
  const _AmberNotice({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.openSlotBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.openSlot),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: AppColors.openSlot),
      ),
    );
  }
}

class _SoftInfoBox extends StatelessWidget {
  const _SoftInfoBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(fontSize: 13)),
    );
  }
}

class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Support plan unavailable — contact coordinator',
        style: TextStyle(fontSize: 13, color: AppColors.error),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: AppColors.error),
      ),
    );
  }
}
