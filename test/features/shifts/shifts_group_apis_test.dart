import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/constants/api_paths.dart';
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
    'required_slots': 1,
    'open_slots': 1,
    'worker_count': 2,
    'status': 'draft',
    'warnings': <String>[],
    'participants': [
      {
        'id': 'sp-1',
        'shift_id': 'shift-1',
        'participant_id': 'client-1',
        'allocation_strategy': 'percentage',
        'allocation_value': 100.0,
        'status': 'active',
        'participant_name': 'Alex',
        'created_at': '2026-08-22T08:00:00Z',
        'updated_at': '2026-08-22T08:00:00Z',
      },
    ],
    'assignments': <Map<String, dynamic>>[],
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

  test('ApiPaths group-shift helpers', () {
    expect(
      ApiPaths.shiftParticipants('s1'),
      '/v1/shifts/s1/participants',
    );
    expect(
      ApiPaths.shiftParticipantsBatch('s1'),
      '/v1/shifts/s1/participants/batch',
    );
    expect(
      ApiPaths.shiftParticipant('s1', 'c1'),
      '/v1/shifts/s1/participants/c1',
    );
    expect(
      ApiPaths.shiftParticipantAllocation('s1', 'c1'),
      '/v1/shifts/s1/participants/c1/allocation',
    );
    expect(
      ApiPaths.shiftAllocationChanges('s1'),
      '/v1/shifts/s1/allocation-changes',
    );
  });

  test('listShifts sends participant_id and include', () async {
    when(
      () => dio.get<List<dynamic>>(
        ApiPaths.shifts,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response<List<dynamic>>(
        requestOptions: RequestOptions(path: ApiPaths.shifts),
        data: [shiftJson],
      ),
    );

    final shifts = await dataSource.listShifts(participantId: 'client-1');

    expect(shifts, hasLength(1));
    expect(shifts.single.workerCount, 2);
    verify(
      () => dio.get<List<dynamic>>(
        ApiPaths.shifts,
        queryParameters: {
          'participant_id': 'client-1',
          'include': 'participants_summary',
          'limit': 200,
        },
      ),
    ).called(1);
  });

  test('putParticipants puts replace body', () async {
    when(
      () => dio.put<Map<String, dynamic>>(
        ApiPaths.shiftParticipants('shift-1'),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(
          path: ApiPaths.shiftParticipants('shift-1'),
        ),
        data: shiftJson,
      ),
    );

    final shift = await dataSource.putParticipants(
      'shift-1',
      const ShiftParticipantsReplaceRequest(
        equalSplit: true,
        participants: [
          ShiftParticipantReplaceItem(participantId: 'client-1'),
          ShiftParticipantReplaceItem(participantId: 'client-2'),
        ],
      ),
    );

    expect(shift.id, 'shift-1');
    verify(
      () => dio.put<Map<String, dynamic>>(
        ApiPaths.shiftParticipants('shift-1'),
        data: {
          'allocation_strategy': 'percentage',
          'equal_split': true,
          'participants': [
            {
              'participant_id': 'client-1',
            },
            {
              'participant_id': 'client-2',
            },
          ],
        },
      ),
    ).called(1);
  });

  test('removeParticipant deletes with reason and rebalance', () async {
    when(
      () => dio.delete<Map<String, dynamic>>(
        ApiPaths.shiftParticipant('shift-1', 'client-1'),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(
          path: ApiPaths.shiftParticipant('shift-1', 'client-1'),
        ),
        data: shiftJson,
      ),
    );

    await dataSource.removeParticipant(
      'shift-1',
      'client-1',
      reason: 'Left early',
    );

    verify(
      () => dio.delete<Map<String, dynamic>>(
        ApiPaths.shiftParticipant('shift-1', 'client-1'),
        queryParameters: {
          'reason': 'Left early',
          'rebalance': 'equal',
        },
      ),
    ).called(1);
  });

  test('patchShift patches worker_count', () async {
    when(
      () => dio.patch<Map<String, dynamic>>(
        ApiPaths.shift('shift-1'),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ApiPaths.shift('shift-1')),
        data: {...shiftJson, 'worker_count': 3},
      ),
    );

    final shift = await dataSource.patchShift(
      'shift-1',
      const ShiftPatchRequest(workerCount: 3),
    );

    expect(shift.workerCount, 3);
    verify(
      () => dio.patch<Map<String, dynamic>>(
        ApiPaths.shift('shift-1'),
        data: {'worker_count': 3},
      ),
    ).called(1);
  });

  test('publishShift posts optional support_item_code', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        ApiPaths.shiftPublish('shift-1'),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ApiPaths.shiftPublish('shift-1')),
        data: {...shiftJson, 'status': 'published'},
      ),
    );

    await dataSource.publishShift(
      'shift-1',
      body: const ShiftPublishRequest(supportItemCode: '01_011_0107_1_1'),
    );

    verify(
      () => dio.post<Map<String, dynamic>>(
        ApiPaths.shiftPublish('shift-1'),
        data: {'support_item_code': '01_011_0107_1_1'},
      ),
    ).called(1);
  });

  test('getAllocationChanges maps list', () async {
    when(
      () => dio.get<List<dynamic>>(ApiPaths.shiftAllocationChanges('shift-1')),
    ).thenAnswer(
      (_) async => Response<List<dynamic>>(
        requestOptions: RequestOptions(
          path: ApiPaths.shiftAllocationChanges('shift-1'),
        ),
        data: [
          {
            'id': 'log-1',
            'shift_id': 'shift-1',
            'change_type': 'participant_added',
            'participant_id': 'client-1',
            'old_allocation_value': null,
            'new_allocation_value': 100.0,
            'old_allocation_strategy': null,
            'new_allocation_strategy': 'percentage',
            'change_reason': 'book',
            'changed_by_user_id': 'user-1',
            'created_at': '2026-08-22T08:00:00Z',
          },
        ],
      ),
    );

    final logs = await dataSource.getAllocationChanges('shift-1');
    expect(logs, hasLength(1));
    expect(logs.single.changeType, 'participant_added');
    expect(logs.single.newAllocationValue, 100.0);
  });
}
