import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../bindings/clients_binding.dart';
import '../controllers/support_plan_controller.dart';
import '../data/models/strengths_needs_models.dart';
import '../data/repositories/clients_repository.dart';
import '../utils/strengths_needs_keys.dart';

class SupportPlanSnSection extends StatefulWidget {
  const SupportPlanSnSection({
    super.key,
    required this.planController,
    required this.clientId,
  });

  final SupportPlanController planController;
  final String clientId;

  @override
  State<SupportPlanSnSection> createState() => _SupportPlanSnSectionState();
}

class _SupportPlanSnSectionState extends State<SupportPlanSnSection> {
  bool _loading = true;
  StrengthsNeedsDto? _current;
  String? _error;

  ClientsRepository get _repository => Get.find<ClientsRepository>();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      StrengthsNeedsDto? pick;
      try {
        pick = await _repository.getCurrentStrengthsNeeds(widget.clientId);
      } on AppFailure catch (e) {
        if (e.statusCode != 404) rethrow;
      }
      pick ??= await _loadDraft();
      if (!mounted) return;
      setState(() {
        _current = pick;
        _loading = false;
      });
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load Strengths & Needs status.';
        _loading = false;
      });
    }
  }

  Future<StrengthsNeedsDto?> _loadDraft() async {
    final list = await _repository.listStrengthsNeeds(widget.clientId);
    for (final item in list) {
      if (item.status == StrengthsNeedsKeys.statusDraft) {
        return item;
      }
    }
    return null;
  }

  Future<void> _openEditor() async {
    ClientsBinding.ensureShared();
    final result = await Get.toNamed(
      AppRoutes.staffClientStrengthsNeeds,
      arguments: {
        'clientId': widget.clientId,
        if (_current != null) 'assessmentId': _current!.id,
      },
    );
    if (result == true) {
      await _reload();
    }
  }

  Future<void> _importToPlan() async {
    final assessment = _current;
    if (assessment == null ||
        assessment.status != StrengthsNeedsKeys.statusSubmitted) {
      return;
    }
    final selected = {...StrengthsNeedsKeys.defaultImportKeys};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Import to care plan'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Imported content may be visible to assigned workers '
                      'on shift brief. Uncheck sections you do not want copied.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final key in StrengthsNeedsKeys.defaultImportKeys)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(StrengthsNeedsKeys.labelFor(key)),
                        value: selected.contains(key),
                        onChanged: (v) {
                          setDialogState(() {
                            if (v == true) {
                              selected.add(key);
                            } else {
                              selected.remove(key);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(ctx, true),
                  child: const Text('Import'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true || !mounted) return;

    try {
      await _repository.importStrengthsNeedsToPlan(
        widget.clientId,
        assessment.id,
        SnImportRequest(sectionKeys: selected.toList()..sort()),
      );
      await widget.planController.load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imported into care plan draft')),
      );
      await _reload();
    } on AppFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Strengths & Needs',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          )
        else if (_error != null)
          Text(
            _error!,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          )
        else ...[
          _StatusChip(assessment: _current),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _openEditor,
                child: Text(_current == null ? 'Start assessment' : 'Edit assessment'),
              ),
              if (_current?.status == StrengthsNeedsKeys.statusSubmitted)
                OutlinedButton(
                  onPressed: _importToPlan,
                  child: const Text('Import to plan'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.assessment});

  final StrengthsNeedsDto? assessment;

  @override
  Widget build(BuildContext context) {
    final label = switch (assessment?.status) {
      StrengthsNeedsKeys.statusDraft => 'Draft in progress',
      StrengthsNeedsKeys.statusSubmitted when assessment!.isCurrent =>
        'Submitted (current)',
      StrengthsNeedsKeys.statusSubmitted => 'Submitted',
      _ => 'No assessment yet',
    };
    return Text(
      label,
      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
    );
  }
}
