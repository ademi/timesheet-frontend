import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yemen_gate_attendance_app/core/services/token_storage.dart';

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
}
