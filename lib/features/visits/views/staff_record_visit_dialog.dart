import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/keyboard_time_field.dart';
import '../data/models/visit_models.dart';

@visibleForTesting
DateTime defaultRecordArrival(VisitOut visit) =>
    (visit.clockInAt ?? visit.scheduledStart).toLocal();

@visibleForTesting
DateTime defaultRecordDeparture(VisitOut visit) =>
    (visit.clockOutAt ?? visit.scheduledEnd).toLocal();

@visibleForTesting
List<String> incompleteRequiredFormNames(VisitOut visit) {
  final submitted = {
    for (final s in visit.formSubmissions) s.formTemplateId,
  };
  return [
    for (final r in visit.formRequirements)
      if (r.isRequired && !submitted.contains(r.formTemplateId))
        (r.name != null && r.name!.trim().isNotEmpty)
            ? r.name!.trim()
            : 'Required form',
  ];
}

@visibleForTesting
bool visitMissingSupportItem(VisitOut visit) =>
    visit.supportItemCode == null || visit.supportItemCode!.trim().isEmpty;

Future<void> showStaffRecordVisitDialog({
  required BuildContext context,
  required VisitOut visit,
  required Future<bool> Function({
    required DateTime clockInAt,
    required DateTime clockOutAt,
    required String reason,
  })
  onSubmit,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder:
          (_) => _StaffRecordVisitPage(visit: visit, onSubmit: onSubmit),
    ),
  );
}

class _StaffRecordVisitPage extends StatefulWidget {
  const _StaffRecordVisitPage({required this.visit, required this.onSubmit});

  final VisitOut visit;
  final Future<bool> Function({
    required DateTime clockInAt,
    required DateTime clockOutAt,
    required String reason,
  })
  onSubmit;

  @override
  State<_StaffRecordVisitPage> createState() => _StaffRecordVisitPageState();
}

class _StaffRecordVisitPageState extends State<_StaffRecordVisitPage> {
  late DateTime _arrivalDate;
  late TimeOfDay _arrivalTime;
  late DateTime _departureDate;
  late TimeOfDay _departureTime;
  final _reasonController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final arrival = defaultRecordArrival(widget.visit);
    final departure = defaultRecordDeparture(widget.visit);
    _arrivalDate = DateTime(arrival.year, arrival.month, arrival.day);
    _arrivalTime = TimeOfDay(hour: arrival.hour, minute: arrival.minute);
    _departureDate = DateTime(departure.year, departure.month, departure.day);
    _departureTime = TimeOfDay(hour: departure.hour, minute: departure.minute);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  Future<void> _pickDate({required bool arrival}) async {
    final initial = arrival ? _arrivalDate : _departureDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (arrival) {
        _arrivalDate = DateTime(picked.year, picked.month, picked.day);
      } else {
        _departureDate = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Reason is required');
      return;
    }
    final inAt = _combine(_arrivalDate, _arrivalTime);
    final outAt = _combine(_departureDate, _departureTime);
    if (!outAt.isAfter(inAt)) {
      setState(() => _error = 'Departure must be after arrival');
      return;
    }
    final now = DateTime.now();
    if (inAt.isAfter(now.add(const Duration(minutes: 2))) ||
        outAt.isAfter(now.add(const Duration(minutes: 2)))) {
      setState(() => _error = 'Times cannot be in the future');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await widget.onSubmit(
      clockInAt: inAt,
      clockOutAt: outAt,
      reason: reason,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      AppToast.success('Visit recorded', 'Marked completed');
      return;
    }
    setState(() {
      _saving = false;
      _error = 'Could not record visit. Check the reason and try again.';
    });
  }

  String _dateLabel(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final visit = widget.visit;
    final contextBits = [
      if (visit.contractorName?.trim().isNotEmpty == true) visit.contractorName!,
      if (visit.jobTitle?.trim().isNotEmpty == true) visit.jobTitle!,
      visit.status,
    ];
    final missingForms = incompleteRequiredFormNames(visit);
    final missingSupport = visitMissingSupportItem(visit);
    final showWarn = missingForms.isNotEmpty || missingSupport;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record visit'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: PageContent(
                width: PageContentWidth.narrow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      contextBits.join(' · '),
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Arrival',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed:
                          _saving ? null : () => _pickDate(arrival: true),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        alignment: Alignment.centerLeft,
                      ),
                      child: Text(_dateLabel(_arrivalDate)),
                    ),
                    const SizedBox(height: 8),
                    KeyboardTimeField(
                      value: _arrivalTime,
                      enabled: !_saving,
                      label: 'Arrival time',
                      onChanged: (t) => setState(() => _arrivalTime = t),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Departure',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed:
                          _saving ? null : () => _pickDate(arrival: false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        alignment: Alignment.centerLeft,
                      ),
                      child: Text(_dateLabel(_departureDate)),
                    ),
                    const SizedBox(height: 8),
                    KeyboardTimeField(
                      value: _departureTime,
                      enabled: !_saving,
                      label: 'Departure time',
                      onChanged: (t) => setState(() => _departureTime = t),
                    ),
                    if (showWarn) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        container: true,
                        liveRegion: true,
                        label: 'Before you record',
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.openSlotBackground,
                            border: Border.all(
                              color: AppColors.openSlot.withValues(alpha: 0.45),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Before you record',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.openSlot,
                                ),
                              ),
                              const SizedBox(height: 6),
                              for (final name in missingForms)
                                Text(
                                  '• Still missing: $name — visit will complete anyway',
                                  style: const TextStyle(
                                    color: AppColors.openSlot,
                                    fontSize: 13,
                                  ),
                                ),
                              if (missingSupport)
                                const Text(
                                  '• No NDIS support item — set it on visit detail or invoice export will fail',
                                  style: TextStyle(
                                    color: AppColors.openSlot,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: _reasonController,
                      enabled: !_saving,
                      maxLength: 2000,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Reason (required)',
                        helperText:
                            'Stored on the attendance audit — why GPS/forms were skipped.',
                        helperMaxLines: 2,
                        hintText: 'e.g. Paper timesheet from Saturday',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Material(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
              child: PageContent(
                width: PageContentWidth.narrow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    Semantics(
                      button: true,
                      label: 'Record visit',
                      child: AsyncElevatedButton(
                        onPressed: _submit,
                        isLoading: _saving,
                        child: const Text('Record visit'),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
