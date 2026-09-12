import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/form_sticky_actions.dart';
import '../../../shared/widgets/ndis_support_item_picker.dart';
import '../data/models/shift_models.dart';
import '../utils/publish_draft.dart';

class GroupShiftPublishOverrideArgs {
  const GroupShiftPublishOverrideArgs({
    required this.participant,
    this.defaultItemCode,
    this.defaultItemName,
    this.initial,
  });

  final ShiftParticipantOut participant;
  final String? defaultItemCode;
  final String? defaultItemName;
  final PublishParticipantOverrideDraft? initial;
}

/// Full-screen per-participant override editor (Done = local only).
class GroupShiftPublishOverrideView extends StatefulWidget {
  const GroupShiftPublishOverrideView({super.key, required this.args});

  final GroupShiftPublishOverrideArgs args;

  @override
  State<GroupShiftPublishOverrideView> createState() =>
      _GroupShiftPublishOverrideViewState();
}

class _GroupShiftPublishOverrideViewState
    extends State<GroupShiftPublishOverrideView> {
  late String? _itemCode;
  late String? _itemName;
  late final TextEditingController _baseCtrl;
  late final TextEditingController _saturdayCtrl;
  late final TextEditingController _sundayCtrl;
  late final TextEditingController _eveningCtrl;
  late final TextEditingController _nightCtrl;
  late final TextEditingController _phCtrl;
  late final TextEditingController _reasonCtrl;
  var _bandsExpanded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.args.initial;
    _itemCode = initial?.supportItemCode;
    _itemName = initial?.supportItemName;
    _baseCtrl = TextEditingController(
      text: _rateText(initial?.baseRate),
    );
    _saturdayCtrl = TextEditingController(
      text: _rateText(initial?.saturdayRate),
    );
    _sundayCtrl = TextEditingController(
      text: _rateText(initial?.sundayRate),
    );
    _eveningCtrl = TextEditingController(
      text: _rateText(initial?.eveningRate),
    );
    _nightCtrl = TextEditingController(
      text: _rateText(initial?.nightRate),
    );
    _phCtrl = TextEditingController(
      text: _rateText(initial?.publicHolidayRate),
    );
    _reasonCtrl = TextEditingController(text: initial?.reason ?? '');
    _bandsExpanded =
        initial?.saturdayRate != null ||
        initial?.sundayRate != null ||
        initial?.eveningRate != null ||
        initial?.nightRate != null ||
        initial?.publicHolidayRate != null;
  }

  @override
  void dispose() {
    _baseCtrl.dispose();
    _saturdayCtrl.dispose();
    _sundayCtrl.dispose();
    _eveningCtrl.dispose();
    _nightCtrl.dispose();
    _phCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _rateText(double? v) => v == null ? '' : v.toString();

  double? _parseRate(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  void _done() {
    final draft = PublishParticipantOverrideDraft(
      participantId: widget.args.participant.participantId,
      supportItemCode: _itemCode,
      supportItemName: _itemName,
      baseRate: _parseRate(_baseCtrl.text),
      saturdayRate: _parseRate(_saturdayCtrl.text),
      sundayRate: _parseRate(_sundayCtrl.text),
      eveningRate: _parseRate(_eveningCtrl.text),
      nightRate: _parseRate(_nightCtrl.text),
      publicHolidayRate: _parseRate(_phCtrl.text),
      reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
    );
    if (draft.isEmpty) {
      Get.back(result: draft);
      return;
    }
    final err = draft.validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Get.back(result: draft);
  }

  void _clearCustom() {
    Get.back(
      result: PublishParticipantOverrideDraft(
        participantId: widget.args.participant.participantId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name =
        widget.args.participant.participantName ??
        widget.args.participant.participantId;
    final defaultLabel =
        widget.args.defaultItemCode?.isNotEmpty == true
            ? widget.args.defaultItemCode!
            : 'default item';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Custom · $name')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PageContent(
                  width: PageContentWidth.narrow,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        'Applies instead of $defaultLabel for this participant.',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 16),
                      NdisSupportItemPicker(
                        supportItemCode: _itemCode,
                        supportItemName: _itemName,
                        labelText: 'Support item (optional)',
                        onChanged: ({
                          required supportItemCode,
                          required supportItemName,
                        }) {
                          setState(() {
                            _itemCode = supportItemCode;
                            _itemName = supportItemName;
                            _error = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _baseCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Base rate (optional)',
                          hintText: 'Negotiated unit price',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.]'),
                          ),
                        ],
                        onChanged: (_) => setState(() => _error = null),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(
                          () => _bandsExpanded = !_bandsExpanded,
                        ),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          alignment: Alignment.centerLeft,
                          foregroundColor: AppColors.primary,
                        ),
                        child: Text(
                          _bandsExpanded
                              ? 'Hide day-band rates'
                              : 'Day-band rates',
                        ),
                      ),
                      if (_bandsExpanded) ...[
                        _RateField(
                          controller: _saturdayCtrl,
                          label: 'Saturday rate',
                          onChanged: () => setState(() => _error = null),
                        ),
                        _RateField(
                          controller: _sundayCtrl,
                          label: 'Sunday rate',
                          onChanged: () => setState(() => _error = null),
                        ),
                        _RateField(
                          controller: _eveningCtrl,
                          label: 'Evening rate',
                          onChanged: () => setState(() => _error = null),
                        ),
                        _RateField(
                          controller: _nightCtrl,
                          label: 'Night rate',
                          onChanged: () => setState(() => _error = null),
                        ),
                        _RateField(
                          controller: _phCtrl,
                          label: 'Public holiday rate',
                          onChanged: () => setState(() => _error = null),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reasonCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Reason',
                          hintText: 'Required when any rate is set',
                        ),
                        maxLength: 500,
                        minLines: 2,
                        maxLines: 4,
                        onChanged: (_) => setState(() => _error = null),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _clearCustom,
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          foregroundColor: AppColors.textMuted,
                        ),
                        child: const Text('Use default'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          FormStickyActions(
            onCancel: () => Get.back(),
            primaryLabel: 'Done',
            onPrimary: _done,
          ),
        ],
      ),
    );
  }
}

class _RateField extends StatelessWidget {
  const _RateField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
        onChanged: (_) => onChanged(),
      ),
    );
  }
}
