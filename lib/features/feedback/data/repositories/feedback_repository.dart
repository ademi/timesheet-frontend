import '../datasources/feedback_remote_datasource.dart';
import '../models/feedback_models.dart';

class FeedbackRepository {
  FeedbackRepository({required FeedbackRemoteDataSource remote})
    : _remote = remote;

  final FeedbackRemoteDataSource _remote;

  Future<FeedbackOut> submit(FeedbackCreateRequest body) =>
      _remote.submit(body);

  Future<List<FeedbackOut>> list({int limit = 50}) =>
      _remote.list(limit: limit);
}
