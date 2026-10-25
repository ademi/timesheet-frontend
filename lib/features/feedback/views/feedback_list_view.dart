import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/utils/humanize_label.dart';
import '../data/models/feedback_models.dart';
import '../data/repositories/feedback_repository.dart';
import '../widgets/feedback_sheet.dart';

/// Owner/admin list of tenant feedback (`GET /v1/feedback`).
class FeedbackListView extends StatefulWidget {
  const FeedbackListView({super.key});

  @override
  State<FeedbackListView> createState() => _FeedbackListViewState();
}

class _FeedbackListViewState extends State<FeedbackListView> {
  final _items = <FeedbackOut>[];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    ensureFeedbackRepository();
    if (!Get.isRegistered<FeedbackRepository>()) {
      setState(() {
        _loading = false;
        _error = 'Session not ready.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await Get.find<FeedbackRepository>().list();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(list);
        _loading = false;
      });
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load feedback.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pilot feedback')),
      body: RefreshIndicator(
        onRefresh: _load,
        child:
            _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    PageContent(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            Text(
                              _error!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (!_loading && _items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 48),
                              child: Center(
                                child: Text('No feedback yet.'),
                              ),
                            ),
                          for (final item in _items) ...[
                            Card(
                              child: ListTile(
                                title: Text(item.message),
                                subtitle: Text(_feedbackMetaLine(item)),
                                isThreeLine: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

String _feedbackMetaLine(FeedbackOut item) {
  final role =
      (item.actorRole?.trim().isNotEmpty ?? false)
          ? item.actorRole!.trim()
          : (item.roleLabel?.trim().isNotEmpty ?? false)
          ? item.roleLabel!.trim()
          : _fallbackActorRole(item.actorType);
  final name = item.actorName?.trim();
  return [
    if (item.severity != null) humanizeLabel(item.severity!),
    if (role != null) humanizeLabel(role),
    if (name != null && name.isNotEmpty) name,
    _formatFeedbackDateTime(item.createdAt),
    if (item.screenRoute != null) item.screenRoute!,
  ].join(' · ');
}

String? _fallbackActorRole(String? actorType) {
  switch (actorType) {
    case 'tenant_member':
      return 'Staff';
    case 'contractor':
      return 'Support worker';
    case 'platform':
      return 'Platform';
    default:
      return null;
  }
}

/// Local time as `mm/dd/yyyy, hh:mm:ss` (24-hour).
String _formatFeedbackDateTime(DateTime value) {
  final local = value.toLocal();
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  final yyyy = local.year.toString();
  final hh = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  final ss = local.second.toString().padLeft(2, '0');
  return '$mm/$dd/$yyyy, $hh:$min:$ss';
}
