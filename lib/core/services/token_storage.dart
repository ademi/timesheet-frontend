import 'package:get_storage/get_storage.dart';

import '../constants/app_constants.dart';

class TokenStorage {
  TokenStorage({required GetStorage storage}) : _storage = storage;

  final GetStorage _storage;

  String? get accessToken => _storage.read<String>(StorageKeys.accessToken);
  String? get refreshToken => _storage.read<String>(StorageKeys.refreshToken);

  Future<void> persist({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(StorageKeys.accessToken, accessToken);
    await _storage.write(StorageKeys.refreshToken, refreshToken);
  }

  void clear() {
    _storage.remove(StorageKeys.accessToken);
    _storage.remove(StorageKeys.refreshToken);
  }
}
