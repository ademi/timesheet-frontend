import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../data/models/shift_participant_models.dart';

typedef ShiftClientOption = ({String id, String name});

/// Shared add/edit form for shift participant allocation (percentage or time-based).
class ParticipantAllocationForm extends StatefulWidget {
  const ParticipantAllocationForm({
    super.key,
    required this.clients,
    required this.excludeClientIds,
    required this.shiftStart,
    required this.shiftEnd,
    this.lockStrategy,
    this.remainingPercentage = 100,
    this.submitLabel = 'Add',
    this.initialParticipantId,
    this.initialAllocationValue,
    this.initialReason,
    this.initialTimeWindows,
    required this.onSubmit,
    this.onSubmitUpdate,
  });

  final List<ShiftClientOption> clients;
  final Set<String> excludeClientIds;
  final DateTime shiftStart;
  final DateTime shiftEnd;
  final String? lockStrategy;
  final double remainingPercentage;
  final String submitLabel;
  final String? initialParticipantId;
  final double? initialAllocationValue;
  final String? initialReason;
  final List<ShiftParticipantAllocationWindow>? initialTimeWindows;
  final FutureOr<void> Function(ShiftParticipantCreateRequest request) onSubmit;
  final FutureOr<void> Function(ShiftParticipantAllocationUpdateRequest request)?
      onSubmitUpdate;

  bool get isEditMode =>
      initialParticipantId != null && onSubmitUpdate != null;

  @override
  State<ParticipantAllocationForm> createState() =>
      _ParticipantAllocationFormState();
}

class _ParticipantAllocationFormState extends State<ParticipantAllocationForm> {
  final _formKey = GlobalKey<FormState>();
  final _percentageController = TextEditingController();
  final _reasonController = TextEditingController();

  String? _selectedClientId;
  late String _strategy;
  final List<_EditableTimeWindow> _timeWindows = [];
  String? _errorMessage;
  bool _isSubmitting = false;

  List<ShiftClientOption> get _availableClients => widget.clients
      .where((c) => !widget.excludeClientIds.contains(c.id))
      .toList(growable: false);

  bool get _isPercentage => _strategy == 'percentage';

  double get _enteredPercentage {
    final parsed = double.tryParse(_percentageController.text.trim());
    return parsed ?? 0;
  }

  double get _displayRemaining {
    if (!_isPercentage) return widget.remainingPercentage;
    return widget.remainingPercentage - _enteredPercentage;
  }

  @override
  void initState() {
    super.initState();
    _strategy = widget.lockStrategy ?? 'percentage';
    _selectedClientId = widget.initialParticipantId ??
        (_availableClients.length == 1 ? _availableClients.first.id : null);

    if (widget.initialAllocationValue != null) {
      _percentageController.text = _formatPercentage(widget.initialAllocationValue!);
    }
    if (widget.initialReason != null) {
      _reasonController.text = widget.initialReason!;
    }

    final initialWindows = widget.initialTimeWindows;
    if (initialWindows != null && initialWindows.isNotEmpty) {
      _timeWindows.addAll(
        initialWindows.map(
          (w) => _EditableTimeWindow(
            start: w.participantStartTime.toLocal(),
            end: w.participantEndTime.toLocal(),
          ),
        ),
      );
    } else if (_strategy == 'time_based') {
      _timeWindows.add(
        _EditableTimeWindow(
          start: widget.shiftStart.toLocal(),
          end: widget.shiftEnd.toLocal(),
        ),
      );
    }

    _percentageController.addListener(_onPercentageChanged);
  }

  @override
  void dispose() {
    _percentageController.removeListener(_onPercentageChanged);
    _percentageController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _onPercentageChanged() => setState(() {});

  String _formatPercentage(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toString();
  }

  String _hhmm(DateTime dt) {
    final l = dt.toLocal();
    final h = l.hour.toString().padLeft(2, '0');
    final m = l.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  DateTime _combineWithShiftDate(TimeOfDay time, DateTime reference) {
    return DateTime(
      reference.year,
      reference.month,
      reference.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _pickTime({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (picked == null) return;
    onPicked(_combineWithShiftDate(picked, initial));
  }

  void _addTimeWindow() {
    setState(() {
      _timeWindows.add(
        _EditableTimeWindow(
          start: widget.shiftStart.toLocal(),
          end: widget.shiftEnd.toLocal(),
        ),
      );
    });
  }

  void _removeTimeWindow(int index) {
    if (_timeWindows.length <= 1) return;
    setState(() => _timeWindows.removeAt(index));
  }

  String? _validateClient(String? value) {
    if (widget.isEditMode) return null;
    if (value == null || value.isEmpty) {
      return 'Select a client';
    }
    return null;
  }

  String? _validatePercentage(String? value) {
    if (!_isPercentage) return null;
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter a percentage';
    final parsed = double.tryParse(text);
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0 || parsed > 100) return 'Must be between 0 and 100';
    // Parent passes remaining budget including this row's current share in edit mode.
    if (parsed > widget.remainingPercentage + 0.001) {
      return 'Exceeds remaining ${widget.remainingPercentage.toStringAsFixed(0)}%';
    }
    return null;
  }

  String? _validateReason(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Reason is required';
    return null;
  }

  bool _validateTimeWindows() {
    final shiftStart = widget.shiftStart.toLocal();
    final shiftEnd = widget.shiftEnd.toLocal();
    if (_timeWindows.isEmpty) {
      _errorMessage = 'Add at least one time window';
      return false;
    }
    for (var i = 0; i < _timeWindows.length; i++) {
      final window = _timeWindows[i];
      if (!window.end.isAfter(window.start)) {
        _errorMessage = 'Window ${i + 1}: end must be after start';
        return false;
      }
      if (window.start.isBefore(shiftStart) || window.end.isAfter(shiftEnd)) {
        _errorMessage = 'Window ${i + 1} must be within shift times';
        return false;
      }
    }
    return true;
  }

  Future<void> _handleSubmit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    if (!_isPercentage && !_validateTimeWindows()) {
      setState(() {});
      return;
    }

    final reason = _reasonController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      if (widget.isEditMode) {
        final body = ShiftParticipantAllocationUpdateRequest(
          allocationValue: _enteredPercentage,
          reason: reason,
        );
        await widget.onSubmitUpdate!(body);
      } else {
        final participantId = _selectedClientId;
        if (participantId == null) {
          setState(() {
            _errorMessage = 'Select a client';
            _isSubmitting = false;
          });
          return;
        }

        final body = ShiftParticipantCreateRequest(
          participantId: participantId,
          allocationStrategy: _strategy,
          allocationValue: _isPercentage ? _enteredPercentage : 0,
          reason: reason,
          timeWindows: _isPercentage
              ? null
              : _timeWindows
                  .map(
                    (w) => ShiftParticipantAllocationWindow(
                      participantStartTime: w.start,
                      participantEndTime: w.end,
                    ),
                  )
                  .toList(growable: false),
        );
        await widget.onSubmit(body);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strategyLocked = widget.lockStrategy != null;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            key: const Key('participant-allocation-form-strategy'),
            value: _strategy,
            decoration: const InputDecoration(
              labelText: 'Allocation strategy',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'percentage',
                child: Text('Percentage'),
              ),
              DropdownMenuItem(
                value: 'time_based',
                child: Text('Time-based'),
              ),
            ],
            onChanged: strategyLocked
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _strategy = value;
                      if (value == 'time_based' && _timeWindows.isEmpty) {
                        _timeWindows.add(
                          _EditableTimeWindow(
                            start: widget.shiftStart.toLocal(),
                            end: widget.shiftEnd.toLocal(),
                          ),
                        );
                      }
                    });
                  },
          ),
          const SizedBox(height: 12),
          if (widget.isEditMode)
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Client',
                border: OutlineInputBorder(),
              ),
              child: Text(
                widget.clients
                        .where((c) => c.id == widget.initialParticipantId)
                        .map((c) => c.name)
                        .firstOrNull ??
                    'Participant',
              ),
            )
          else
            DropdownButtonFormField<String>(
              key: const Key('participant-allocation-form-client'),
              value: _selectedClientId,
              decoration: const InputDecoration(
                labelText: 'Client',
                border: OutlineInputBorder(),
              ),
              items: _availableClients
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name),
                    ),
                  )
                  .toList(growable: false),
              validator: _validateClient,
              onChanged: (value) => setState(() => _selectedClientId = value),
            ),
          if (_isPercentage) ...[
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('participant-allocation-form-percentage'),
              controller: _percentageController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Capacity (%)',
                border: OutlineInputBorder(),
              ),
              validator: _validatePercentage,
            ),
            const SizedBox(height: 8),
            Text(
              'Remaining: ${_displayRemaining.toStringAsFixed(0)}%',
              key: const Key('participant-allocation-form-remaining'),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ...List.generate(_timeWindows.length, (index) {
              final window = _timeWindows[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Window ${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        if (_timeWindows.length > 1)
                          IconButton(
                            tooltip: 'Remove window',
                            onPressed: () => _removeTimeWindow(index),
                            icon: const Icon(Icons.close, size: 20),
                          ),
                      ],
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start time'),
                      subtitle: Text(_hhmm(window.start)),
                      onTap: () => _pickTime(
                        initial: window.start,
                        onPicked: (picked) {
                          setState(() {
                            window.start = picked;
                            if (!window.end.isAfter(window.start)) {
                              window.end = window.start.add(
                                const Duration(minutes: 30),
                              );
                            }
                          });
                        },
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('End time'),
                      subtitle: Text(_hhmm(window.end)),
                      onTap: () => _pickTime(
                        initial: window.end,
                        onPicked: (picked) {
                          setState(() => window.end = picked);
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('participant-allocation-form-add-window'),
                onPressed: _addTimeWindow,
                icon: const Icon(Icons.add),
                label: const Text('Add window'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('participant-allocation-form-reason'),
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(),
            ),
            validator: _validateReason,
            minLines: 1,
            maxLines: 3,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error),
            ),
          ],
          const SizedBox(height: 16),
          AsyncElevatedButton(
            key: const Key('participant-allocation-form-submit'),
            onPressed: _isSubmitting ? null : _handleSubmit,
            isLoading: _isSubmitting,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}

class _EditableTimeWindow {
  _EditableTimeWindow({required this.start, required this.end});

  DateTime start;
  DateTime end;
}
