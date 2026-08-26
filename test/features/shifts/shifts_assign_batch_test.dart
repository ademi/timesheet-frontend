import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/constants/api_paths.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/shifts/data/datasources/shifts_remote_datasource.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late ShiftsRemoteDataSource dataSource;

  final shiftJson = {
    'id': 'shift-1',
    'tenant_id': 'tenant-1',
    'job_id': 'job-1',
    'job_title': 'Support',
    'scheduled_start': '2026-08-22T09:00:00Z',
    'scheduled_end': '2026-08-22T12:00:00Z',
    'required_slots': 2,
    'open_slots': 0,
    'status': 'published',
    'assignments': [
      {
        'id': 'a1',
        'contractor_id': 'c1',
        'contractor_name': 'Alex',
        'visit_id': 'v1',
        'source': 'staff_assign',
        'status': 'active',
      },
      {
        'id': 'a2',
        'contractor_id': 'c2',
        'contractor_name': 'Blake',
        'visit_id': 'v2',
        'source': 'staff_assign',
        'status': 'active',
      },
    ],
    'created_at': '2026-08-22T08:00:00Z',
    'updated_at': '2026-08-22T08:30:00Z',
  };

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
  });

  setUp(() {
    dio = MockDio();
    dataSource = ShiftsRemoteDataSource(authenticatedDio: dio);
  });

  test('ApiPaths.shiftAssignBatch builds assign-batch path', () {
    expect(
      ApiPaths.shiftAssignBatch('shift-1'),
      '/v1/shifts/shift-1/assign-batch',
    );
  });

  test('assignShiftBatch posts contractor_ids and task_template', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        ApiPaths.shiftAssignBatch('shift-1'),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(
          path: ApiPaths.shiftAssignBatch('shift-1'),
        ),
        data: shiftJson,
      ),
    );

    final shift = await dataSource.assignShiftBatch(
      shiftId: 'shift-1',
      contractorIds: const ['c1', 'c2'],
      taskTemplate: const [
        TaskTemplateItem(title: 'Care', sortOrder: 0),
      ],
    );

    expect(shift.id, 'shift-1');
    expect(shift.openSlots, 0);
    expect(shift.assignments, hasLength(2));
    verify(
      () => dio.post<Map<String, dynamic>>(
        ApiPaths.shiftAssignBatch('shift-1'),
        data: {
          'contractor_ids': ['c1', 'c2'],
          'task_template': [
            {'title': 'Care', 'sort_order': 0},
          ],
        },
      ),
    ).called(1);
  });

  test('assignShiftBatch omits task_template when empty', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        ApiPaths.shiftAssignBatch('shift-1'),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(
          path: ApiPaths.shiftAssignBatch('shift-1'),
        ),
        data: shiftJson,
      ),
    );

    await dataSource.assignShiftBatch(
      shiftId: 'shift-1',
      contractorIds: const ['c1'],
    );

    verify(
      () => dio.post<Map<String, dynamic>>(
        ApiPaths.shiftAssignBatch('shift-1'),
        data: {'contractor_ids': ['c1']},
      ),
    ).called(1);
  });
}
