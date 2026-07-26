import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../data/models/client_models.dart';
import '../data/repositories/clients_repository.dart';

class PublicClientInviteController extends GetxController {
  PublicClientInviteController({required ClientsRepository repository})
      : _repository = repository;

  final ClientsRepository _repository;

  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();
  final invite = Rxn<ClientInvitePublicOut>();
  final doneMessage = RxnString();

  late final String token;

  @override
  void onInit() {
    super.onInit();
    token = (Get.parameters['token'] ?? Get.arguments?.toString() ?? '').trim();
    if (token.isEmpty) {
      errorMessage.value = 'Missing invite token.';
    } else {
      load();
    }
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      invite.value = await _repository.getPublicInvite(token);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> acknowledge({bool accept = true}) async {
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final result = await _repository.acknowledgePublicInvite(
        token: token,
        accept: accept,
      );
      doneMessage.value = result.message;
      await load();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }
}
