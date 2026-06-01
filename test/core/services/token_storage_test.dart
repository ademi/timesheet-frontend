import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:yemen_gate_attendance_app/core/services/token_storage.dart';
import 'dart:io';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this._path);

  final String _path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const boxName = 'token_storage_test_box';
  final tempDir = Directory.systemTemp.createTempSync('token_storage_test_');

  setUpAll(() async {
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    await GetStorage.init(boxName);
  });

  test('persists and reads access/refresh tokens', () async {
    final rawStorage = GetStorage(boxName);
    final storage = TokenStorage(storage: rawStorage);

    await storage.persist(accessToken: 'access', refreshToken: 'refresh');

    expect(storage.accessToken, 'access');
    expect(storage.refreshToken, 'refresh');
  });

  test('clears persisted tokens', () async {
    final rawStorage = GetStorage(boxName);
    final storage = TokenStorage(storage: rawStorage);
    await storage.persist(accessToken: 'access', refreshToken: 'refresh');

    storage.clear();

    expect(storage.accessToken, isNull);
    expect(storage.refreshToken, isNull);
  });
}
