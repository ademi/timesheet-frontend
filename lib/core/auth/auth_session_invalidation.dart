import 'package:get/get.dart';

import '../services/session_service.dart';
import '../services/token_storage.dart';

/// Clears in-memory session state and persisted auth tokens.
Future<void> invalidateStoredAuthSession({
  TokenStorage? tokenStorage,
  SessionService? sessionService,
}) async {
  final session = sessionService ??
      (Get.isRegistered<SessionService>() ? Get.find<SessionService>() : null);
  final storage = tokenStorage ??
      (Get.isRegistered<TokenStorage>() ? Get.find<TokenStorage>() : null);
  await session?.clear();
  await storage?.clear();
}
