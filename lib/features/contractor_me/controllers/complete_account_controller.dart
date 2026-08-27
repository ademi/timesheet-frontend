import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/utils/abn_utils.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/models/contractor_me_models.dart';
import '../data/repositories/contractor_me_repository.dart';

class CompleteAccountController extends GetxController {
  CompleteAccountController({
    required ContractorMeRepository repository,
    SessionService? session,
  })  : _repository = repository,
        _session = session;

  final ContractorMeRepository _repository;
  final SessionService? _session;

  final formKey = GlobalKey<FormState>();
  final abnCtrl = TextEditingController();
  final accountNameCtrl = TextEditingController();
  final bsbCtrl = TextEditingController();
  final accountNumberCtrl = TextEditingController();

  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();
  final profile = Rxn<ContractorMeOut>();
  final hasExistingPayment = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    abnCtrl.dispose();
    accountNameCtrl.dispose();
    bsbCtrl.dispose();
    accountNumberCtrl.dispose();
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final me = await _repository.getMe();
      profile.value = me;
      abnCtrl.text = me.abn ?? '';
      final payment = me.paymentDetails;
      hasExistingPayment.value = payment != null;
      if (payment != null) {
        accountNameCtrl.text = payment.accountName;
        bsbCtrl.text = payment.bsb;
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> save({required bool continueToApp}) async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    isSaving.value = true;
    errorMessage.value = null;
    try {
      final abn = AbnUtils.normalizeOrNull(abnCtrl.text);
      var me = await _repository.patchMe(abn: abn);

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
        me = await _repository.putPaymentDetails(
          ContractorPaymentDetailsIn(
            accountName: name,
            bsb: bsb,
            accountNumber: account,
          ),
        );
        accountNumberCtrl.clear();
      }

      profile.value = me;
      hasExistingPayment.value = me.paymentDetails != null;
      if (Get.isRegistered<SessionService>()) {
        Get.find<SessionService>().needsProfileCompletion.value =
            !me.isProfileComplete;
      } else {
        await _session?.refreshProfileCompletion();
      }
      AppToast.success('Saved', 'Your account details were updated.');
      if (continueToApp) {
        Get.offAllNamed(AppRoutes.contractorHome);
      }
    } on FormatException catch (e) {
      errorMessage.value = e.message;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }

  void skip() => Get.offAllNamed(AppRoutes.contractorHome);
}
