import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../core/services/token_storage.dart';
import '../data/models/branch/branch_model.dart';
import '../data/repositories/branch_repository.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'auth_controller.dart';
import 'gateway_controller.dart';

class BranchGatewayController extends GetxController {
  BranchGatewayController({
    required BranchRepository branchRepository,
    required TokenStorage tokenStorage,
  })  : _branchRepository = branchRepository,
        _tokenStorage = tokenStorage;

  final BranchRepository _branchRepository;
  final TokenStorage _tokenStorage;

  final branches = <BranchModel>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadBranches();
  }

  Future<void> loadBranches() async {
    try {
      isLoading.value = true;
      final list = await _branchRepository.listBranches();
      branches.assignAll(list);
      if (list.length == 1) {
        await selectBranch(list.first);
      }
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (_) {
      _showError('Failed to load branches.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> selectBranch(BranchModel branch) async {
    await _tokenStorage.persistBranchSelection(
      branchId: branch.id,
      branchName: branch.name,
    );
    final role = Get.find<GatewayController>().selectedRole.value;
    final destination =
        role == UserRole.admin ? AppRoutes.adminPanel : AppRoutes.home;
    Get.offAllNamed(destination);
  }

  Future<void> logout() async {
    if (Get.isRegistered<AuthController>()) {
      await Get.find<AuthController>().logout();
    }
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    return e.message ?? 'Unable to load branches right now.';
  }

  void _showError(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.error,
      colorText: AppColors.textLight,
    );
  }
}
