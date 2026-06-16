import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../models/branch/branch_model.dart';

class BranchRemoteDataSource {
  BranchRemoteDataSource({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<BranchModel>> listBranches() async {
    final response = await _dio.get<List<dynamic>>(AppConstants.branchesPath);
    final data = response.data ?? <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(BranchModel.fromJson)
        .toList();
  }
}
