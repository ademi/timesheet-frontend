import '../datasources/pilot_onboarding_remote_datasource.dart';
import '../models/pilot_onboarding_models.dart';

class PilotOnboardingRepository {
  PilotOnboardingRepository({required PilotOnboardingRemoteDataSource remote})
    : _remote = remote;

  final PilotOnboardingRemoteDataSource _remote;

  Future<PilotOnboardingOut> getStatus() => _remote.getStatus();

  Future<PilotOnboardingOut> dismiss() => _remote.dismiss();
}
