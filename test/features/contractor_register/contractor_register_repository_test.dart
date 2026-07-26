import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/features/contractor_register/data/models/contractor_register_models.dart';
import 'package:rostiq/features/contractor_register/data/repositories/contractor_register_repository.dart';
import 'package:rostiq/features/contractor_register/data/datasources/contractor_register_remote_datasource.dart';

class _MockRemote extends Mock implements ContractorRegisterRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late ContractorRegisterRepository repository;

  setUp(() {
    remote = _MockRemote();
    repository = ContractorRegisterRepository(remote: remote);
    registerFallbackValue(
      const ContractorRegisterRequest(
        fullName: 'A',
        email: 'a@b.com',
        password: 'Password1',
        termsVersion: 'v0.1-placeholder',
        privacyVersion: 'v0.1-placeholder',
      ),
    );
  });

  test('register forwards request and maps response', () async {
    const request = ContractorRegisterRequest(
      fullName: 'Ada Contractor',
      email: 'ada@example.com',
      password: 'Password1',
      termsVersion: 'v0.1-placeholder',
      privacyVersion: 'v0.1-placeholder',
    );
    when(() => remote.register(any())).thenAnswer(
      (_) async => const ContractorRegisterResponse(
        contractorId: 'c1',
        userId: 'u1',
        email: 'ada@example.com',
      ),
    );

    final result = await repository.register(request);
    expect(result.contractorId, 'c1');
    expect(result.email, 'ada@example.com');
    verify(() => remote.register(any())).called(1);
  });

  test('request json includes optional fields only when set', () {
    const withOptional = ContractorRegisterRequest(
      fullName: 'Ada',
      email: 'a@b.com',
      password: 'Password1',
      phone: '+61400000000',
      dob: '1990-01-02',
      termsVersion: 'v0.1-placeholder',
      privacyVersion: 'v0.1-placeholder',
    );
    final json = withOptional.toJson();
    expect(json['full_name'], 'Ada');
    expect(json['terms_version'], 'v0.1-placeholder');
    expect(json['privacy_version'], 'v0.1-placeholder');
    expect(json['phone'], '+61400000000');
    expect(json['dob'], '1990-01-02');
    expect(json.containsKey('access_token'), isFalse);
  });

  test('repository surfaces AppFailure', () async {
    when(() => remote.register(any())).thenThrow(
      const AppFailure(
        code: 'hard_split_violation',
        message: 'Cannot register',
        presentation: AppFailurePresentation.screen,
      ),
    );
    expect(
      () => repository.register(
        const ContractorRegisterRequest(
          fullName: 'A',
          email: 'a@b.com',
          password: 'Password1',
          termsVersion: 'v',
          privacyVersion: 'v',
        ),
      ),
      throwsA(isA<AppFailure>()),
    );
  });
}
