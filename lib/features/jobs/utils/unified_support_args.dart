import '../../clients/data/models/client_models.dart';

enum UnifiedSupportMode { oneSession, ongoing }

/// Arguments for [UnifiedSupportController] / route navigation.
class UnifiedSupportArgs {
  const UnifiedSupportArgs({
    this.client,
    this.clientId,
    this.initialMode,
  });

  final ClientOut? client;
  final String? clientId;
  final UnifiedSupportMode? initialMode;

  /// Convenience for client-detail CTAs.
  factory UnifiedSupportArgs.forClient(
    ClientOut client, {
    UnifiedSupportMode? mode,
  }) =>
      UnifiedSupportArgs(client: client, clientId: client.id, initialMode: mode);
}
