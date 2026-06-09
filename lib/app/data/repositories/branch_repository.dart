import '../datasources/remote/branch_remote_datasource.dart';
import '../models/branch/branch_model.dart';

class BranchRepository {
  BranchRepository({required BranchRemoteDataSource remote}) : _remote = remote;

  final BranchRemoteDataSource _remote;

  Future<List<BranchModel>> listBranches() => _remote.listBranches();
}
