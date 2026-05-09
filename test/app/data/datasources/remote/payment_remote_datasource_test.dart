import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yemen_gate_attendance_app/app/data/datasources/remote/payment_remote_datasource.dart';
import 'package:yemen_gate_attendance_app/app/data/models/payment/create_payment_request.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late PaymentRemoteDataSource dataSource;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
  });

  setUp(() {
    dio = MockDio();
    dataSource = PaymentRemoteDataSource(dio: dio);
  });

  group('PaymentRemoteDataSource', () {
    test('createPayment sends payload and parses response', () async {
      const request = CreatePaymentRequest(
        employeeId: 'emp-1',
        paymentDate: '2026-05-09',
        amountPaid: 100.0,
        currencyCode: 'USD',
        paymentMethod: 'cash',
      );
      when(() => dio.post('/api/v1/payments', data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/api/v1/payments'),
          statusCode: 201,
          data: {
            'id': 'p-1',
            'tenant_id': 't-1',
            'employee_id': 'emp-1',
            'payroll_result_id': null,
            'payment_date': '2026-05-09',
            'amount_paid': 100.0,
            'currency_code': 'USD',
            'payment_method': 'cash',
            'reference_no': null,
            'notes': null,
            'created_by_user_id': null,
            'created_at': '2026-05-09T10:00:00Z',
            'updated_at': '2026-05-09T10:00:00Z',
          },
        ),
      );

      final result = await dataSource.createPayment(request);
      expect(result.id, 'p-1');

      verify(() => dio.post('/api/v1/payments', data: request.toJson())).called(1);
    });

    test('getPaymentsReport passes query parameters', () async {
      when(
        () => dio.get('/api/v1/payments/report', queryParameters: any(named: 'queryParameters')),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/api/v1/payments/report'),
          statusCode: 200,
          data: [
            {
              'payment_id': 'p-1',
              'payment_date': '2026-05-09',
              'amount_paid': 300,
              'currency_code': 'USD',
              'payment_method': 'bank_transfer',
              'reference_no': 'ref',
              'created_at': '2026-05-09T10:00:00Z',
              'employee_id': 'e-1',
              'employee_code': 'EMP-001',
              'employee_name': 'Ahmed',
              'branch_id': 'b-1',
            },
          ],
        ),
      );

      final result = await dataSource.getPaymentsReport(
        from: '2026-05-01',
        to: '2026-05-31',
        employeeId: 'e-1',
        branchId: 'b-1',
      );

      expect(result, hasLength(1));
      verify(
        () => dio.get(
          '/api/v1/payments/report',
          queryParameters: {
            'from': '2026-05-01',
            'to': '2026-05-31',
            'employee_id': 'e-1',
            'branch_id': 'b-1',
          },
        ),
      ).called(1);
    });

    test('propagates 400/403/401 errors from backend', () async {
      when(() => dio.post('/api/v1/payments', data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/payments'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/payments'),
            statusCode: 400,
            data: {'detail': 'bad request'},
          ),
        ),
      );
      when(
        () => dio.get('/api/v1/payments/report', queryParameters: any(named: 'queryParameters')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/payments/report'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/payments/report'),
            statusCode: 403,
            data: {'detail': 'forbidden'},
          ),
        ),
      );
      when(() => dio.get('/api/v1/payments/employees/e-1')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/payments/employees/e-1'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/payments/employees/e-1'),
            statusCode: 401,
            data: {'detail': 'unauthorized'},
          ),
        ),
      );

      await expectLater(
        () => dataSource.createPayment(
          const CreatePaymentRequest(
            employeeId: 'e-1',
            paymentDate: '2026-05-09',
            amountPaid: 100,
            currencyCode: 'USD',
          ),
        ),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        () => dataSource.getPaymentsReport(from: '2026-05-01', to: '2026-05-09'),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        () => dataSource.getEmployeePaymentHistory('e-1'),
        throwsA(isA<DioException>()),
      );
    });
  });
}
