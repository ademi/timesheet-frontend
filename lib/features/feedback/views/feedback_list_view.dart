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
                                subtitle: Text(
                                  [
                                    if (item.severity != null)
                                      humanizeLabel(item.severity!),
                                    if (item.roleLabel != null)
                                      item.roleLabel!,
                                    item.createdAt.toLocal().toString(),
                                    if (item.screenRoute != null)
                                      item.screenRoute!,
                                  ].join(' · '),
                                ),
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
