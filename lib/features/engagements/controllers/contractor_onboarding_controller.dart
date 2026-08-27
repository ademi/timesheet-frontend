import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/utils/name_sort.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../credentials/data/models/credential_models.dart';
import '../../credentials/data/repositories/credentials_repository.dart';
import '../data/models/staff_contractor_models.dart';
import '../data/repositories/engagements_repository.dart';
import 'workforce_controller.dart';

/// Staff "Add contractor" horizontal stepper (Identity → … → Invite).
class ContractorOnboardingController extends GetxController {
  ContractorOnboardingController({
    required EngagementsRepository repository,
    required CredentialsRepository credentialsRepository,
    required SessionService session,
  })  : _repository = repository,
        _credentialsRepository = credentialsRepository,
        _session = session;

  final EngagementsRepository _repository;
  final CredentialsRepository _credentialsRepository;
  final SessionService _session;

  static const maxStep = 4;
  static const stepLabels = [
    'Identity',
    'Screening',
    'Qualifications',
    'Checks',
    'Invite',
  ];

  final step = 0.obs;
  final errorMessage = RxnString();
  final isSaving = false.obs;
  final sendInvite = true.obs;
  final selectedCategories = <String>{'ndis_worker_screening'}.obs;
  final catalogCategories = <CredentialCategory>[].obs;

  // Identity
  final fullNameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final abnCtrl = TextEditingController();
  final addressLine1Ctrl = TextEditingController();
  final addressLine2Ctrl = TextEditingController();
  final suburbCtrl = TextEditingController();
  final stateCtrl = TextEditingController(text: 'NSW');
  final postcodeCtrl = TextEditingController();
  final countryCtrl = TextEditingController(text: 'AU');
  final dob = Rxn<DateTime>();

  // Screening (CRM)
  final screeningNumberCtrl = TextEditingController();
  final screeningStatus = RxnString();
  final screeningStateCtrl = TextEditingController();
  final screeningIssueDate = Rxn<DateTime>();
  final screeningExpiryDate = Rxn<DateTime>();

  // Qualifications CRM rows
  final qualifications = <ContractorQualRow>[].obs;

  // Checks
  final wwccNumberCtrl = TextEditingController();
  final wwccStateCtrl = TextEditingController();
  final wwccExpiry = Rxn<DateTime>();
  final policeIssueDate = Rxn<DateTime>();
  final licenceNumberCtrl = TextEditingController();
  final licenceStateCtrl = TextEditingController();
  final licenceExpiry = Rxn<DateTime>();
  final vehiclePlateCtrl = TextEditingController();
  final vehicleStateCtrl = TextEditingController();
  final vehicleExpiry = Rxn<DateTime>();

  List<CredentialCategory> get categoryChoices {
    final choices = catalogCategories.isNotEmpty
        ? catalogCategories.toList()
        : credentialTypesAllowlist
            .map(
              (code) => CredentialCategory(
                code: code,
                label: credentialTypeLabel(code),
              ),
            )
            .toList();
    return sortedByName(choices, (c) => c.label);
  }

  static const qualTypeOptions = <String>[
    'cert_iii',
    'nursing_bachelor',
    'nursing_diploma',
    'other_health_qualification',
    'first_aid',
    'cpr',
    'medication_admin',
    'epilepsy_management',
    'manual_handling',
    'trade_certificate',
  ];

  @override
  void onInit() {
    super.onInit();
    qualifications.add(ContractorQualRow());
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final list = await _credentialsRepository.listCredentialCategories();
      catalogCategories.assignAll(list);
    } catch (_) {
      // Fallback allowlist via [categoryChoices].
    }
  }

  void previousStep() {
    if (step.value > 0) step.value--;
  }

  Future<void> nextStep() async {
    errorMessage.value = null;
    if (step.value == 0) {
      final email = emailCtrl.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        errorMessage.value = 'A valid email is required.';
        return;
      }
    }
    if (step.value == maxStep && selectedCategories.isEmpty) {
      errorMessage.value = 'Select at least one required document.';
      return;
    }
    if (step.value < maxStep) {
      step.value++;
      return;
    }
    await submit();
  }

  void addQualification() => qualifications.add(ContractorQualRow());

  void removeQualification(int index) {
    if (qualifications.length <= 1) return;
    qualifications[index].dispose();
    qualifications.removeAt(index);
  }

  Map<String, dynamic> _compliancePayload() {
    final screening = <String, dynamic>{
      if (screeningNumberCtrl.text.trim().isNotEmpty)
        'number': screeningNumberCtrl.text.trim(),
      if (screeningStatus.value != null) 'status': screeningStatus.value,
      if (screeningStateCtrl.text.trim().isNotEmpty)
        'state': screeningStateCtrl.text.trim(),
      if (screeningIssueDate.value != null)
        'issue_date':
            screeningIssueDate.value!.toIso8601String().split('T').first,
      if (screeningExpiryDate.value != null)
        'expiry_date':
            screeningExpiryDate.value!.toIso8601String().split('T').first,
    };
    final quals = <Map<String, dynamic>>[];
    for (final row in qualifications) {
      final type = row.type.value;
      if (type == null || type.isEmpty) continue;
      quals.add({
        'type': type,
        if (row.nameCtrl.text.trim().isNotEmpty)
          'name': row.nameCtrl.text.trim(),
        if (row.issueDate.value != null)
          'issue_date': row.issueDate.value!.toIso8601String().split('T').first,
        if (row.expiryDate.value != null)
          'expiry_date':
              row.expiryDate.value!.toIso8601String().split('T').first,
      });
    }
    final checks = <String, dynamic>{
      if (wwccNumberCtrl.text.trim().isNotEmpty ||
          wwccStateCtrl.text.trim().isNotEmpty ||
          wwccExpiry.value != null)
        'wwcc': {
          if (wwccNumberCtrl.text.trim().isNotEmpty)
            'number': wwccNumberCtrl.text.trim(),
          if (wwccStateCtrl.text.trim().isNotEmpty)
            'state': wwccStateCtrl.text.trim(),
          if (wwccExpiry.value != null)
            'expiry_date':
                wwccExpiry.value!.toIso8601String().split('T').first,
        },
      if (policeIssueDate.value != null)
        'police_check': {
          'issue_date':
              policeIssueDate.value!.toIso8601String().split('T').first,
        },
      if (licenceNumberCtrl.text.trim().isNotEmpty ||
          licenceStateCtrl.text.trim().isNotEmpty ||
          licenceExpiry.value != null)
        'drivers_licence': {
          if (licenceNumberCtrl.text.trim().isNotEmpty)
            'number': licenceNumberCtrl.text.trim(),
          if (licenceStateCtrl.text.trim().isNotEmpty)
            'state': licenceStateCtrl.text.trim(),
          if (licenceExpiry.value != null)
            'expiry_date':
                licenceExpiry.value!.toIso8601String().split('T').first,
        },
      if (vehiclePlateCtrl.text.trim().isNotEmpty ||
          vehicleStateCtrl.text.trim().isNotEmpty ||
          vehicleExpiry.value != null)
        'vehicle_registration': {
          if (vehiclePlateCtrl.text.trim().isNotEmpty)
            'plate': vehiclePlateCtrl.text.trim(),
          if (vehicleStateCtrl.text.trim().isNotEmpty)
            'state': vehicleStateCtrl.text.trim(),
          if (vehicleExpiry.value != null)
            'expiry_date':
                vehicleExpiry.value!.toIso8601String().split('T').first,
        },
    };
    return {
      if (screening.isNotEmpty) 'screening': screening,
      if (quals.isNotEmpty) 'qualifications': quals,
      if (checks.isNotEmpty) 'checks': checks,
    };
  }

  Future<void> submit() async {
    if (!_session.hasPermission(AppPermissions.contractorsManage)) {
      errorMessage.value = 'Missing contractors.manage permission.';
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final result = await _repository.createStaffContractor(
        StaffContractorCreateRequest(
          email: emailCtrl.text.trim(),
          fullName: fullNameCtrl.text.trim().isEmpty
              ? null
              : fullNameCtrl.text.trim(),
          phone:
              phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
          dob: dob.value,
          abn: abnCtrl.text.trim().isEmpty ? null : abnCtrl.text.trim(),
          address: ContractorAddress(
            addressLine1: addressLine1Ctrl.text,
            addressLine2: addressLine2Ctrl.text,
            suburb: suburbCtrl.text,
            state: stateCtrl.text,
            postcode: postcodeCtrl.text,
            country: countryCtrl.text,
          ),
          compliance: _compliancePayload(),
          requiredCategories: selectedCategories.toList(),
          sendInvite: sendInvite.value,
        ),
      );

      if (Get.isRegistered<WorkforceController>()) {
        await Get.find<WorkforceController>().load();
      }

      final invite = result.registrationInvite;
      final inviteUrl = invite?.inviteUrl?.trim();
      if (result.isRegistrationInvite &&
          inviteUrl != null &&
          inviteUrl.isNotEmpty &&
          Get.isRegistered<WorkforceController>()) {
        await Get.find<WorkforceController>().showInviteLinkDialog(
          inviteUrl: inviteUrl,
          expiresAt: invite!.expiresAt,
        );
      } else {
        AppToast.success(
          'Contractor saved',
          result.isRegistrationInvite
              ? 'Invite sent to ${emailCtrl.text.trim()}.'
              : 'Engagement created.',
        );
      }
      Get.offNamed(AppRoutes.staffWorkforce);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    fullNameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    abnCtrl.dispose();
    addressLine1Ctrl.dispose();
    addressLine2Ctrl.dispose();
    suburbCtrl.dispose();
    stateCtrl.dispose();
    postcodeCtrl.dispose();
    countryCtrl.dispose();
    screeningNumberCtrl.dispose();
    screeningStateCtrl.dispose();
    wwccNumberCtrl.dispose();
    wwccStateCtrl.dispose();
    licenceNumberCtrl.dispose();
    licenceStateCtrl.dispose();
    vehiclePlateCtrl.dispose();
    vehicleStateCtrl.dispose();
    for (final q in qualifications) {
      q.dispose();
    }
    super.onClose();
  }
}

class ContractorQualRow {
  ContractorQualRow();

  final type = RxnString();
  final nameCtrl = TextEditingController();
  final issueDate = Rxn<DateTime>();
  final expiryDate = Rxn<DateTime>();

  void dispose() {
    nameCtrl.dispose();
  }
}
