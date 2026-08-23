import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/constants/api_paths.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';
import 'package:rostiq/features/visits/data/datasources/visits_remote_datasource.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late VisitsRemoteDataSource dataSource;

  const visitId = 'visit-1';
  const taskId = 'task-1';
  final visitJson = {
    'id': visitId,
    'tenant_id': 'tenant-1',
    'job_id': 'job-1',
    'contractor_id': 'contractor-1',
    'engagement_id': 'engagement-1',
    'scheduled_start': '2026-07-30T09:00:00Z',
    'scheduled_end': '2026-07-30T10:00:00Z',
    'status': 'scheduled',
    'source': 'manual',
    'latitude': 0.0,
    'longitude': 0.0,
    'geofence_radius_m': 100,
    'geofence_mode': 'informational',
    'payment_status': 'unpaid',
    'created_at': '2026-07-30T09:00:00Z',
    'updated_at': '2026-07-30T09:00:00Z',
  };

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
  });

  setUp(() {
    dio = MockDio();
    dataSource = VisitsRemoteDataSource(authenticatedDio: dio);
  });

  test('patchVisitSupportItem patches support item path', () async {
    when(
      () => dio.patch<Map<String, dynamic>>(
        ApiPaths.visitSupportItem(visitId),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ApiPaths.visitSupportItem(visitId)),
        data: {
          ...visitJson,
          'support_item_code': '01_011_0107_1_1',
          'support_item_name': 'Self care',
        },
      ),
    );

    final visit = await dataSource.patchVisitSupportItem(
      visitId,
      const SupportItemPatch(
        supportItemCode: '01_011_0107_1_1',
        supportItemName: 'Self care',
      ),
    );

    expect(visit.supportItemCode, '01_011_0107_1_1');
  });

  test('patchVisitPriceTier patches price tier path', () async {
    when(
      () => dio.patch<Map<String, dynamic>>(
        ApiPaths.visitPriceTier(visitId),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ApiPaths.visitPriceTier(visitId)),
        data: {...visitJson, 'price_tier_override': 'remote'},
      ),
    );

    final visit = await dataSource.patchVisitPriceTier(
      visitId,
      const VisitPriceTierPatch(priceTierOverride: PriceTier.remote),
    );

    expect(visit.priceTierOverride, PriceTier.remote);
  });

  test('patchVisitTaskBilling patches task billing path', () async {
    when(
      () => dio.patch<Map<String, dynamic>>(
        ApiPaths.visitTaskBilling(visitId, taskId),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(
          path: ApiPaths.visitTaskBilling(visitId, taskId),
        ),
        data: {
          'id': taskId,
          'tenant_id': 'tenant-1',
          'visit_id': visitId,
          'title': 'Shower',
          'sort_order': 0,
          'is_done': false,
          'billable_minutes': 90,
          'created_at': '2026-07-30T09:00:00Z',
          'updated_at': '2026-07-30T09:00:00Z',
        },
      ),
    );

    final task = await dataSource.patchVisitTaskBilling(
      visitId: visitId,
      taskId: taskId,
      body: const VisitTaskBillingPatch(billableMinutes: 90),
    );

    expect(task.billableMinutes, 90);
  });
}
