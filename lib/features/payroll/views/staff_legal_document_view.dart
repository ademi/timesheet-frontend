import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/markdown_viewer.dart';
import '../../contractor_onboarding/data/datasources/compliance_remote_datasource.dart';
import '../../contractor_onboarding/data/models/compliance_models.dart';
import '../../contractor_onboarding/data/repositories/compliance_repository.dart';

/// Read-only view of a current platform legal document (privacy / terms).
///
/// Loads from `GET /v1/compliance/legal-documents/current`. Content may still
/// be counsel-pending (`v0.1-placeholder`) — ClosedBeta banner remains until
/// Legal reloads approved versions.
class StaffLegalDocumentView extends StatefulWidget {
  const StaffLegalDocumentView({
    super.key,
    required this.docKey,
    required this.title,
  });

  /// Backend `doc_key`: `privacy_policy` or `platform_terms`.
  final String docKey;
  final String title;

  @override
  State<StaffLegalDocumentView> createState() => _StaffLegalDocumentViewState();
}

class _StaffLegalDocumentViewState extends State<StaffLegalDocumentView> {
  LegalDocumentCurrent? _doc;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!Get.isRegistered<ApiClient>()) {
        throw const AppFailure(
          code: 'not_ready',
          message: 'Session not ready. Sign in again and retry.',
          presentation: AppFailurePresentation.screen,
        );
      }
      if (!Get.isRegistered<ComplianceRepository>()) {
        Get.put(
          ComplianceRepository(
            remote: ComplianceRemoteDataSource(
              authenticatedDio: Get.find<ApiClient>().dio,
            ),
          ),
        );
      }
      final doc = await Get.find<ComplianceRepository>().getCurrentLegalDocument(
        widget.docKey,
      );
      if (!mounted) return;
      setState(() {
        _doc = doc;
        _loading = false;
      });
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this document.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: 16),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : doc == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      doc.counselPending
                          ? 'Version ${doc.version} · interim (not counsel-approved)'
                          : 'Version ${doc.version}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                Expanded(child: MarkdownViewer(markdown: doc.contentMd)),
              ],
            ),
    );
  }
}
