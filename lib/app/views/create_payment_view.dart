import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/create_payment_controller.dart';
import '../themes/app_colors.dart';

class CreatePaymentView extends GetView<CreatePaymentController> {
  const CreatePaymentView({super.key});

  static const _paymentMethods = [
    'cash',
    'bank_transfer',
    'mobile_money',
    'check',
    'other',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Payment'),
        backgroundColor: AppColors.darkBrown,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Employee'),
                    const SizedBox(height: 8),
                    Obx(
                      () => InkWell(
                        onTap: () => _openEmployeePicker(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            hintText: 'Select employee',
                            prefixIcon: Icon(Icons.person_search_rounded),
                          ),
                          child: Text(
                            controller.selectedEmployee.value == null
                                ? 'Select employee'
                                : '${controller.selectedEmployee.value!.fullName} (${controller.selectedEmployee.value!.employeeCode})',
                            style: TextStyle(
                              color: controller.selectedEmployee.value == null
                                  ? Colors.grey.shade600
                                  : AppColors.textDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _Label('Payment Date'),
                    const SizedBox(height: 8),
                    Obx(
                      () => InkWell(
                        onTap: () => controller.setPaymentDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.calendar_today_rounded),
                          ),
                          child: Text(controller.formatDate(controller.paymentDate.value)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _Label('Amount Paid'),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('create_payment_amount_field'),
                      controller: controller.amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: controller.validateAmount,
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _Label('Currency Code'),
                    const SizedBox(height: 8),
                    Obx(
                      () => DropdownButtonFormField<String>(
                        value: controller.selectedCurrencyCode.value,
                        items: const [
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                          DropdownMenuItem(value: 'AUD', child: Text('AUD')),
                        ],
                        onChanged: (value) {
                          if (value != null) controller.selectedCurrencyCode.value = value;
                        },
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.currency_exchange)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _Label('Payment Method'),
                    const SizedBox(height: 8),
                    Obx(
                      () => DropdownButtonFormField<String>(
                        value: controller.selectedPaymentMethod.value,
                        items: _paymentMethods
                            .map(
                              (method) => DropdownMenuItem(
                                value: method,
                                child: Text(method),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => controller.selectedPaymentMethod.value = value,
                        decoration: const InputDecoration(
                          hintText: 'Select method',
                          prefixIcon: Icon(Icons.payments_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _Label('Reference No (Optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: controller.referenceNoController,
                      decoration: const InputDecoration(
                        hintText: 'TRX-001',
                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _Label('Payroll Result ID (Optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: controller.payrollResultIdController,
                      decoration: const InputDecoration(
                        hintText: 'uuid',
                        prefixIcon: Icon(Icons.fingerprint),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _Label('Notes (Optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: controller.notesController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Any notes for this payment...',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const Key('create_payment_submit_button'),
                    onPressed: controller.isLoading.value ? null : controller.submitPayment,
                    icon: controller.isLoading.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(controller.isLoading.value ? 'Submitting...' : 'Submit Payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEmployeePicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller.employeeSearchController,
                  onChanged: controller.filterEmployees,
                  decoration: const InputDecoration(
                    hintText: 'Search employee by name or code',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 320,
                  child: Obx(() {
                    if (controller.isLoadingEmployees.value) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (controller.filteredEmployees.isEmpty) {
                      return const Center(child: Text('No employees found'));
                    }
                    return ListView.separated(
                      itemBuilder: (context, index) {
                        final employee = controller.filteredEmployees[index];
                        return ListTile(
                          title: Text(employee.fullName),
                          subtitle: Text(employee.employeeCode),
                          onTap: () {
                            controller.selectEmployee(employee);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                      separatorBuilder: (_, _) => const Divider(height: 0),
                      itemCount: controller.filteredEmployees.length,
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryDark,
      ),
    );
  }
}
