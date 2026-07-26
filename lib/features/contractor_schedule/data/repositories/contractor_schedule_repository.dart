import '../datasources/contractor_schedule_remote_datasource.dart';
import '../models/schedule_models.dart';

class ContractorScheduleRepository {
  ContractorScheduleRepository({required ContractorScheduleRemoteDataSource remote})
      : _remote = remote;

  final ContractorScheduleRemoteDataSource _remote;

  Future<TimetableOut> getTimetable({
    required DateTime from,
    required DateTime to,
  }) =>
      _remote.getTimetable(from: from, to: to);

  Future<List<AvailabilityRuleOut>> listAvailability() =>
      _remote.listAvailability();

  Future<List<AvailabilityRuleOut>> putAvailability(
    List<AvailabilityRuleOut> rules,
  ) =>
      _remote.putAvailability(rules);

  Future<List<LeaveOut>> listLeave() => _remote.listLeave();

  Future<LeaveOut> createLeave(LeaveCreateRequest body) =>
      _remote.createLeave(body);

  Future<void> deleteLeave(String id) => _remote.deleteLeave(id);
}
