import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../documents/sync/media_outbox_store.dart';
import '../services/visit_location_service.dart';
import '../sync/form_draft_store.dart';
import '../sync/outbox_store.dart';

/// Worker-facing GPS / sync health panel (A20 + B2 form drafts).
class WorkerSyncDiagnosticsPanel extends StatefulWidget {
  const WorkerSyncDiagnosticsPanel({
    super.key,
    this.location = const VisitLocationService(),
    this.outboxStore,
    this.mediaOutboxStore,
    this.formDraftStore,
  });

  final VisitLocationService location;
  final OutboxStore? outboxStore;
  final MediaOutboxStore? mediaOutboxStore;
  final FormDraftStore? formDraftStore;

  @override
  State<WorkerSyncDiagnosticsPanel> createState() =>
      _WorkerSyncDiagnosticsPanelState();
}

class _WorkerSyncDiagnosticsPanelState extends State<WorkerSyncDiagnosticsPanel> {
  String _permissionLabel = 'Checking…';
  String _serviceLabel = 'Checking…';
  String _accuracyLabel = '—';
  bool _busy = false;

  OutboxStore? get _clock {
    if (widget.outboxStore != null) return widget.outboxStore;
    if (Get.isRegistered<OutboxStore>()) return Get.find<OutboxStore>();
    return null;
  }

  MediaOutboxStore? get _media {
    if (widget.mediaOutboxStore != null) return widget.mediaOutboxStore;
    if (Get.isRegistered<MediaOutboxStore>()) {
      return Get.find<MediaOutboxStore>();
    }
    return null;
  }

  FormDraftStore? get _forms {
    if (widget.formDraftStore != null) return widget.formDraftStore;
    if (Get.isRegistered<FormDraftStore>()) {
      return Get.find<FormDraftStore>();
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      if (widget.location.isWeb) {
        setState(() {
          _permissionLabel = 'Unavailable on web';
          _serviceLabel = 'Unavailable on web';
          _accuracyLabel = '—';
        });
        return;
      }
      final perm = await Geolocator.checkPermission();
      final enabled = await Geolocator.isLocationServiceEnabled();
      setState(() {
        _permissionLabel = _permLabel(perm);
        _serviceLabel = enabled ? 'Enabled' : 'Disabled';
      });
      final gps = await widget.location.tryGps();
      if (gps.status == 'captured' && gps.body?.accuracyM != null) {
        setState(() {
          _accuracyLabel = '${gps.body!.accuracyM!.round()} m';
        });
      } else {
        final fromOutbox = _clock
            ?.pending()
            .where((e) => e.accuracyM != null)
            .toList();
        if (fromOutbox != null && fromOutbox.isNotEmpty) {
          setState(() {
            _accuracyLabel =
                '${fromOutbox.last.accuracyM!.round()} m (last punch)';
          });
        } else {
          setState(() {
            _accuracyLabel = gps.failReason ?? gps.status;
          });
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _permLabel(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return 'Granted';
      case LocationPermission.denied:
        return 'Denied';
      case LocationPermission.deniedForever:
        return 'Permanently denied';
      case LocationPermission.unableToDetermine:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final clockPending = _clock?.pending().length ?? 0;
    final mediaPending = _media?.pending().length ?? 0;
    final formPending = _forms?.pendingUnsent().length ?? 0;

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Location & sync health',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _refresh,
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row('GPS permission', _permissionLabel),
            _row('Location services', _serviceLabel),
            _row('Last accuracy', _accuracyLabel),
            _row('Pending clock sync', '$clockPending'),
            _row('Pending media upload', '$mediaPending'),
            _row('Pending field notes', '$formPending'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
