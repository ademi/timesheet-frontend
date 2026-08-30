import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/data/models/document/document_models.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../features/clients/data/models/client_models.dart' as client_models;
import '../../../features/clients/utils/site_geocode_apply.dart';
import '../../../features/contractor_register/data/models/contractor_register_models.dart';
import '../../../features/contractor_register/models/contractor_qual_row.dart';
import '../../../shared/models/profile_photo_models.dart';
import '../../../shared/utils/abn_utils.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../documents/data/document_pipeline.dart';
import '../../contractor_me/data/models/contractor_me_models.dart';
import '../../contractor_me/data/repositories/contractor_me_repository.dart';
import '../../subscription/billing_gate.dart';
import '../data/models/compliance_ops_models.dart';
import '../data/repositories/compliance_ops_repository.dart';

class ContractorProfileController extends GetxController {
  ContractorProfileController({
    required ComplianceOpsRepository repository,
    required SessionService session,
    DocumentPipeline? documentPipeline,
    ContractorMeRepository? meRepository,
  })  : _repository = repository,
        _session = session,
        _pipeline = documentPipeline,
        _meRepository = meRepository;

  final ComplianceOpsRepository _repository;
  final SessionService _session;
  final DocumentPipeline? _pipeline;
  final ContractorMeRepository? _meRepository;

  static const auStates = [
    'NSW',
    'VIC',
    'QLD',
    'WA',
    'SA',
    'TAS',
    'ACT',
    'NT',
  ];

  static const qualTypeOptions = <String>[
    'cert_iii',
    'first_aid',
    'cpr',
    'medication_admin',
    'epilepsy_management',
    'manual_handling',
    'nursing_bachelor',
    'other_health_qualification',
  ];

  final isSaving = false.obs;
  final isLoading = false.obs;
  final isPhotoLoading = false.obs;
  final isGeocoding = false.obs;
  final errorMessage = RxnString();
  final lastRights = Rxn<RightsRequestOut>();
  final lastExport = Rxn<PrivacyExportResult>();
  final events = <NotificationEventOut>[].obs;
  final profile = Rxn<ContractorMeOut>();

  final photo = Rxn<ProfilePhotoOut>();
  final localPhotoBytes = Rxn<List<int>>();

  final rightsNotesCtrl = TextEditingController();
  final rightsType = 'access'.obs;
  final withdrawTypeCtrl = TextEditingController(text: 'police_check');
  final profileFormKey = GlobalKey<FormState>();

  final fullNameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final dobCtrl = TextEditingController();
  final abnCtrl = TextEditingController();
  final accountNameCtrl = TextEditingController();
  final bsbCtrl = TextEditingController();
  final accountNumberCtrl = TextEditingController();

  final addressLine1Ctrl = TextEditingController();
  final addressLine2Ctrl = TextEditingController();
  final suburbCtrl = TextEditingController();
  final stateCtrl = TextEditingController();
  final postcodeCtrl = TextEditingController();
  final countryCtrl = TextEditingController(text: 'AU');
  final latCtrl = TextEditingController();
  final lngCtrl = TextEditingController();

  final screeningNumberCtrl = TextEditingController();
  final screeningIssueCtrl = TextEditingController();
  final screeningExpiryCtrl = TextEditingController();
  final screeningStateCtrl = TextEditingController();
  final screeningStatus = RxnString();

  final wwccNumberCtrl = TextEditingController();
  final wwccStateCtrl = TextEditingController();
  final wwccExpiryCtrl = TextEditingController();
  final policeIssueCtrl = TextEditingController();
  final licenceNumberCtrl = TextEditingController();
  final licenceStateCtrl = TextEditingController();
  final licenceExpiryCtrl = TextEditingController();
  final vehiclePlateCtrl = TextEditingController();
  final vehicleStateCtrl = TextEditingController();
  final vehicleExpiryCtrl = TextEditingController();

  final qualifications = <ContractorQualRow>[].obs;
  final geocodeFormattedAddress = RxnString();
  final addressConfirmed = false.obs;

  bool get canConsent =>
      _session.hasPermission(AppPermissions.complianceConsentManage);

  bool get canUploadPhoto =>
      _session.hasPermission(AppPermissions.documentsUpload) &&
      _pipeline != null &&
      (_session.contractorId.value?.isNotEmpty ?? false);

  bool get canEditProfile => _meRepository != null;

  bool get needsAbnBanner => _session.needsProfileCompletion.value;

  @override
  void onInit() {
    super.onInit();
    qualifications.add(ContractorQualRow());
    stateCtrl.text = auStates.first;
    _loadEvents();
    loadProfilePhoto();
    loadProfile();
  }

  @override
  void onClose() {
    rightsNotesCtrl.dispose();
    withdrawTypeCtrl.dispose();
    fullNameCtrl.dispose();
    phoneCtrl.dispose();
    dobCtrl.dispose();
    abnCtrl.dispose();
    accountNameCtrl.dispose();
    bsbCtrl.dispose();
    accountNumberCtrl.dispose();
    addressLine1Ctrl.dispose();
    addressLine2Ctrl.dispose();
    suburbCtrl.dispose();
    stateCtrl.dispose();
    postcodeCtrl.dispose();
    countryCtrl.dispose();
    latCtrl.dispose();
    lngCtrl.dispose();
    screeningNumberCtrl.dispose();
    screeningIssueCtrl.dispose();
    screeningExpiryCtrl.dispose();
    screeningStateCtrl.dispose();
    wwccNumberCtrl.dispose();
    wwccStateCtrl.dispose();
    wwccExpiryCtrl.dispose();
    policeIssueCtrl.dispose();
    licenceNumberCtrl.dispose();
    licenceStateCtrl.dispose();
    licenceExpiryCtrl.dispose();
    vehiclePlateCtrl.dispose();
    vehicleStateCtrl.dispose();
    vehicleExpiryCtrl.dispose();
    for (final q in qualifications) {
      q.dispose();
    }
    super.onClose();
  }

  Future<void> loadProfile() async {
    final meRepo = _meRepository;
    if (meRepo == null) return;
    isLoading.value = true;
    try {
      final me = await meRepo.getMe();
      profile.value = me;
      _bindFromProfile(me);
      _session.needsProfileCompletion.value = !me.isProfileComplete;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  void _bindFromProfile(ContractorMeOut me) {
    fullNameCtrl.text = me.fullName;
    phoneCtrl.text = me.phone ?? '';
    dobCtrl.text = me.dob ?? '';
    abnCtrl.text = me.abn ?? '';
    addressLine1Ctrl.text = me.addressLine1 ?? '';
    addressLine2Ctrl.text = me.addressLine2 ?? '';
    suburbCtrl.text = me.suburb ?? '';
    stateCtrl.text = me.state ?? auStates.first;
    postcodeCtrl.text = me.postcode ?? '';
    countryCtrl.text = me.country ?? 'AU';

    final location = me.metadata['location'];
    if (location is Map) {
      final lat = location['latitude'];
      final lng = location['longitude'];
      if (lat != null) latCtrl.text = lat.toString();
      if (lng != null) lngCtrl.text = lng.toString();
      if (lat != null && lng != null) {
        addressConfirmed.value = true;
      }
    } else {
      latCtrl.clear();
      lngCtrl.clear();
      addressConfirmed.value = false;
    }
    geocodeFormattedAddress.value = null;

    final payment = me.paymentDetails;
    if (payment != null) {
      accountNameCtrl.text = payment.accountName;
      bsbCtrl.text = payment.bsb;
    } else {
      accountNameCtrl.clear();
      bsbCtrl.clear();
    }
    accountNumberCtrl.clear();

    final screening = me.compliance['screening'];
    if (screening is Map) {
      screeningNumberCtrl.text = screening['number']?.toString() ?? '';
      screeningStatus.value = screening['status']?.toString();
      screeningIssueCtrl.text = screening['issue_date']?.toString() ?? '';
      screeningExpiryCtrl.text = screening['expiry_date']?.toString() ?? '';
      screeningStateCtrl.text = screening['state']?.toString() ?? '';
    } else {
      screeningNumberCtrl.clear();
      screeningStatus.value = null;
      screeningIssueCtrl.clear();
      screeningExpiryCtrl.clear();
      screeningStateCtrl.clear();
    }

    for (final q in qualifications) {
      q.dispose();
    }
    qualifications.clear();
    final quals = me.compliance['qualifications'];
    if (quals is List && quals.isNotEmpty) {
      for (final item in quals) {
        if (item is! Map) continue;
        final row = ContractorQualRow(
          type: item['type']?.toString() ?? qualTypeOptions.first,
        );
        row.issueDateCtrl.text = item['issue_date']?.toString() ?? '';
        row.expiryDateCtrl.text = item['expiry_date']?.toString() ?? '';
        qualifications.add(row);
      }
    } else {
      qualifications.add(ContractorQualRow());
    }

    final checks = me.compliance['checks'];
    if (checks is Map) {
      final wwcc = checks['wwcc'];
      if (wwcc is Map) {
        wwccNumberCtrl.text = wwcc['number']?.toString() ?? '';
        wwccStateCtrl.text = wwcc['state']?.toString() ?? '';
        wwccExpiryCtrl.text = wwcc['expiry_date']?.toString() ?? '';
      } else {
        wwccNumberCtrl.clear();
        wwccStateCtrl.clear();
        wwccExpiryCtrl.clear();
      }
      final police = checks['police_check'];
      policeIssueCtrl.text =
          police is Map ? police['issue_date']?.toString() ?? '' : '';
      final licence = checks['drivers_licence'];
      if (licence is Map) {
        licenceNumberCtrl.text = licence['number']?.toString() ?? '';
        licenceStateCtrl.text = licence['state']?.toString() ?? '';
        licenceExpiryCtrl.text = licence['expiry_date']?.toString() ?? '';
      } else {
        licenceNumberCtrl.clear();
        licenceStateCtrl.clear();
        licenceExpiryCtrl.clear();
      }
      final vehicle = checks['vehicle_registration'];
      if (vehicle is Map) {
        vehiclePlateCtrl.text = vehicle['plate']?.toString() ?? '';
        vehicleStateCtrl.text = vehicle['state']?.toString() ?? '';
        vehicleExpiryCtrl.text = vehicle['expiry_date']?.toString() ?? '';
      } else {
        vehiclePlateCtrl.clear();
        vehicleStateCtrl.clear();
        vehicleExpiryCtrl.clear();
      }
    } else {
      wwccNumberCtrl.clear();
      wwccStateCtrl.clear();
      wwccExpiryCtrl.clear();
      policeIssueCtrl.clear();
      licenceNumberCtrl.clear();
      licenceStateCtrl.clear();
      licenceExpiryCtrl.clear();
      vehiclePlateCtrl.clear();
      vehicleStateCtrl.clear();
      vehicleExpiryCtrl.clear();
    }
  }

  void invalidateAddressConfirm() {
    if (!addressConfirmed.value && geocodeFormattedAddress.value == null) {
      return;
    }
    addressConfirmed.value = false;
    geocodeFormattedAddress.value = null;
    latCtrl.clear();
    lngCtrl.clear();
  }

  Future<void> lookupAddress() async {
    final meRepo = _meRepository;
    if (meRepo == null) return;
    addressConfirmed.value = false;
    final line1 = addressLine1Ctrl.text.trim();
    final city = suburbCtrl.text.trim();
    if (line1.isEmpty || city.isEmpty) {
      errorMessage.value = 'Enter address line 1 and suburb before looking up.';
      return;
    }
    isGeocoding.value = true;
    errorMessage.value = null;
    try {
      final result = await meRepo.geocode(
        GeocodeRequest(
          addressLine1: line1,
          city: city,
          country: countryCtrl.text.trim().isEmpty ? 'AU' : countryCtrl.text.trim(),
          state: stateCtrl.text.trim().isEmpty ? null : stateCtrl.text.trim(),
        ),
      );
      final outcome = applyGeocodeResponse(
        result: client_models.GeocodeResponse(
          latitude: result.latitude,
          longitude: result.longitude,
          formattedAddress: result.formattedAddress,
          confidence: result.confidence,
        ),
        latCtrl: latCtrl,
        lngCtrl: lngCtrl,
        formattedAddress: geocodeFormattedAddress,
        addressConfirmed: addressConfirmed,
        addressFallback: '$line1, $city',
      );
      if (!outcome.accepted) {
        errorMessage.value = outcome.errorMessage;
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      geocodeFormattedAddress.value = null;
    } catch (e) {
      errorMessage.value = e.toString();
      geocodeFormattedAddress.value = null;
    } finally {
      isGeocoding.value = false;
    }
  }

  void confirmAddress() {
    final lat = double.tryParse(latCtrl.text.trim());
    final lng = double.tryParse(lngCtrl.text.trim());
    if (lat == null || lng == null) {
      errorMessage.value = 'Look up an address before confirming.';
      return;
    }
    addressConfirmed.value = true;
    errorMessage.value = null;
  }

  void editAddressLookup() {
    addressConfirmed.value = false;
    geocodeFormattedAddress.value = null;
    latCtrl.clear();
    lngCtrl.clear();
    errorMessage.value = null;
  }

  void addQualification() => qualifications.add(ContractorQualRow());

  void removeQualification(int index) {
    if (qualifications.length <= 1) return;
    qualifications[index].dispose();
    qualifications.removeAt(index);
  }

  Future<void> pickDob(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 16),
    );
    if (picked == null) return;
    dobCtrl.text =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
  }

  Future<void> pickDate(
    BuildContext context,
    TextEditingController controller, {
    DateTime? initial,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year + 20),
    );
    if (picked == null) return;
    controller.text =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic>? _metadataPayload(ContractorMeOut? existing) {
    final base = Map<String, dynamic>.from(existing?.metadata ?? {});
    final lat = double.tryParse(latCtrl.text.trim());
    final lng = double.tryParse(lngCtrl.text.trim());
    if (lat != null && lng != null) {
      base['location'] = {'latitude': lat, 'longitude': lng};
    } else {
      base.remove('location');
    }
    final compliance = _compliancePayload();
    if (compliance != null) {
      base['compliance'] = compliance;
    } else {
      base.remove('compliance');
    }
    return base.isEmpty ? null : base;
  }

  Map<String, dynamic>? _compliancePayload() {
    final screening = <String, dynamic>{
      if (screeningNumberCtrl.text.trim().isNotEmpty)
        'number': screeningNumberCtrl.text.trim(),
      if (screeningStatus.value != null) 'status': screeningStatus.value,
      if (screeningIssueCtrl.text.trim().isNotEmpty)
        'issue_date': screeningIssueCtrl.text.trim(),
      if (screeningExpiryCtrl.text.trim().isNotEmpty)
        'expiry_date': screeningExpiryCtrl.text.trim(),
      if (screeningStateCtrl.text.trim().isNotEmpty)
        'state': screeningStateCtrl.text.trim(),
    };
    final quals = <Map<String, dynamic>>[];
    for (final row in qualifications) {
      final item = <String, dynamic>{'type': row.type};
      if (row.issueDateCtrl.text.trim().isNotEmpty) {
        item['issue_date'] = row.issueDateCtrl.text.trim();
      }
      if (row.expiryDateCtrl.text.trim().isNotEmpty) {
        item['expiry_date'] = row.expiryDateCtrl.text.trim();
      }
      if (item.length > 1) quals.add(item);
    }
    final checks = <String, dynamic>{};
    final wwcc = <String, dynamic>{
      if (wwccNumberCtrl.text.trim().isNotEmpty)
        'number': wwccNumberCtrl.text.trim(),
      if (wwccStateCtrl.text.trim().isNotEmpty)
        'state': wwccStateCtrl.text.trim(),
      if (wwccExpiryCtrl.text.trim().isNotEmpty)
        'expiry_date': wwccExpiryCtrl.text.trim(),
    };
    if (wwcc.isNotEmpty) checks['wwcc'] = wwcc;
    if (policeIssueCtrl.text.trim().isNotEmpty) {
      checks['police_check'] = {'issue_date': policeIssueCtrl.text.trim()};
    }
    final licence = <String, dynamic>{
      if (licenceNumberCtrl.text.trim().isNotEmpty)
        'number': licenceNumberCtrl.text.trim(),
      if (licenceStateCtrl.text.trim().isNotEmpty)
        'state': licenceStateCtrl.text.trim(),
      if (licenceExpiryCtrl.text.trim().isNotEmpty)
        'expiry_date': licenceExpiryCtrl.text.trim(),
    };
    if (licence.isNotEmpty) checks['drivers_licence'] = licence;
    final vehicle = <String, dynamic>{
      if (vehiclePlateCtrl.text.trim().isNotEmpty)
        'plate': vehiclePlateCtrl.text.trim(),
      if (vehicleStateCtrl.text.trim().isNotEmpty)
        'state': vehicleStateCtrl.text.trim(),
      if (vehicleExpiryCtrl.text.trim().isNotEmpty)
        'expiry_date': vehicleExpiryCtrl.text.trim(),
    };
    if (vehicle.isNotEmpty) checks['vehicle_registration'] = vehicle;

    final payload = <String, dynamic>{};
    if (screening.isNotEmpty) payload['screening'] = screening;
    if (quals.isNotEmpty) payload['qualifications'] = quals;
    if (checks.isNotEmpty) payload['checks'] = checks;
    return payload.isEmpty ? null : payload;
  }

  String? _optionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> saveProfile() async {
    final meRepo = _meRepository;
    if (meRepo == null) return;
    if (!(profileFormKey.currentState?.validate() ?? false)) return;

    isSaving.value = true;
    errorMessage.value = null;
    try {
      String? abn;
      try {
        abn = AbnUtils.normalizeOrNull(abnCtrl.text);
      } on FormatException catch (e) {
        errorMessage.value = e.message;
        return;
      }

      var me = await meRepo.patchMe(
        fullName: _optionalText(fullNameCtrl.text),
        phone: _optionalText(phoneCtrl.text),
        dob: _optionalText(dobCtrl.text),
        abn: abn,
        addressLine1: _optionalText(addressLine1Ctrl.text),
        addressLine2: _optionalText(addressLine2Ctrl.text),
        suburb: _optionalText(suburbCtrl.text),
        state: _optionalText(stateCtrl.text),
        postcode: _optionalText(postcodeCtrl.text),
        country: _optionalText(countryCtrl.text),
        metadata: _metadataPayload(profile.value),
      );

      final name = accountNameCtrl.text.trim();
      final bsb = AbnUtils.digitsOnly(bsbCtrl.text);
      final account = AbnUtils.digitsOnly(accountNumberCtrl.text);
      final anyPayment = name.isNotEmpty || bsb.isNotEmpty || account.isNotEmpty;
      if (anyPayment) {
        if (name.isEmpty || bsb.isEmpty || account.isEmpty) {
          errorMessage.value =
              'To save payment details, fill account name, BSB, and account number.';
          return;
        }
        me = await meRepo.putPaymentDetails(
          ContractorPaymentDetailsIn(
            accountName: name,
            bsb: bsb,
            accountNumber: account,
          ),
        );
        accountNumberCtrl.clear();
      }

      profile.value = me;
      _bindFromProfile(me);
      _session.needsProfileCompletion.value = !me.isProfileComplete;
      AppToast.success('Saved', 'Profile updated.');
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _loadEvents() async {
    isLoading.value = true;
    try {
      events.assignAll(await _repository.listNotificationEvents());
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadProfilePhoto() async {
    isPhotoLoading.value = true;
    try {
      final result = await _repository.getContractorProfilePhoto();
      photo.value = result;
      if (result.hasDisplayableUrl) {
        localPhotoBytes.value = null;
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
    } finally {
      isPhotoLoading.value = false;
    }
  }

  Future<void> onPhotoPicked(PickedProfilePhoto picked) async {
    final contractorId = _session.contractorId.value;
    final pipeline = _pipeline;
    if (contractorId == null || contractorId.isEmpty || pipeline == null) {
      errorMessage.value = 'Cannot upload photo: missing contractor session.';
      return;
    }
    if (!canUploadPhoto) {
      errorMessage.value = 'Missing documents.upload permission.';
      return;
    }

    isPhotoLoading.value = true;
    errorMessage.value = null;
    localPhotoBytes.value = picked.bytes;
    try {
      final doc = await pipeline.uploadEvidence(
        request: UploadUrlRequest(
          ownerType: 'contractor',
          ownerId: contractorId,
          filename: picked.name,
          contentType: picked.contentType,
          sizeBytes: picked.bytes.length,
          category: 'contractor_photo',
        ),
        bytes: picked.bytes,
      );
      final result = await _repository.setContractorProfilePhoto(doc.id);
      photo.value = result;
      AppToast.success('Profile photo updated', 'Your photo was saved.');
    } on AppFailure catch (e) {
      await BillingGate.showIfNeeded(e);
      errorMessage.value = e.message;
      localPhotoBytes.value = null;
    } catch (e) {
      errorMessage.value = e.toString();
      localPhotoBytes.value = null;
    } finally {
      isPhotoLoading.value = false;
    }
  }

  Future<void> removeProfilePhoto() async {
    isPhotoLoading.value = true;
    errorMessage.value = null;
    try {
      final result = await _repository.clearContractorProfilePhoto();
      photo.value = result;
      localPhotoBytes.value = null;
      AppToast.info('Profile photo removed', 'Your photo was cleared.');
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isPhotoLoading.value = false;
    }
  }

  Future<void> submitRightsRequest() async {
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final created = await _repository.createRightsRequest(
        RightsRequestCreate(
          requestType: rightsType.value,
          notes: rightsNotesCtrl.text,
        ),
      );
      lastRights.value = created;
      rightsNotesCtrl.clear();
      AppToast.success(
        'Request submitted',
        '${created.requestType} · ${created.status}',
      );
    } on AppFailure catch (e) {
      await BillingGate.showIfNeeded(e);
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> runPrivacyExport() async {
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final result = await _repository.privacyExport();
      lastExport.value = result;
      AppToast.info(
        'Privacy export',
        result.message ?? result.downloadUrl ?? 'Export requested',
      );
    } on AppFailure catch (e) {
      await BillingGate.showIfNeeded(e);
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> confirmWithdrawConsent() async {
    if (!canConsent) {
      errorMessage.value = 'Missing compliance.consent.manage.';
      return;
    }
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Withdraw consent?'),
        content: const Text(
          'Withdrawing sensitive-data consent may block future platform-mediated '
          'access to that credential class. Your provider may still retain lawful '
          'copies outside this app. This does not delete historical records by itself.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _repository.withdrawConsent(
        credentialType: withdrawTypeCtrl.text.trim(),
      );
      AppToast.info(
        'Consent withdrawn',
        'Recorded for ${withdrawTypeCtrl.text.trim()}.',
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }
}
