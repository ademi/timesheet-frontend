import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yemen_gate_attendance_app/app/constants/scheduling_permissions.dart';
import 'package:yemen_gate_attendance_app/core/services/token_storage.dart';

String _fakeJwt(Map<String, dynamic> payload) {
  final header = base64Url.encode(
    utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
  );
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return '$header.$body.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('persists and reads access/refresh tokens', () async {
    final storage = TokenStorage();
    await storage.loadFromStorage();

    await storage.persist(accessToken: 'access', refreshToken: 'refresh');

    expect(storage.accessToken, 'access');
    expect(storage.refreshToken, 'refresh');
  });

  test('persists branch id when provided', () async {
    final storage = TokenStorage();
    await storage.persist(
      accessToken: 'access',
      refreshToken: 'refresh',
      branchId: 'branch-1',
    );

    expect(storage.branchId, 'branch-1');
  });

  test('persists branch selection with name', () async {
    final storage = TokenStorage();
    await storage.persistBranchSelection(
      branchId: 'branch-1',
      branchName: 'Head Office',
    );

    expect(storage.branchId, 'branch-1');
    expect(storage.branchName, 'Head Office');
  });

  test('persistTokens does not clear selected branch', () async {
    final storage = TokenStorage();
    await storage.persistBranchSelection(
      branchId: 'branch-1',
      branchName: 'Head Office',
    );
    await storage.persistTokens(accessToken: 'new-access', refreshToken: 'new-refresh');

    expect(storage.branchId, 'branch-1');
    expect(storage.branchName, 'Head Office');
    expect(storage.accessToken, 'new-access');
  });

  test('clears persisted tokens', () async {
    final storage = TokenStorage();
    await storage.persist(accessToken: 'access', refreshToken: 'refresh');

    await storage.clear();

    expect(storage.accessToken, isNull);
    expect(storage.refreshToken, isNull);
    expect(storage.branchId, isNull);
  });

  test('needsProactiveRefresh is false without token', () {
    final storage = TokenStorage();
    expect(storage.needsProactiveRefresh(), isFalse);
  });

  test('permissions empty without token', () {
    final storage = TokenStorage();
    expect(storage.permissions, isEmpty);
    expect(storage.canViewSchedule, isFalse);
    expect(storage.canManageSchedule, isFalse);
  });

  test('scheduling.read grants view only', () async {
    final storage = TokenStorage();
    await storage.persistTokens(
      accessToken: _fakeJwt({
        'permissions': [SchedulingPermissions.read],
        'exp': 9999999999,
      }),
      refreshToken: 'refresh',
    );

    expect(storage.hasPermission(SchedulingPermissions.read), isTrue);
    expect(storage.hasPermission(SchedulingPermissions.manage), isFalse);
    expect(storage.canViewSchedule, isTrue);
    expect(storage.canManageSchedule, isFalse);
  });

  test('scheduling.manage grants view and manage', () async {
    final storage = TokenStorage();
    await storage.persistTokens(
      accessToken: _fakeJwt({
        'permissions': [SchedulingPermissions.manage],
        'exp': 9999999999,
      }),
      refreshToken: 'refresh',
    );

    expect(storage.canViewSchedule, isTrue);
    expect(storage.canManageSchedule, isTrue);
  });

  test('wildcard permission grants all', () async {
    final storage = TokenStorage();
    await storage.persistTokens(
      accessToken: _fakeJwt({
        'permissions': ['*'],
        'exp': 9999999999,
      }),
      refreshToken: 'refresh',
    );

    expect(storage.hasPermission(SchedulingPermissions.read), isTrue);
    expect(storage.hasPermission(SchedulingPermissions.manage), isTrue);
  });
}
