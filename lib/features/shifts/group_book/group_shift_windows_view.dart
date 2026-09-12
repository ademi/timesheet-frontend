import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/form_sticky_actions.dart';
import '../../../shared/widgets/keyboard_time_field.dart';
import '../utils/participant_window_math.dart';

/// Args for full-screen per-participant window editor (local Done only).
class GroupShiftWindowsArgs {
  const GroupShiftWindowsArgs({
    required this.displayName,
    required this.windows,
    required this.shiftStart,
    required this.shiftEnd,
  });

  final String displayName;
  final List<ParticipantWindowDraft> windows;
  final DateTime shiftStart;
  final DateTime shiftEnd;
}

/// Form multi-window editor (D12). Done returns windows via [Get.back]; no API.
class GroupShiftWindowsView extends StatefulWidget {
  const GroupShiftWindowsView({super.key, required this.args});

  final GroupShiftWindowsArgs args;

  @override
  State<GroupShiftWindowsView> createState() => _GroupShiftWindowsViewState();
}

class _GroupShiftWindowsViewState extends State<GroupShiftWindowsView> {
  late List<ParticipantWindowDraft> _windows;
  String? _error;

  DateTime get _shiftStart => widget.args.shiftStart;
  DateTime get _shiftEnd => widget.args.shiftEnd;

  @override
  void initState() {
    super.initState();
    _windows =
        widget.args.windows.isEmpty
            ? defaultFullShiftWindows(_shiftStart, _shiftEnd)
            : [for (final w in widget.args.windows) w];
  }

  void _setWindow(int index, ParticipantWindowDraft next) {
    setState(() {
      _windows = [
        for (var i = 0; i < _windows.length; i++)
          if (i == index) next else _windows[i],
      ];
      _error = null;
    });
  }

  void _addWindow() {
    setState(() {
      _windows = [..._windows, ...defaultFullShiftWindows(_shiftStart, _shiftEnd)];
      _error = null;
    });
  }

  void _removeWindow(int index) {
    if (_windows.length <= 1) {
      setState(() => _error = 'Add at least one time window');
      return;
    }
    setState(() {
      _windows = [
        for (var i = 0; i < _windows.length; i++)
          if (i != index) _windows[i],
      ];
      _error = null;
    });
  }

  void _done() {
    final err = validateParticipantWindows(
      _windows,
      shiftStart: _shiftStart,
      shiftEnd: _shiftEnd,
    );
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Get.back(result: List<ParticipantWindowDraft>.unmodifiable(_windows));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Participant · ${widget.args.displayName}')),
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
                      Text(
                        formatShiftBoundsHint(_shiftStart, _shiftEnd),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Windows',
                              style: Get.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            for (var i = 0; i < _windows.length; i++) ...[
                              _WindowRow(
                                window: _windows[i],
                                onChanged: (w) => _setWindow(i, w),
                                onRemove: () => _removeWindow(i),
                              ),
                              if (validateSingleWindow(
                                    _windows[i],
                                    shiftStart: _shiftStart,
                                    shiftEnd: _shiftEnd,
                                  ) !=
                                  null) ...[
                                const SizedBox(height: 4),
                                _InlineError(
                                  validateSingleWindow(
                                    _windows[i],
                                    shiftStart: _shiftStart,
                                    shiftEnd: _shiftEnd,
                                  )!,
                                ),
                              ],
                              const SizedBox(height: 8),
                            ],
                            OutlinedButton(
                              onPressed: _addWindow,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                              ),
                              child: const Text('+ Add window'),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _InlineError(_error!),
                      ],
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

class _WindowRow extends StatelessWidget {
  const _WindowRow({
    required this.window,
    required this.onChanged,
    required this.onRemove,
  });

  final ParticipantWindowDraft window;
  final ValueChanged<ParticipantWindowDraft> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final startLocal = window.start.toLocal();
    final endLocal = window.end.toLocal();
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _MiniDateTile(
                    label: 'Start date',
                    value: startLocal,
                    onSelected: (d) {
                      onChanged(
                        window.copyWith(
                          start: DateTime(
                            d.year,
                            d.month,
                            d.day,
                            startLocal.hour,
                            startLocal.minute,
                          ),
                        ),
                      );
                    },
                  ),
                  KeyboardTimeField(
                    label: 'Start time',
                    value: TimeOfDay(
                      hour: startLocal.hour,
                      minute: startLocal.minute,
                    ),
                    onChanged: (t) {
                      onChanged(
                        window.copyWith(
                          start: DateTime(
                            startLocal.year,
                            startLocal.month,
                            startLocal.day,
                            t.hour,
                            t.minute,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  _MiniDateTile(
                    label: 'End date',
                    value: endLocal,
                    onSelected: (d) {
                      onChanged(
                        window.copyWith(
                          end: DateTime(
                            d.year,
                            d.month,
                            d.day,
                            endLocal.hour,
                            endLocal.minute,
                          ),
                        ),
                      );
                    },
                  ),
                  KeyboardTimeField(
                    label: 'End time',
                    value: TimeOfDay(
                      hour: endLocal.hour,
                      minute: endLocal.minute,
                    ),
                    onChanged: (t) {
                      onChanged(
                        window.copyWith(
                          end: DateTime(
                            endLocal.year,
                            endLocal.month,
                            endLocal.day,
                            t.hour,
                            t.minute,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove window',
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniDateTile extends StatelessWidget {
  const _MiniDateTile({
    required this.label,
    required this.value,
    required this.onSelected,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 12)),
      subtitle: Text(
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
      ),
      trailing: const Icon(Icons.calendar_today_outlined, size: 18),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onSelected(picked);
      },
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.error,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
