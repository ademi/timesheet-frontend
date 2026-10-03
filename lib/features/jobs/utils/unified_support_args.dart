import '../../clients/data/models/client_models.dart';

enum UnifiedSupportMode { oneSession, ongoing }

/// Legacy typed args for [AppRoutes.staffUnifiedSupport] soft-cutover.
///
/// Call sites may still pass this type; [ComposerCutover] / [RosterComposerArgs]
/// map it into the unified composer. The Unified Support wizard is removed.
class UnifiedSupportArgs {
  const UnifiedSupportArgs({this.client, this.clientId, this.initialMode});

  final ClientOut? client;
  final String? clientId;
  final UnifiedSupportMode? initialMode;

  /// Convenience for client-detail CTAs.
  factory UnifiedSupportArgs.forClient(
    ClientOut client, {
    UnifiedSupportMode? mode,
  }) => UnifiedSupportArgs(
    client: client,
    clientId: client.id,
    initialMode: mode,
  );
}
