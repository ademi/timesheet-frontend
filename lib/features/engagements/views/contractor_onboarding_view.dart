import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/floating_error_notice.dart';
import '../../credentials/data/models/credential_models.dart';
import '../controllers/contractor_onboarding_controller.dart';

class ContractorOnboardingView
    extends GetView<ContractorOnboardingController> {
  const ContractorOnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Obx(() {
          final i = controller.step.value;
          final label =
              i >= 0 && i < ContractorOnboardingController.stepLabels.length
                  ? ContractorOnboardingController.stepLabels[i]
                  : 'Add contractor';
          return Text(label);
        }),
      ),
      body: Obx(() {
        final err = controller.errorMessage.value;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _StepIndicator(step: controller.step.value),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PageContent(
                    width: PageContentWidth.narrow,
                    child: switch (controller.step.value) {
                      0 => _IdentityStep(controller: controller),
                      1 => _ScreeningStep(controller: controller),
                      2 => _QualificationsStep(controller: controller),
                      3 => _ChecksStep(controller: controller),
                      _ => _InviteStep(controller: controller),
                    },
                  ),
                ],
              ),
            ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: FloatingErrorNotice(
                  message: err,
                  onDismiss: () => controller.errorMessage.value = null,
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: PageContent(
                  width: PageContentWidth.narrow,
                  child: Obx(() {
                    final isLast = controller.step.value ==
                        ContractorOnboardingController.maxStep;
                    final isSaving = controller.isSaving.value;
                    final sendInvite = controller.sendInvite.value;
                    final narrow =
                        MediaQuery.sizeOf(context).width < 420;
                    final nextLabel = isLast
                        ? (sendInvite ? 'Save & invite' : 'Save')
                        : 'Next';
                    final back = controller.step.value > 0
                        ? OutlinedButton(
                            onPressed:
                                isSaving ? null : controller.previousStep,
                            child: const Text('Back'),
                          )
                        : null;
                    final next = AsyncElevatedButton(
                      onPressed: controller.nextStep,
                      isLoading: isSaving,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        minimumSize: narrow
                            ? const Size.fromHeight(48)
                            : null,
                      ),
                      child: Text(nextLabel),
                    );
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          next,
                          if (back != null) ...[
                            const SizedBox(height: 8),
                            back,
                          ],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        if (back != null) back,
                        const Spacer(),
                        next,
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ContractorOnboardingController.stepLabels;
    final narrow = MediaQuery.sizeOf(context).width < 520;
    if (narrow) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              SizedBox(
                width: 88,
                child: _stepCell(i, labels[i]),
              ),
            ],
          ],
        ),
      );
    }
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(child: _stepCell(i, labels[i])),
        ],
      ],
    );
  }

  Widget _stepCell(int i, String label) {
    return Column(
      children: [
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: i <= step ? AppColors.primary : AppColors.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: i <= step ? AppColors.textDark : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

Future<void> _pickDate(
  BuildContext context,
  Rxn<DateTime> target, {
  DateTime? first,
  DateTime? last,
}) async {
  final now = DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: target.value ?? now,
    firstDate: first ?? DateTime(now.year - 80),
    lastDate: last ?? DateTime(now.year + 20),
  );
  if (picked != null) target.value = picked;
}

String _fmt(DateTime? d) =>
    d == null ? 'Select date' : d.toIso8601String().split('T').first;

class _IdentityStep extends StatelessWidget {
  const _IdentityStep({required this.controller});
  final ContractorOnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'All fields optional except email. Document uploads happen after invite.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller.fullNameCtrl,
          decoration: const InputDecoration(labelText: 'Full name'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.emailCtrl,
          decoration: const InputDecoration(labelText: 'Email *'),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.phoneCtrl,
          decoration: const InputDecoration(labelText: 'Phone'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        Obx(
          () => ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date of birth'),
            subtitle: Text(_fmt(controller.dob.value)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () => _pickDate(
              context,
              controller.dob,
              last: DateTime.now(),
            ),
          ),
        ),
        TextField(
          controller: controller.abnCtrl,
          decoration: const InputDecoration(labelText: 'ABN'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        const Text(
          'Residential address',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller.addressLine1Ctrl,
          decoration: const InputDecoration(labelText: 'Address line 1'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.addressLine2Ctrl,
          decoration: const InputDecoration(labelText: 'Address line 2'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.suburbCtrl,
          decoration: const InputDecoration(labelText: 'Suburb'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller.stateCtrl,
                decoration: const InputDecoration(labelText: 'State'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller.postcodeCtrl,
                decoration: const InputDecoration(labelText: 'Postcode'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.countryCtrl,
          decoration: const InputDecoration(labelText: 'Country'),
        ),
      ],
    );
  }
}

class _ScreeningStep extends StatelessWidget {
  const _ScreeningStep({required this.controller});
  final ContractorOnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'NDIS Worker Screening Check (CRM fields — contractor uploads evidence later).',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller.screeningNumberCtrl,
          decoration: const InputDecoration(labelText: 'Screening check number'),
        ),
        const SizedBox(height: 12),
        Obx(
          () => DropdownButtonFormField<String>(
            value: controller.screeningStatus.value,
            decoration: const InputDecoration(labelText: 'Clearance status'),
            items: const [
              DropdownMenuItem(value: 'cleared', child: Text('Cleared')),
              DropdownMenuItem(value: 'excluded', child: Text('Excluded')),
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => controller.screeningStatus.value = v,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.screeningStateCtrl,
          decoration: const InputDecoration(labelText: 'State / territory'),
        ),
        Obx(
          () => ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Issue date'),
            subtitle: Text(_fmt(controller.screeningIssueDate.value)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () => _pickDate(context, controller.screeningIssueDate),
          ),
        ),
        Obx(
          () => ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Expiry date'),
            subtitle: Text(_fmt(controller.screeningExpiryDate.value)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () => _pickDate(context, controller.screeningExpiryDate),
          ),
        ),
      ],
    );
  }
}

class _QualificationsStep extends StatelessWidget {
  const _QualificationsStep({required this.controller});
  final ContractorOnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Optional qualifications. Evidence uploads stay on the contractor credentials flow.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < controller.qualifications.length; i++) ...[
            _QualCard(
              index: i,
              row: controller.qualifications[i],
              onRemove: () => controller.removeQualification(i),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: controller.addQualification,
            icon: const Icon(Icons.add),
            label: const Text('Add qualification'),
          ),
        ],
      );
    });
  }
}

class _QualCard extends StatelessWidget {
  const _QualCard({
    required this.index,
    required this.row,
    required this.onRemove,
  });

  final int index;
  final ContractorQualRow row;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Qualification ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Obx(
            () => DropdownButtonFormField<String>(
              value: row.type.value,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final code
                    in ContractorOnboardingController.qualTypeOptions)
                  DropdownMenuItem(
                    value: code,
                    child: Text(credentialTypeLabel(code)),
                  ),
              ],
              onChanged: (v) => row.type.value = v,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: row.nameCtrl,
            decoration: const InputDecoration(labelText: 'Name / details'),
          ),
          Obx(
            () => ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Issue date'),
              subtitle: Text(_fmt(row.issueDate.value)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => _pickDate(context, row.issueDate),
            ),
          ),
          Obx(
            () => ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Expiry date'),
              subtitle: Text(_fmt(row.expiryDate.value)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => _pickDate(context, row.expiryDate),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecksStep extends StatelessWidget {
  const _ChecksStep({required this.controller});
  final ContractorOnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'WWCC, police check, licence, and vehicle (CRM only).',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        const Text('Working with Children Check',
            style: TextStyle(fontWeight: FontWeight.w600)),
        TextField(
          controller: controller.wwccNumberCtrl,
          decoration: const InputDecoration(labelText: 'WWCC number'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller.wwccStateCtrl,
          decoration: const InputDecoration(labelText: 'State'),
        ),
        Obx(
          () => ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('WWCC expiry'),
            subtitle: Text(_fmt(controller.wwccExpiry.value)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () => _pickDate(context, controller.wwccExpiry),
          ),
        ),
        const SizedBox(height: 8),
        const Text('National police check',
            style: TextStyle(fontWeight: FontWeight.w600)),
        Obx(
          () => ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Issue date'),
            subtitle: Text(_fmt(controller.policeIssueDate.value)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () => _pickDate(context, controller.policeIssueDate),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Driver licence',
            style: TextStyle(fontWeight: FontWeight.w600)),
        TextField(
          controller: controller.licenceNumberCtrl,
          decoration: const InputDecoration(labelText: 'Licence number'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller.licenceStateCtrl,
          decoration: const InputDecoration(labelText: 'State'),
        ),
        Obx(
          () => ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Licence expiry'),
            subtitle: Text(_fmt(controller.licenceExpiry.value)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () => _pickDate(context, controller.licenceExpiry),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Vehicle registration',
            style: TextStyle(fontWeight: FontWeight.w600)),
        TextField(
          controller: controller.vehiclePlateCtrl,
          decoration: const InputDecoration(labelText: 'Plate'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller.vehicleStateCtrl,
          decoration: const InputDecoration(labelText: 'State'),
        ),
        Obx(
          () => ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Rego expiry'),
            subtitle: Text(_fmt(controller.vehicleExpiry.value)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () => _pickDate(context, controller.vehicleExpiry),
          ),
        ),
      ],
    );
  }
}

class _InviteStep extends StatelessWidget {
  const _InviteStep({required this.controller});
  final ContractorOnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choose required document categories and whether to email the invite now.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Obx(
          () => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Send invite email'),
            value: controller.sendInvite.value,
            onChanged: (v) => controller.sendInvite.value = v,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Required documents',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Obx(() {
          final selected = controller.selectedCategories;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cat in controller.categoryChoices)
                FilterChip(
                  label: Text(cat.label),
                  selected: selected.contains(cat.code),
                  onSelected: (on) {
                    if (on) {
                      selected.add(cat.code);
                    } else {
                      selected.remove(cat.code);
                    }
                  },
                ),
            ],
          );
        }),
      ],
    );
  }
}
