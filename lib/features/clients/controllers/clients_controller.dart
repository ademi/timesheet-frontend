import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../data/models/client_models.dart';
import '../data/repositories/clients_repository.dart';

class ClientsController extends GetxController {
  ClientsController({
    required ClientsRepository repository,
    required SessionService session,
  })  : _repository = repository,
        _session = session;

  final ClientsRepository _repository;
  final SessionService _session;

  final items = <ClientOut>[].obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  // Create / edit form
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final status = 'active'.obs;
  ClientOut? editing;

  // Detail
  final selected = Rxn<ClientOut>();
  final sites = <ClientSiteOut>[].obs;
  final contacts = <ClientContactOut>[].obs;
  final lastInvite = Rxn<ClientInviteCreateResponse>();
  final invites = <ClientInviteOut>[].obs;
  final tabIndex = 0.obs;

  // Site form
  final siteNameCtrl = TextEditingController();
  final siteAddressCtrl = TextEditingController();
  final siteCityCtrl = TextEditingController();
  final siteStateCtrl = TextEditingController();
  final siteCountryCtrl = TextEditingController();
  final sitePostalCtrl = TextEditingController();
  final siteLatCtrl = TextEditingController();
  final siteLngCtrl = TextEditingController();
  final siteRadiusCtrl = TextEditingController(text: '100');
  final siteIsPrimary = false.obs;
  final isGeocoding = false.obs;
  final geocodeHint = RxnString();
  ClientSiteOut? editingSite;

  // Contact form
  final contactNameCtrl = TextEditingController();
  final contactEmailCtrl = TextEditingController();
  final contactPhoneCtrl = TextEditingController();
  final contactIsPrimary = false.obs;
  final contactNotify = true.obs;
  ClientContactOut? editingContact;

  bool get canManage =>
      _session.hasPermission(AppPermissions.clientsManage);
  bool get canRead => _session.hasPermission(AppPermissions.clientsRead);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    notesCtrl.dispose();
    siteNameCtrl.dispose();
    siteAddressCtrl.dispose();
    siteCityCtrl.dispose();
    siteStateCtrl.dispose();
    siteCountryCtrl.dispose();
    sitePostalCtrl.dispose();
    siteLatCtrl.dispose();
    siteLngCtrl.dispose();
    siteRadiusCtrl.dispose();
    contactNameCtrl.dispose();
    contactEmailCtrl.dispose();
    contactPhoneCtrl.dispose();
    super.onClose();
  }

  Future<void> load() async {
    if (!canRead) {
      errorMessage.value = 'Missing clients.read permission.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      items.assignAll(await _repository.listClients());
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void openCreate() {
    editing = null;
    nameCtrl.clear();
    emailCtrl.clear();
    phoneCtrl.clear();
    notesCtrl.clear();
    status.value = 'active';
    errorMessage.value = null;
    Get.toNamed(AppRoutes.staffClientForm);
  }

  void openEdit(ClientOut client) {
    editing = client;
    nameCtrl.text = client.fullName;
    emailCtrl.text = client.email ?? '';
    phoneCtrl.text = client.phone ?? '';
    notesCtrl.text = client.serviceAgreementNotes ?? '';
    status.value = client.status;
    errorMessage.value = null;
    Get.toNamed(AppRoutes.staffClientForm, arguments: client);
  }

  Future<void> saveClient() async {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      errorMessage.value = 'Full name is required.';
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      if (editing == null) {
        final created = await _repository.createClient(
          ClientCreateRequest(
            fullName: name,
            status: status.value,
            email: emailCtrl.text.trim(),
            phone: phoneCtrl.text.trim(),
            serviceAgreementNotes: notesCtrl.text.trim().isEmpty
                ? null
                : notesCtrl.text.trim(),
          ),
        );
        Get.back();
        await load();
        openDetail(created);
      } else {
        await _repository.patchClient(
          editing!.id,
          ClientUpdateRequest(
            fullName: name,
            status: status.value,
            email: emailCtrl.text.trim(),
            phone: phoneCtrl.text.trim(),
            serviceAgreementNotes: notesCtrl.text.trim(),
          ),
        );
        Get.back();
        await load();
        if (selected.value?.id == editing!.id) {
          await openDetailById(editing!.id);
        }
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> deleteClient(ClientOut client) async {
    final ok = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Delete client?'),
            content: Text('Delete ${client.fullName}? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    isSaving.value = true;
    try {
      await _repository.deleteClient(client.id);
      await load();
      if (Get.currentRoute.startsWith(AppRoutes.staffClientDetail)) {
        Get.back();
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> openDetail(ClientOut client) async {
    selected.value = client;
    lastInvite.value = null;
    invites.clear();
    tabIndex.value = 0;
    Get.toNamed(AppRoutes.staffClientDetail, arguments: client);
    await openDetailById(client.id);
  }

  Future<void> openDetailById(String id) async {
    isLoading.value = true;
    try {
      final client = await _repository.getClient(id);
      selected.value = client;
      await refreshDetailExtras();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshDetailExtras() async {
    final id = selected.value?.id;
    if (id == null) return;
    try {
      final results = await Future.wait([
        _repository.listSites(id),
        _repository.listContacts(id),
      ]);
      sites.assignAll(results[0] as List<ClientSiteOut>);
      contacts.assignAll(results[1] as List<ClientContactOut>);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    }
    try {
      invites.assignAll(await _repository.listInvites(id));
    } on AppFailure catch (e) {
      invites.clear();
      errorMessage.value ??= e.message;
    }
  }

  void beginSiteForm({ClientSiteOut? site}) {
    editingSite = site;
    siteNameCtrl.text = site?.name ?? '';
    siteAddressCtrl.text = site?.addressLine1 ?? '';
    siteCityCtrl.text = site?.city ?? '';
    siteStateCtrl.text = site?.state ?? '';
    siteCountryCtrl.text = site?.country ?? '';
    sitePostalCtrl.text = site?.postalCode ?? '';
    siteLatCtrl.text = site?.latitude?.toString() ?? '';
    siteLngCtrl.text = site?.longitude?.toString() ?? '';
    siteRadiusCtrl.text = (site?.geofenceRadiusM ?? 100).toString();
    siteIsPrimary.value = site?.isPrimary ?? false;
    errorMessage.value = null;
    geocodeHint.value = null;
    Get.toNamed(AppRoutes.staffClientSiteForm);
  }

  /// Resolves lat/lng from address via `POST /v1/public/geocode`.
  /// Returns coordinates on success, or null after setting [errorMessage].
  Future<({double lat, double lng})?> geocodeFromAddress({
    bool showSuccessHint = true,
  }) async {
    final address = siteAddressCtrl.text.trim();
    final city = siteCityCtrl.text.trim();
    final state = siteStateCtrl.text.trim();
    final country = siteCountryCtrl.text.trim().toUpperCase();

    if (address.isEmpty || city.isEmpty || country.isEmpty) {
      errorMessage.value =
          'Address line 1, city, and country (ISO code, e.g. AU) are '
          'required to look up coordinates.';
      return null;
    }
    if (country.length != 2) {
      errorMessage.value =
          'Country must be a 2-letter ISO code (e.g. AU, US, GB).';
      return null;
    }

    isGeocoding.value = true;
    errorMessage.value = null;
    geocodeHint.value = null;
    try {
      final result = await _repository.geocode(
        GeocodeRequest(
          addressLine1: address,
          city: city,
          state: state.nullIfEmpty,
          country: country,
        ),
      );
      siteLatCtrl.text = result.latitude.toString();
      siteLngCtrl.text = result.longitude.toString();
      // Normalize country field to the ISO code we sent.
      siteCountryCtrl.text = country;
      if (showSuccessHint) {
        final parts = <String>[
          if (result.formattedAddress != null &&
              result.formattedAddress!.isNotEmpty)
            result.formattedAddress!,
          if (result.confidence != null) 'confidence: ${result.confidence}',
        ];
        geocodeHint.value = parts.isEmpty
            ? 'Coordinates filled from address.'
            : parts.join(' · ');
      }
      return (lat: result.latitude, lng: result.longitude);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return null;
    } catch (e) {
      errorMessage.value = e.toString();
      return null;
    } finally {
      isGeocoding.value = false;
    }
  }

  Future<void> saveSite() async {
    final clientId = selected.value?.id;
    if (clientId == null) return;
    final name = siteNameCtrl.text.trim();
    if (name.isEmpty) {
      errorMessage.value = 'Site name is required.';
      return;
    }

    var lat = double.tryParse(siteLatCtrl.text.trim());
    var lng = double.tryParse(siteLngCtrl.text.trim());

    // Auto-geocode when coordinates were not entered manually.
    if (lat == null || lng == null) {
      final coords = await geocodeFromAddress(showSuccessHint: true);
      if (coords == null) return;
      lat = coords.lat;
      lng = coords.lng;
    }

    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      errorMessage.value = 'Latitude/longitude out of range.';
      return;
    }
    final radius = int.tryParse(siteRadiusCtrl.text.trim()) ?? 100;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final body = ClientSiteWriteRequest(
        name: name,
        addressLine1: siteAddressCtrl.text.trim().nullIfEmpty,
        city: siteCityCtrl.text.trim().nullIfEmpty,
        state: siteStateCtrl.text.trim().nullIfEmpty,
        country: siteCountryCtrl.text.trim().nullIfEmpty,
        postalCode: sitePostalCtrl.text.trim().nullIfEmpty,
        latitude: lat,
        longitude: lng,
        geofenceRadiusM: radius.clamp(10, 5000),
        isPrimary: siteIsPrimary.value,
      );
      if (editingSite == null) {
        await _repository.createSite(clientId, body);
      } else {
        await _repository.patchSite(clientId, editingSite!.id, body);
      }
      Get.back();
      await refreshDetailExtras();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> deleteSite(ClientSiteOut site) async {
    final clientId = selected.value?.id;
    if (clientId == null) return;
    isSaving.value = true;
    try {
      await _repository.deleteSite(clientId, site.id);
      await refreshDetailExtras();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  void beginContactForm({ClientContactOut? contact}) {
    editingContact = contact;
    contactNameCtrl.text = contact?.name ?? '';
    contactEmailCtrl.text = contact?.email ?? '';
    contactPhoneCtrl.text = contact?.phone ?? '';
    contactIsPrimary.value = contact?.isPrimary ?? false;
    contactNotify.value = contact?.notifyVisitComplete ?? true;
    errorMessage.value = null;
    Get.toNamed(AppRoutes.staffClientContactForm);
  }

  Future<void> saveContact() async {
    final clientId = selected.value?.id;
    if (clientId == null) return;
    final email = contactEmailCtrl.text.trim();
    final phone = contactPhoneCtrl.text.trim();
    final name = contactNameCtrl.text.trim();
    if (email.isEmpty && phone.isEmpty && name.isEmpty) {
      errorMessage.value = 'Provide at least a name, email, or phone.';
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final body = ClientContactWriteRequest(
        name: name.nullIfEmpty,
        email: email.nullIfEmpty,
        phone: phone.nullIfEmpty,
        isPrimary: contactIsPrimary.value,
        notifyVisitComplete: contactNotify.value,
      );
      if (editingContact == null) {
        await _repository.createContact(clientId, body);
      } else {
        await _repository.patchContact(clientId, editingContact!.id, body);
      }
      Get.back();
      await refreshDetailExtras();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> deleteContact(ClientContactOut contact) async {
    final clientId = selected.value?.id;
    if (clientId == null) return;
    isSaving.value = true;
    try {
      await _repository.deleteContact(clientId, contact.id);
      await refreshDetailExtras();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> createInvite() async {
    final clientId = selected.value?.id;
    if (clientId == null) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final invite = await _repository.createInvite(clientId);
      lastInvite.value = invite;
      invites.assignAll(await _repository.listInvites(clientId));
      Get.snackbar(
        'Invite created',
        'Copy the link below. Expires ${invite.expiresAt.toLocal()}.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.primary,
        colorText: AppColors.onPrimary,
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  String invitePath(String token) => '/invites/client/$token';

  Future<void> copyInviteLink(String token) async {
    final path = invitePath(token);
    await Clipboard.setData(ClipboardData(text: path));
    Get.snackbar(
      'Copied',
      path,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
