import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/constants/api_paths.dart';
import 'package:rostiq/features/clients/data/datasources/clients_remote_datasource.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  test('getBudgetSummary calls client budget summary path', () async {
    final authenticated = _MockDio();
    final plain = _MockDio();
    const clientId = 'client-1';
    when(
      () => authenticated.get<Map<String, dynamic>>(
        ApiPaths.clientBudgetSummary(clientId),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(
          path: ApiPaths.clientBudgetSummary(clientId),
        ),
        data: {
          'client_id': clientId,
          'envelopes': [
            {'key': 'core', 'declared': 100, 'spent': 25, 'remaining': 75},
          ],
        },
      ),
    );
    final remote = ClientsRemoteDataSource(
      authenticatedDio: authenticated,
      plainDio: plain,
    );

    final summary = await remote.getBudgetSummary(clientId);

    expect(summary.clientId, clientId);
    expect(summary.envelopes.first.remaining, 75);
    verify(
      () => authenticated.get<Map<String, dynamic>>(
        ApiPaths.clientBudgetSummary(clientId),
      ),
    ).called(1);
  });
}
