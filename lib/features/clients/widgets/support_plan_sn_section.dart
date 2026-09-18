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
  StrengthsNeedsDto? _draft;
  StrengthsNeedsDto? _submittedCurrent;
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
      StrengthsNeedsDto? submittedCurrent;
      try {
        submittedCurrent =
            await _repository.getCurrentStrengthsNeeds(widget.clientId);
      } on AppFailure catch (e) {
        if (e.statusCode != 404) rethrow;
      }

      StrengthsNeedsDto? draft;
      final list = await _repository.listStrengthsNeeds(widget.clientId);
      for (final item in list) {
        if (item.status == StrengthsNeedsKeys.statusDraft) {
          draft = item;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _draft = draft;
        _submittedCurrent = submittedCurrent;
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

  StrengthsNeedsDto? get _editorTarget => _draft ?? _submittedCurrent;

  Future<void> _openEditor() async {
    ClientsBinding.ensureShared();
    final result = await Get.toNamed(
      AppRoutes.staffClientStrengthsNeeds,
      arguments: {
        'clientId': widget.clientId,
        if (_editorTarget != null) 'assessmentId': _editorTarget!.id,
      },
    );
    if (result == true) {
      await _reload();
    }
  }

  Future<void> _importToPlan() async {
    final assessment = _submittedCurrent;
    if (assessment == null) return;

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
          _StatusSummary(draft: _draft, submittedCurrent: _submittedCurrent),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _openEditor,
                child: Text(
                  _editorTarget == null ? 'Start assessment' : 'Edit assessment',
                ),
              ),
              if (_submittedCurrent != null)
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

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({
    required this.draft,
    required this.submittedCurrent,
  });

  final StrengthsNeedsDto? draft;
  final StrengthsNeedsDto? submittedCurrent;

  @override
  Widget build(BuildContext context) {
    if (draft == null && submittedCurrent == null) {
      return const Text(
        'No assessment yet',
        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
      );
    }

    final lines = <String>[];
    if (draft != null) {
      lines.add('Draft in progress');
    }
    if (submittedCurrent != null) {
      lines.add('Submitted (current)');
    }

    return Text(
      lines.join(' · '),
      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
    );
  }
}
