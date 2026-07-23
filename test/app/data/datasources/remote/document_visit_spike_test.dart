import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/data/datasources/remote/document_remote_datasource.dart';
import 'package:rostiq/app/data/datasources/remote/visit_remote_datasource.dart';
import 'package:rostiq/app/data/models/document/document_models.dart';
import 'package:rostiq/app/data/models/visit/visit_gps_body.dart';

class MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(Options());
  });

  group('DocumentRemoteDataSource spike', () {
    late MockDio authDio;
    late MockDio plainDio;
    late DocumentRemoteDataSource ds;

    setUp(() {
      authDio = MockDio();
      plainDio = MockDio();
      ds = DocumentRemoteDataSource(
        authenticatedDio: authDio,
        plainDio: plainDio,
      );
    });

    test('uploadBytes: upload-url → PUT → finalize', () async {
      when(
        () => authDio.post<Map<String, dynamic>>(
          '/v1/documents/upload-url',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/v1/documents/upload-url'),
          statusCode: 201,
          data: {
            'document_id': 'dddddddd-dddd-dddd-dddd-dddddddddddd',
            'upload_url': 'https://storage.example/put',
            'gcs_object_key': 'contractors/x/file.txt',
            'expires_in_seconds': 900,
          },
        ),
      );
      when(
        () => plainDio.put<void>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: 'https://storage.example/put'),
          statusCode: 200,
        ),
      );
      when(
        () => authDio.post<Map<String, dynamic>>(
          '/v1/documents/dddddddd-dddd-dddd-dddd-dddddddddddd/finalize',
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/finalize'),
          statusCode: 200,
          data: {
            'id': 'dddddddd-dddd-dddd-dddd-dddddddddddd',
            'owner_type': 'contractor',
            'owner_id': '33333333-3333-3333-3333-333333333333',
            'category': 'passport_id',
            'filename': 'file.txt',
            'content_type': 'text/plain',
            'size_bytes': 4,
            'scan_status': 'pending',
          },
        ),
      );

      final doc = await ds.uploadBytes(
        request: const UploadUrlRequest(
          ownerType: 'contractor',
          ownerId: '33333333-3333-3333-3333-333333333333',
          filename: 'file.txt',
          contentType: 'text/plain',
          sizeBytes: 4,
          category: 'passport_id',
        ),
        bytes: utf8Bytes('spike'),
      );

      expect(doc.scanStatus, 'pending');
      expect(doc.id, startsWith('dddd'));
      verify(
        () => plainDio.put<void>(
          'https://storage.example/put',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).called(1);
    });
  });

  group('VisitRemoteDataSource spike', () {
    late MockDio authDio;
    late VisitRemoteDataSource ds;

    setUp(() {
      authDio = MockDio();
      ds = VisitRemoteDataSource(authenticatedDio: authDio);
    });

    test('checkIn posts VisitGpsBody + Idempotency-Key', () async {
      when(
        () => authDio.post<Map<String, dynamic>>(
          '/v1/visits/vvvvvvvv-vvvv-vvvv-vvvv-vvvvvvvvvvvv/check-in',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/check-in'),
          statusCode: 200,
          data: {
            'visit_id': 'vvvvvvvv-vvvv-vvvv-vvvv-vvvvvvvvvvvv',
            'status': 'checked_in',
            'time_entry_id': 'tttttttt-tttt-tttt-tttt-tttttttttttt',
          },
        ),
      );

      final result = await ds.checkIn(
        visitId: 'vvvvvvvv-vvvv-vvvv-vvvv-vvvvvvvvvvvv',
        gps: const VisitGpsBody(lat: -33.8688, lng: 151.2093, accuracyM: 12.5),
        idempotencyKey: 'checkin-vvvvvvvv-vvvv-vvvv-vvvv-vvvvvvvvvvvv',
      );

      expect(result.status, 'checked_in');
      expect(result.timeEntryId, isNotEmpty);
      final captured = verify(
        () => authDio.post<Map<String, dynamic>>(
          '/v1/visits/vvvvvvvv-vvvv-vvvv-vvvv-vvvvvvvvvvvv/check-in',
          data: captureAny(named: 'data'),
          options: captureAny(named: 'options'),
        ),
      ).captured;
      expect(captured[0], {
        'lat': -33.8688,
        'lng': 151.2093,
        'accuracy_m': 12.5,
      });
      final options = captured[1] as Options;
      expect(
        options.headers?['Idempotency-Key'],
        'checkin-vvvvvvvv-vvvv-vvvv-vvvv-vvvvvvvvvvvv',
      );
    });
  });
}

List<int> utf8Bytes(String s) => s.codeUnits;
