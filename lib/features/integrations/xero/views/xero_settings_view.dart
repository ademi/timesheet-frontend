import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/responsive/page_content.dart';
import '../../../../shared/utils/humanize_label.dart';
import '../../../../shared/utils/visit_datetime_format.dart';
import '../controllers/xero_settings_controller.dart';
import '../data/models/xero_models.dart';

/// Settings → Integrations → Xero (connect + mapping).
class XeroSettingsView extends GetView<XeroSettingsController> {
  const XeroSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Xero')),
      body: Obx(() {
        final loading = controller.isLoading.value;
        final st = controller.status.value;
        final err = controller.errorMessage.value;

        if (loading && st == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return PageContent(
          width: PageContentWidth.narrow,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text('Integrations', style: Get.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Send posted payment batches to Xero Payroll as drafts.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
              if (err != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    err,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Text('Connection', style: Get.textTheme.titleSmall),
              const SizedBox(height: 10),
              if (st != null && !st.featureEnabled)
                const Text(
                  'Xero integration is turned off for this environment.',
                  style: TextStyle(fontSize: 13),
                )
              else ...[
                _ConnectionPanel(status: st),
                const SizedBox(height: 12),
                if (controller.isConnected)
                  Row(
                    children: [
                      TextButton(
                        onPressed:
                            controller.isLoading.value ||
                                    controller.isMappingLoading.value
                                ? null
                                : () async {
                                  await controller.loadStatus();
                                  await controller.loadMappingData();
                                },
                        child: const Text('Refresh'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed:
                            controller.isDisconnecting.value
                                ? null
                                : controller.disconnect,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        child:
                            controller.isDisconnecting.value
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('Disconnect'),
                      ),
                    ],
                  )
                else
                  FilledButton(
                    onPressed:
                        !controller.canManageXero ||
                                controller.isConnecting.value
                            ? null
                            : controller.connect,
                    child:
                        controller.isConnecting.value
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Connect Xero'),
                  ),
                if (controller.isConnected) ...[
                  if (controller.mappingIncomplete) ...[
                    const SizedBox(height: 8),
                    const _MappingIncompleteBanner(),
                  ],
                  const SizedBox(height: 28),
                  Text('Mappings', style: Get.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    'Tap a row to choose the Xero match, then save.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (controller.isMappingLoading.value)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    const _MappingSection(),
                ],
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _MappingIncompleteBanner extends StatelessWidget {
  const _MappingIncompleteBanner();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<XeroSettingsController>();
    final workers = c.unmappedContractorIds.length;
    final bands = c.unmappedBandKeys.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.openSlotBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.openSlot.withValues(alpha: 0.28)),
      ),
      child: Text(
        '$workers worker(s) and $bands pay band(s) still need a map '
        'before Send to Xero.',
        style: const TextStyle(fontSize: 13, color: AppColors.openSlot),
      ),
    );
  }
}

class _MappingSection extends StatefulWidget {
  const _MappingSection();

  @override
  State<_MappingSection> createState() => _MappingSectionState();
}

class _MappingSectionState extends State<_MappingSection> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Workers')),
            ButtonSegment(value: 1, label: Text('Pay items')),
          ],
          selected: {_tab},
          onSelectionChanged: (next) {
            if (next.isEmpty) return;
            setState(() => _tab = next.first);
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.primary;
              }
              return AppColors.textMuted;
            }),
          ),
        ),
        const SizedBox(height: 14),
        if (_tab == 0) const _EmployeesMappingPanel() else const _PayItemsMappingPanel(),
      ],
    );
  }
}

class _EmployeesMappingPanel extends GetView<XeroSettingsController> {
  const _EmployeesMappingPanel();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final employees = controller.xeroEmployees;
      final rows = controller.contractorRows;

      if (employees.isEmpty) {
        return _EmptyCatalogue(
          title: 'No Xero employees found',
          body:
              'Create payroll employees in Xero (Demo Company AU for tests), '
              'then refresh.',
          onOpenXero: controller.openXeroInBrowser,
          onRefresh: controller.loadMappingData,
        );
      }

      if (rows.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No workers to map yet. Add engagements or create a payment batch first.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        );
      }

      final byId = {for (final e in employees) e.employeeId: e};
      final requiredUnmapped = controller.unmappedContractorIds.toSet();
      final sortedRows = [...rows]..sort((a, b) {
        final aRequired = requiredUnmapped.contains(a.contractorId);
        final bRequired = requiredUnmapped.contains(b.contractorId);
        if (aRequired != bRequired) return aRequired ? -1 : 1;
        final aSelected =
            controller.employeeSelection[a.contractorId]?.isNotEmpty == true;
        final bSelected =
            controller.employeeSelection[b.contractorId]?.isNotEmpty == true;
        if (aSelected != bSelected) return aSelected ? -1 : 1;
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Only workers on draft/posted payment batches must be mapped. '
            'Others are optional until they appear on a batch.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          _MappingListSurface(
            children: [
              for (var i = 0; i < sortedRows.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.divider),
                Builder(
                  builder: (context) {
                    final row = sortedRows[i];
                    final selected =
                        controller.employeeSelection[row.contractorId];
                    final hasSelection =
                        selected != null && selected.isNotEmpty;
                    final mapped =
                        hasSelection ? byId[selected] : null;
                    final pending = controller.isEmployeeMappingPending(
                      row.contractorId,
                    );
                    final required = requiredUnmapped.contains(
                      row.contractorId,
                    );
                    return _MapRow(
                      title: row.displayName,
                      subtitle:
                          mapped?.displayName ??
                          (hasSelection
                              ? 'Mapped in Xero'
                              : (required
                                  ? 'Required — tap to choose Xero employee'
                                  : 'Optional — not on current batches')),
                      status: _mapStatus(
                        hasSelection: hasSelection,
                        pending: pending,
                        required: required,
                      ),
                      enabled: controller.canManageXero,
                      onTap: () async {
                        final picked = await _showXeroPickSheet(
                          context,
                          title: row.displayName,
                          hint: 'Search Xero employees',
                          selectedId: hasSelection ? selected : null,
                          options: [
                            for (final e in employees)
                              _PickOption(
                                id: e.employeeId,
                                label: e.displayName,
                                subtitle: e.email,
                              ),
                          ],
                        );
                        if (picked.cancelled) return;
                        controller.setEmployeeMapping(
                          row.contractorId,
                          picked.id,
                        );
                      },
                    );
                  },
                ),
              ],
            ],
          ),
          if (controller.hasPendingEmployeeMappings) ...[
            const SizedBox(height: 10),
            const Text(
              'You have unsaved worker maps. Save to keep them.',
              style: TextStyle(fontSize: 12, color: AppColors.openSlot),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed:
                controller.isSavingEmployees.value
                    ? null
                    : controller.saveEmployeeMappings,
            child:
                controller.isSavingEmployees.value
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Save worker mappings'),
          ),
        ],
      );
    });
  }
}

class _PayItemsMappingPanel extends GetView<XeroSettingsController> {
  const _PayItemsMappingPanel();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rates = controller.xeroEarningsRates;

      if (rates.isEmpty) {
        return _EmptyCatalogue(
          title: 'No Xero earnings rates found',
          body:
              'Add earnings rates / pay items in Xero Payroll, then refresh.',
          onOpenXero: controller.openXeroInBrowser,
          onRefresh: controller.loadMappingData,
        );
      }

      final byId = {for (final r in rates) r.earningsRateId: r};
      final requiredUnmapped = controller.unmappedBandKeys.toSet();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Only bands used on payment batches must be mapped. '
            'Map each band to Ordinary Hours or Overtime — allowances '
            'and bonuses are rejected by Xero timesheets.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          _MappingListSurface(
            children: [
              for (var i = 0; i < XeroBandKeys.all.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.divider),
                Builder(
                  builder: (context) {
                    final band = XeroBandKeys.all[i];
                    final selected = controller.payItemSelection[band];
                    final mapped =
                        selected != null ? byId[selected] : null;
                    final pending = controller.isPayItemMappingPending(band);
                    final required = requiredUnmapped.contains(band);
                    final invalidMapped =
                        mapped != null && !mapped.isTimesheetEligible;
                    final pickRates = [
                      ...rates.where((r) => r.isTimesheetEligible),
                      // Keep a currently saved ineligible rate visible so it
                      // can be replaced (otherwise the row looks "mapped").
                      if (invalidMapped) mapped!,
                    ];
                    String subtitle;
                    if (mapped == null) {
                      subtitle =
                          required
                              ? 'Required — tap to choose Ordinary/Overtime'
                              : 'Optional — not used on current batches';
                    } else if (invalidMapped) {
                      subtitle =
                          '${mapped.name} — not valid for timesheets; retap';
                    } else {
                      subtitle = mapped.name;
                    }
                    return _MapRow(
                      title: humanizeLabel(band),
                      subtitle: subtitle,
                      status: _mapStatus(
                        hasSelection: mapped != null && !invalidMapped,
                        pending: pending || invalidMapped,
                        required: required || invalidMapped,
                      ),
                      enabled: controller.canManageXero,
                      onTap: () async {
                        final picked = await _showXeroPickSheet(
                          context,
                          title: humanizeLabel(band),
                          hint: 'Search Ordinary / Overtime rates',
                          selectedId: mapped?.earningsRateId,
                          options: [
                            for (final r in pickRates)
                              _PickOption(
                                id: r.earningsRateId,
                                label: r.name,
                                subtitle: [
                                  if (r.earningsType != null &&
                                      r.earningsType!.isNotEmpty)
                                    r.earningsType!,
                                  if (r.rateType != null &&
                                      r.rateType!.isNotEmpty)
                                    r.rateType!,
                                  if (!r.isTimesheetEligible)
                                    'not valid for timesheets',
                                ].join(' · '),
                              ),
                          ],
                        );
                        if (picked.cancelled) return;
                        controller.setPayItemMapping(band, picked.id);
                      },
                    );
                  },
                ),
              ],
            ],
          ),
          if (controller.hasPendingPayItemMappings) ...[
            const SizedBox(height: 10),
            const Text(
              'You have unsaved pay-item maps. Save to keep them.',
              style: TextStyle(fontSize: 12, color: AppColors.openSlot),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed:
                controller.isSavingPayItems.value
                    ? null
                    : controller.savePayItemMappings,
            child:
                controller.isSavingPayItems.value
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Save pay-item mappings'),
          ),
        ],
      );
    });
  }
}

enum _MapRowStatus { needsMap, optional, selected, mapped }

_MapRowStatus _mapStatus({
  required bool hasSelection,
  required bool pending,
  bool required = true,
}) {
  if (!hasSelection) {
    return required ? _MapRowStatus.needsMap : _MapRowStatus.optional;
  }
  if (pending) return _MapRowStatus.selected;
  return _MapRowStatus.mapped;
}

class _MappingListSurface extends StatelessWidget {
  const _MappingListSurface({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _MapRow extends StatelessWidget {
  const _MapRow({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final _MapRowStatus status;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitleColor = switch (status) {
      _MapRowStatus.needsMap => AppColors.openSlot,
      _MapRowStatus.optional => AppColors.slate500,
      _MapRowStatus.selected => AppColors.primary,
      _MapRowStatus.mapped => AppColors.textMuted,
    };
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: subtitleColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(status: status),
              Icon(
                Icons.chevron_right,
                color: enabled ? AppColors.slate400 : AppColors.slate300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _MapRowStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      _MapRowStatus.needsMap => (
        'Needs map',
        AppColors.openSlotBackground,
        AppColors.openSlot,
      ),
      _MapRowStatus.optional => (
        'Optional',
        AppColors.slate200,
        AppColors.slate600,
      ),
      _MapRowStatus.selected => (
        'Selected',
        AppColors.brandSoft,
        AppColors.primary,
      ),
      _MapRowStatus.mapped => (
        'Mapped',
        AppColors.successBackground,
        AppColors.success,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _PickOption {
  const _PickOption({
    required this.id,
    required this.label,
    this.subtitle,
  });

  final String id;
  final String label;
  final String? subtitle;
}

class _PickResult {
  const _PickResult._({required this.cancelled, this.id});
  const _PickResult.cancelled() : this._(cancelled: true);
  const _PickResult.clear() : this._(cancelled: false);
  const _PickResult.selected(String id) : this._(cancelled: false, id: id);

  final bool cancelled;
  final String? id;
}

Future<_PickResult> _showXeroPickSheet(
  BuildContext context, {
  required String title,
  required String hint,
  required String? selectedId,
  required List<_PickOption> options,
}) async {
  final result = await showModalBottomSheet<_PickResult>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return _XeroPickSheet(
        title: title,
        hint: hint,
        selectedId: selectedId,
        options: options,
      );
    },
  );
  return result ?? const _PickResult.cancelled();
}

class _XeroPickSheet extends StatefulWidget {
  const _XeroPickSheet({
    required this.title,
    required this.hint,
    required this.selectedId,
    required this.options,
  });

  final String title;
  final String hint;
  final String? selectedId;
  final List<_PickOption> options;

  @override
  State<_XeroPickSheet> createState() => _XeroPickSheetState();
}

class _XeroPickSheetState extends State<_XeroPickSheet> {
  late final TextEditingController _query;
  String _filter = '';
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController();
    _selectedId = widget.selectedId;
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  _PickOption? get _selectedOption {
    final id = _selectedId;
    if (id == null) return null;
    for (final o in widget.options) {
      if (o.id == id) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final q = _filter.trim().toLowerCase();
    final filtered =
        q.isEmpty
            ? widget.options
            : widget.options
                .where((o) {
                  final hay = '${o.label} ${o.subtitle ?? ''}'.toLowerCase();
                  return hay.contains(q);
                })
                .toList(growable: false);

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    final chosen = _selectedOption;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap a match, then Apply',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _query,
                      onChanged: (v) => setState(() => _filter = v),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    if (chosen != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Selected: ${chosen.label}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child:
                    filtered.isEmpty
                        ? const Center(
                          child: Text(
                            'No matches',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                        : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder:
                              (_, __) => const Divider(
                                height: 1,
                                color: AppColors.divider,
                              ),
                          itemBuilder: (context, i) {
                            final o = filtered[i];
                            final selected = o.id == _selectedId;
                            return ListTile(
                              selected: selected,
                              selectedTileColor: AppColors.brandSoft,
                              title: Text(
                                o.label,
                                style: TextStyle(
                                  fontWeight:
                                      selected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                ),
                              ),
                              subtitle:
                                  (o.subtitle != null &&
                                          o.subtitle!.trim().isNotEmpty)
                                      ? Text(o.subtitle!)
                                      : null,
                              trailing:
                                  selected
                                      ? const Icon(
                                        Icons.check_circle,
                                        color: AppColors.primary,
                                      )
                                      : const Icon(
                                        Icons.circle_outlined,
                                        color: AppColors.slate300,
                                        size: 22,
                                      ),
                              onTap: () => setState(() => _selectedId = o.id),
                            );
                          },
                        ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed:
                          _selectedId == null
                              ? null
                              : () => Navigator.of(
                                context,
                              ).pop(_PickResult.selected(_selectedId!)),
                      child: const Text('Apply'),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        TextButton(
                          onPressed:
                              () => Navigator.of(
                                context,
                              ).pop(const _PickResult.clear()),
                          child: const Text('Clear mapping'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCatalogue extends StatelessWidget {
  const _EmptyCatalogue({
    required this.title,
    required this.body,
    required this.onOpenXero,
    required this.onRefresh,
  });

  final String title;
  final String body;
  final Future<void> Function() onOpenXero;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        children: [
          Text(title, style: Get.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              TextButton(onPressed: onOpenXero, child: const Text('Open Xero')),
              TextButton(onPressed: onRefresh, child: const Text('Refresh')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectionPanel extends StatelessWidget {
  const _ConnectionPanel({required this.status});

  final XeroConnectionStatus? status;

  @override
  Widget build(BuildContext context) {
    final connected = status?.connected ?? false;
    final org = status?.orgName?.trim();
    final at = status?.connectedAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            connected
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              connected
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                connected ? Icons.check_circle_outline : Icons.link_off,
                color: connected ? AppColors.success : AppColors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                connected ? 'Connected' : 'Not connected',
                style: Get.textTheme.titleSmall,
              ),
            ],
          ),
          if (connected) ...[
            const SizedBox(height: 8),
            Text(
              (org != null && org.isNotEmpty) ? org : 'Xero organisation',
              style: const TextStyle(fontSize: 14),
            ),
            if (at != null) ...[
              const SizedBox(height: 4),
              Text(
                'Connected ${formatVisitDateTime(at)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Connect Demo Company (AU) for local tests. '
                'Payments stay unchanged until you Send to Xero.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
