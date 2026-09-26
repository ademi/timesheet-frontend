import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../controllers/sil_houses_controller.dart';
import '../data/models/sil_models.dart';

class SilHousesListView extends GetView<SilHousesController> {
  const SilHousesListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('SIL houses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _promptCreate(context),
        icon: const Icon(Icons.add),
        label: const Text('Add house'),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.houses.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final err = controller.errorMessage.value;
        if (err != null && controller.houses.isEmpty) {
          return Center(child: Text(err));
        }
        if (controller.houses.isEmpty) {
          return const Center(
            child: Text('No SIL houses yet. Add one to fund ROC ratios.'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.houses.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final h = controller.houses[i];
            return ListTile(
              tileColor: AppColors.surface,
              title: Text(h.name),
              subtitle: Text(
                [
                  if (h.city != null && h.city!.isNotEmpty) h.city,
                  if (!(h.isActive)) 'inactive',
                ].whereType<String>().join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => Get.toNamed(
                    AppRoutes.staffSilHouseDetail,
                    arguments: {'house_id': h.id},
                  ),
            );
          },
        );
      }),
    );
  }

  Future<void> _promptCreate(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('New SIL house'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'House name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final created = await controller.createHouse(nameCtrl.text);
    if (created != null) {
      Get.toNamed(
        AppRoutes.staffSilHouseDetail,
        arguments: {'house_id': created.id},
      );
    }
  }
}

class SilHouseDetailView extends GetView<SilHouseDetailController> {
  const SilHouseDetailView({super.key});

  static const _bands = ['day', 'evening', 'overnight'];

  static SilRocBlockOut? _blockFor(List<SilRocBlockOut> blocks, String band) {
    for (final r in blocks) {
      if (r.band == band) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Obx(
          () => Text(controller.bundle.value?.house.name ?? 'SIL house'),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.bundle.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final b = controller.bundle.value;
        if (b == null) {
          return Center(
            child: Text(controller.errorMessage.value ?? 'House not found'),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              width: PageContentWidth.narrow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Present occupancy: ${b.presentOccupancy} / ${b.members.length}'
                    '${b.house.bedCapacity != null ? ' (beds ${b.house.bedCapacity})' : ''}',
                    style: Get.textTheme.titleMedium,
                  ),
                  if (controller.overlay.value != null) ...[
                    const SizedBox(height: 8),
                    _VacancyStrip(overlay: controller.overlay.value!),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed:
                          controller.isSaving.value
                              ? null
                              : () => controller.draftFillShift(),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Draft fill shift'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _CapacityCostEditor(
                    bedCapacity: b.house.bedCapacity,
                    fixedWeeklyCost: b.house.fixedWeeklyCost,
                    enabled: !controller.isSaving.value,
                    onSave: ({bedCapacity, fixedWeeklyCost}) =>
                        controller.saveCapacityCost(
                          bedCapacity: bedCapacity,
                          fixedWeeklyCost: fixedWeeklyCost,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Funded roster of care (by local time-of-day)',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  for (final band in _bands) ...[
                    _RocBandEditor(
                      band: band,
                      existing: _blockFor(b.rocBlocks, band),
                      enabled: !controller.isSaving.value,
                      onSave: (workers, participants) => controller.saveRocBlock(
                        band: band,
                        workers: workers,
                        participants: participants,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text('Members', style: Get.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (b.members.isEmpty)
                    const Text(
                      'No members yet. Link clients from the API or a later picker.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  for (final m in b.members)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(m.clientName ?? m.clientId),
                      subtitle: Text(
                        m.isPresent ? 'Present' : m.occupancyStatus,
                      ),
                      trailing: DropdownButton<String>(
                        value: m.occupancyStatus,
                        items: const [
                          DropdownMenuItem(
                            value: 'present',
                            child: Text('Present'),
                          ),
                          DropdownMenuItem(
                            value: 'vacant',
                            child: Text('Vacant'),
                          ),
                          DropdownMenuItem(
                            value: 'hospital',
                            child: Text('Hospital'),
                          ),
                          DropdownMenuItem(
                            value: 'other_absent',
                            child: Text('Other absent'),
                          ),
                        ],
                        onChanged:
                            controller.isSaving.value
                                ? null
                                : (v) {
                                  if (v == null) return;
                                  controller.setOccupancy(
                                    clientId: m.clientId,
                                    status: v,
                                  );
                                },
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Compatibility rules',
                          style: Get.textTheme.titleMedium,
                        ),
                      ),
                      TextButton.icon(
                        onPressed:
                            controller.isSaving.value
                                ? null
                                : () => _promptCompatRule(context, b.members),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Soft warn or hard-block assign when a housemate is present.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  if (controller.compatRules.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'No compatibility rules yet.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  for (final rule in controller.compatRules)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(rule.reason),
                      subtitle: Text(
                        '${rule.isHard ? 'Hard block' : 'Soft warn'}'
                        '${rule.againstClientId != null ? ' · client ${rule.againstClientId!.substring(0, 8)}…' : ''}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed:
                            controller.isSaving.value
                                ? null
                                : () => controller.removeCompatRule(rule.id),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _promptCompatRule(
    BuildContext context,
    List<SilHouseMemberOut> members,
  ) async {
    final reasonCtrl = TextEditingController();
    var severity = 'soft_warn';
    String? againstClientId = members.isNotEmpty ? members.first.clientId : null;
    final ok = await Get.dialog<bool>(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add compatibility rule'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: reasonCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: severity,
                    decoration: const InputDecoration(
                      labelText: 'Severity',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'soft_warn',
                        child: Text('Soft warn'),
                      ),
                      DropdownMenuItem(
                        value: 'hard_block',
                        child: Text('Hard block'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => severity = v);
                    },
                  ),
                  if (members.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: againstClientId,
                      decoration: const InputDecoration(
                        labelText: 'Against housemate',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final m in members)
                          DropdownMenuItem(
                            value: m.clientId,
                            child: Text(m.clientName ?? m.clientId),
                          ),
                      ],
                      onChanged: (v) => setState(() => againstClientId = v),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    await controller.addCompatRule(
      reason: reasonCtrl.text,
      severity: severity,
      againstClientId: againstClientId,
    );
  }
}

class _RocBandEditor extends StatefulWidget {
  const _RocBandEditor({
    required this.band,
    required this.existing,
    required this.enabled,
    required this.onSave,
  });

  final String band;
  final SilRocBlockOut? existing;
  final bool enabled;
  final Future<void> Function(int workers, int participants) onSave;

  @override
  State<_RocBandEditor> createState() => _RocBandEditorState();
}

class _RocBandEditorState extends State<_RocBandEditor> {
  late final TextEditingController _workers;
  late final TextEditingController _participants;

  @override
  void initState() {
    super.initState();
    _workers = TextEditingController(
      text: '${widget.existing?.fundedWorkerCount ?? 1}',
    );
    _participants = TextEditingController(
      text: '${widget.existing?.fundedParticipantCount ?? 1}',
    );
  }

  @override
  void didUpdateWidget(covariant _RocBandEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.existing?.id != widget.existing?.id) {
      _workers.text = '${widget.existing?.fundedWorkerCount ?? 1}';
      _participants.text = '${widget.existing?.fundedParticipantCount ?? 1}';
    }
  }

  @override
  void dispose() {
    _workers.dispose();
    _participants.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.band,
          border: const OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _workers,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Workers',
                  border: InputBorder.none,
                ),
              ),
            ),
            const Text(':'),
            Expanded(
              child: TextField(
                controller: _participants,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Participants',
                  border: InputBorder.none,
                ),
              ),
            ),
            TextButton(
              onPressed:
                  widget.enabled
                      ? () async {
                        final w = int.tryParse(_workers.text) ?? 1;
                        final p = int.tryParse(_participants.text) ?? 1;
                        await widget.onSave(w, p);
                      }
                      : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VacancyStrip extends StatelessWidget {
  const _VacancyStrip({required this.overlay});
  final SilVacancyOverlayOut overlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vacancy overlay · ${overlay.presentOccupancy}'
            '${overlay.bedCapacity != null ? '/${overlay.bedCapacity}' : ''} present'
            '${overlay.fixedWeeklyCost != null ? ' · \$${overlay.fixedWeeklyCost!.toStringAsFixed(0)}/wk' : ''}'
            '${overlay.costPerPresentBed != null ? ' · \$${overlay.costPerPresentBed!.toStringAsFixed(0)}/present bed' : ''}',
            style: const TextStyle(fontSize: 13),
          ),
          if (overlay.warningCodes.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final code in overlay.warningCodes)
              Text(
                '• ${silWarningLabel(code)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CapacityCostEditor extends StatefulWidget {
  const _CapacityCostEditor({
    required this.bedCapacity,
    required this.fixedWeeklyCost,
    required this.enabled,
    required this.onSave,
  });

  final int? bedCapacity;
  final double? fixedWeeklyCost;
  final bool enabled;
  final Future<void> Function({int? bedCapacity, double? fixedWeeklyCost})
  onSave;

  @override
  State<_CapacityCostEditor> createState() => _CapacityCostEditorState();
}

class _CapacityCostEditorState extends State<_CapacityCostEditor> {
  late final TextEditingController _beds;
  late final TextEditingController _cost;

  @override
  void initState() {
    super.initState();
    _beds = TextEditingController(
      text: widget.bedCapacity?.toString() ?? '',
    );
    _cost = TextEditingController(
      text: widget.fixedWeeklyCost?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _beds.dispose();
    _cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _beds,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Bed capacity',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _cost,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Fixed \$/week',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed:
              widget.enabled
                  ? () => widget.onSave(
                    bedCapacity: int.tryParse(_beds.text.trim()),
                    fixedWeeklyCost: double.tryParse(_cost.text.trim()),
                  )
                  : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
