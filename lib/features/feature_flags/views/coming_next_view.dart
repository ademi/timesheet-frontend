import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../data/feature_flags_models.dart';
import '../data/feature_flags_repository.dart';

/// Remote “coming next” chips from `GET /v1/public/feature-flags`.
class ComingNextView extends StatefulWidget {
  const ComingNextView({super.key});

  @override
  State<ComingNextView> createState() => _ComingNextViewState();
}

class _ComingNextViewState extends State<ComingNextView> {
  PublicFeatureFlags _flags = PublicFeatureFlags.empty;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final flags = await FeatureFlagsRepository.ensureRegistered().load();
    if (!mounted) return;
    setState(() {
      _flags = flags;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = <_ComingItem>[
      if (_flags.comingNextDndRoster)
        const _ComingItem(
          title: 'Drag-and-drop roster',
          body: 'Move shifts on the board by dragging. Compose/publish works today.',
        ),
      if (_flags.comingNextBulkImport)
        const _ComingItem(
          title: 'Bulk CSV import',
          body: 'Import workers and participants from a spreadsheet.',
        ),
      if (_flags.comingNextProda)
        const _ComingItem(
          title: 'PRODA / direct NDIA claiming',
          body: 'Not the current product path — plan-manager CSV export is available now.',
        ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Coming next')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PageContent(
                    width: PageContentWidth.narrow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Roadmap items enabled for this environment. '
                          'Available-now features are listed in the honesty one-pager.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (items.isEmpty)
                          const Text(
                            'No “coming next” flags are on right now.',
                            style: TextStyle(color: AppColors.textMuted),
                          )
                        else
                          for (final item in items) ...[
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.flag_outlined),
                                title: Text(item.title),
                                subtitle: Text(item.body),
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
    );
  }
}

class _ComingItem {
  const _ComingItem({required this.title, required this.body});
  final String title;
  final String body;
}
