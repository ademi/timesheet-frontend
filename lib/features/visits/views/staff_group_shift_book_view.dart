import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../../clients/data/models/client_models.dart';
import '../../shifts/data/models/shift_participant_models.dart';
import '../controllers/staff_visits_controller.dart';
import '../widgets/group_shift_participant_capacity_row.dart';

const kMaxGroupWizardParticipants = 8;

class StaffGroupShiftBookView extends StatefulWidget {
  const StaffGroupShiftBookView({super.key});

  @override
  State<StaffGroupShiftBookView> createState() =>
      _StaffGroupShiftBookViewState();
}

class _StaffGroupShiftBookViewState extends State<StaffGroupShiftBookView> {
  final _capacityFormKey = GlobalKey<FormState>();
  final _participants = <_CapacityEntry>[];

  late final StaffVisitsController _controller;
  List<ClientOut> _clients = const [];
  int _currentStep = 0;
  String? _hostId;
  late DateTime _start;
  late DateTime _end;
  int _requiredSlots = 1;
  bool _loadingClients = true;
  bool _creating = false;

  static const _stepNames = ['Host & participants', 'When & workers', 'Review'];

  @override
  void initState() {
    super.initState();
    _controller = Get.find<StaffVisitsController>();
    _start = DateTime.now().add(const Duration(hours: 1));
    _end = _start.add(const Duration(hours: 2));
    _loadClients();
  }

  Future<void> _loadClients() async {
    await _controller.loadClientsForPicker();
    if (!mounted) return;
    setState(() {
      _clients = List<ClientOut>.of(_controller.clientsForPicker);
      _loadingClients = false;
    });
  }

  @override
  void dispose() {
    for (final participant in _participants) {
      participant.dispose();
    }
    super.dispose();
  }

  String _clientName(String id) {
    for (final client in _clients) {
      if (client.id == id) return client.fullName;
    }
    return id;
  }

  double get _capacitySum => _participants.fold(
    0,
    (total, participant) => total + participant.capacity,
  );

  double get _remainingCapacity => math.max(0, 100 - _capacitySum);

  bool get _canContinueStepOne {
    final hostId = _hostId;
    return hostId != null &&
        _participants.isNotEmpty &&
        _participants.any((participant) => participant.clientId == hostId) &&
        _participants.every(
          (participant) =>
              participant.capacity > 0 && participant.capacity <= 100,
        ) &&
        _capacitySum <= 100.0001;
  }

  String _formatCapacity(double value) =>
      value == value.roundToDouble()
          ? '${value.round()}'
          : value.toStringAsFixed(1);

  void _selectHost(String? clientId) {
    if (clientId == null || clientId == _hostId) return;

    final oldHostIndex = _participants.indexWhere((entry) => entry.isHost);
    final existingIndex = _participants.indexWhere(
      (entry) => entry.clientId == clientId,
    );

    setState(() {
      if (_participants.isEmpty || oldHostIndex < 0) {
        if (existingIndex >= 0) {
          _participants[existingIndex].isHost = true;
        } else {
          _participants.insert(
            0,
            _CapacityEntry(clientId: clientId, capacity: 100, isHost: true),
          );
        }
      } else {
        if (existingIndex >= 0 && existingIndex != oldHostIndex) {
          _participants[existingIndex].dispose();
          _participants.removeAt(existingIndex);
        }
        final currentHostIndex = _participants.indexWhere(
          (entry) => entry.isHost,
        );
        _participants[currentHostIndex].clientId = clientId;
      }
      _hostId = clientId;
    });
  }

  void _addParticipant(String? clientId) {
    if (clientId == null) return;
    final remaining = 100 - _capacitySum;
    if (remaining <= 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reduce someone’s capacity first')),
      );
      return;
    }
    setState(() {
      _participants.add(
        _CapacityEntry(
          clientId: clientId,
          capacity: math.min(remaining, 100),
          isHost: false,
        ),
      );
    });
  }

  void _removeParticipant(_CapacityEntry participant) {
    setState(() => _participants.remove(participant));
    participant.dispose();
  }

  void _goBack() {
    if (_currentStep == 0) {
      Get.back();
    } else {
      setState(() => _currentStep--);
    }
  }

  void _next() {
    if (_currentStep == 0) {
      if (!_capacityFormKey.currentState!.validate() || !_canContinueStepOne) {
        return;
      }
    } else if (_currentStep == 1 && !_end.isAfter(_start)) {
      return;
    }
    setState(() => _currentStep++);
  }

  Future<void> _createDraft() async {
    if (_creating) return;
    setState(() => _creating = true);
    final ok = await _controller.bookGroupShift(
      hostClientId: _hostId!,
      start: _start,
      end: _end,
      requiredSlots: _requiredSlots,
      participants: [
        for (final participant in _participants)
          ShiftParticipantCreateRequest(
            participantId: participant.clientId,
            allocationStrategy: 'percentage',
            allocationValue: participant.capacity,
            reason: 'Initial group split',
          ),
      ],
    );
    if (!mounted) return;
    setState(() => _creating = false);
    if (!ok && _controller.errorMessage.value != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_controller.errorMessage.value!)));
    }
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _formatDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: _currentStep == 0 ? 'Back' : 'Previous step',
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New group shift'),
            Text(
              'Step ${_currentStep + 1} of 3 — ${_stepNames[_currentStep]}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: switch (_currentStep) {
              0 => _buildParticipantsStep(),
              1 => _buildWhenStep(),
              _ => _buildReviewStep(),
            },
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_currentStep == 0) ...[
                Text(
                  'Sum: ${_formatCapacity(_capacitySum)}% · '
                  'Remaining: ${_formatCapacity(_remainingCapacity)}%',
                  key: const Key('group-shift-capacity-sum'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        _capacitySum > 100
                            ? AppColors.error
                            : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              AsyncElevatedButton(
                key: const Key('group-shift-primary-action'),
                onPressed:
                    _primaryActionEnabled
                        ? (_currentStep == 2 ? _createDraft : _next)
                        : null,
                isLoading: _creating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(_currentStep == 2 ? 'Create draft' : 'Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _primaryActionEnabled {
    if (_loadingClients || _creating) return false;
    if (_currentStep == 0) return _canContinueStepOne;
    if (_currentStep == 1) return _end.isAfter(_start);
    return true;
  }

  Widget _buildParticipantsStep() {
    final atMaximum = _participants.length >= kMaxGroupWizardParticipants;
    final addedIds =
        _participants.map((participant) => participant.clientId).toSet();
    final available = _clients
        .where(
          (client) => client.id != _hostId && !addedIds.contains(client.id),
        )
        .toList(growable: false);

    return Form(
      key: _capacityFormKey,
      child: Column(
        key: const ValueKey('participants-step'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loadingClients)
            const Center(child: CircularProgressIndicator())
          else if (_clients.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'No clients yet. Open a client and book from there, '
                'or start ongoing support first.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          DropdownButtonFormField<String>(
            key: const Key('group-shift-host'),
            value: _hostId,
            isExpanded: true,
            items: [
              for (final client in _clients)
                DropdownMenuItem(
                  value: client.id,
                  child: Text(client.fullName, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _loadingClients ? null : _selectHost,
            decoration: const InputDecoration(
              labelText: 'Host client',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _hostId == null
                ? 'Pick a host client first.'
                : 'Host added at 100%. Add others and adjust capacity.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          for (final participant in _participants)
            GroupShiftParticipantCapacityRow(
              key: ValueKey(participant.clientId),
              clientName: _clientName(participant.clientId),
              capacityController: participant.controller,
              isHost: participant.isHost,
              onCapacityChanged: (_) => setState(() {}),
              onRemove: () => _removeParticipant(participant),
            ),
          if (_capacitySum > 100.0001)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Capacity total cannot exceed 100%.',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          DropdownButtonFormField<String>(
            key: const Key('group-shift-add-participant'),
            value: null,
            isExpanded: true,
            items: [
              for (final client in available)
                DropdownMenuItem(
                  value: client.id,
                  child: Text(client.fullName, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged:
                _hostId == null || atMaximum || available.isEmpty
                    ? null
                    : _addParticipant,
            decoration: const InputDecoration(
              labelText: 'Add participant',
              border: OutlineInputBorder(),
            ),
          ),
          if (atMaximum)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Maximum 8 participants in this flow.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWhenStep() {
    return Column(
      key: const ValueKey('when-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Host owns the job; others are billed as participants.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        ListTile(
          key: const Key('group-shift-start'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Start'),
          subtitle: Text(_formatDateTime(_start)),
          trailing: const Icon(Icons.calendar_today_outlined),
          minVerticalPadding: 12,
          onTap: () async {
            final picked = await _pickDateTime(_start);
            if (picked == null) return;
            setState(() {
              _start = picked;
              if (!_end.isAfter(_start)) {
                _end = _start.add(const Duration(hours: 1));
              }
            });
          },
        ),
        ListTile(
          key: const Key('group-shift-end'),
          contentPadding: EdgeInsets.zero,
          title: const Text('End'),
          subtitle: Text(_formatDateTime(_end)),
          trailing: const Icon(Icons.calendar_today_outlined),
          minVerticalPadding: 12,
          onTap: () async {
            final picked = await _pickDateTime(_end);
            if (picked != null) setState(() => _end = picked);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: const Key('group-shift-worker-slots'),
          value: _requiredSlots,
          items: [
            for (var slots = 1; slots <= 8; slots++)
              DropdownMenuItem(value: slots, child: Text('$slots')),
          ],
          onChanged: (value) => setState(() => _requiredSlots = value ?? 1),
          decoration: const InputDecoration(
            labelText: 'Required workers',
            border: OutlineInputBorder(),
          ),
        ),
        if (!_end.isAfter(_start))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'End must be after start.',
              style: TextStyle(color: AppColors.error),
            ),
          ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      key: const ValueKey('review-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Host', style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(
          _clientName(_hostId!),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        const Text(
          'Capacity',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const Divider(),
        for (final participant in _participants)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    participant.isHost
                        ? '${_clientName(participant.clientId)} (host)'
                        : _clientName(participant.clientId),
                  ),
                ),
                Text('${_formatCapacity(participant.capacity)}%'),
              ],
            ),
          ),
        const Divider(),
        if ((_capacitySum - 100).abs() > 0.0001)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Draft OK under 100%; you must reach 100% before publish.',
              style: TextStyle(
                color: AppColors.openSlot,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 20),
        const Text('When', style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text('${_formatDateTime(_start)} – ${_formatDateTime(_end)}'),
        const SizedBox(height: 20),
        const Text(
          'Worker slots',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Text('$_requiredSlots'),
      ],
    );
  }
}

class _CapacityEntry {
  _CapacityEntry({
    required this.clientId,
    required double capacity,
    required this.isHost,
  }) : controller = TextEditingController(
         text:
             capacity == capacity.roundToDouble()
                 ? '${capacity.round()}'
                 : capacity.toStringAsFixed(1),
       );

  String clientId;
  bool isHost;
  final TextEditingController controller;

  double get capacity => double.tryParse(controller.text.trim()) ?? 0;

  void dispose() => controller.dispose();
}
