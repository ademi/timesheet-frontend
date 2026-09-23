import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/app_date_field.dart';
import '../../../shared/widgets/app_file_field.dart';
import '../../../shared/widgets/async_action.dart';
import '../../documents/sync/media_outbox_models.dart';
import '../data/models/visit_models.dart';

/// Renders a visit form template from `schema_json.fields` and submits payload.
class VisitSchemaForm extends StatefulWidget {
  const VisitSchemaForm({
    super.key,
    required this.requirement,
    required this.canSubmit,
    required this.isSubmitting,
    required this.isSubmitted,
    required this.onSubmit,
    this.visitId,
    this.onEnqueueFile,
    this.pendingFileForField,
    this.ackedDocumentIdForField,
    this.onRetryMedia,
  });

  final VisitFormRequirement requirement;
  final bool canSubmit;
  final bool isSubmitting;
  final bool isSubmitted;
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;

  /// When set with [onEnqueueFile], file fields use the durable media outbox.
  final String? visitId;
  final Future<void> Function({
    required String fieldId,
    required String filename,
    required String contentType,
    required List<int> bytes,
  })? onEnqueueFile;
  final MediaOutboxItem? Function(String fieldId)? pendingFileForField;
  final String? Function(String fieldId)? ackedDocumentIdForField;
  final Future<void> Function()? onRetryMedia;

  @override
  State<VisitSchemaForm> createState() => _VisitSchemaFormState();
}

class _VisitSchemaFormState extends State<VisitSchemaForm> {
  final _controllers = <String, TextEditingController>{};
  final _boolValues = <String, bool>{};
  final _selectedOptions = <String, String?>{};
  String? _validationError;

  List<VisitFormFieldSchema> get _fields => widget.requirement.fields;

  @override
  void initState() {
    super.initState();
    _ensureControllers();
  }

  @override
  void didUpdateWidget(covariant VisitSchemaForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requirement.formTemplateId !=
            widget.requirement.formTemplateId ||
        oldWidget.requirement.fields.length != _fields.length) {
      _disposeControllers();
      _boolValues.clear();
      _selectedOptions.clear();
      _ensureControllers();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _ensureControllers() {
    for (final field in _fields) {
      if (field.type == 'boolean') {
        _boolValues.putIfAbsent(field.id, () => false);
        continue;
      }
      if (field.options.isNotEmpty &&
          (field.type == 'text' || field.type == 'textarea')) {
        _selectedOptions.putIfAbsent(field.id, () => null);
        continue;
      }
      _controllers.putIfAbsent(field.id, TextEditingController.new);
    }
  }

  void _disposeControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
  }

  Map<String, dynamic>? _buildPayload() {
    final payload = <String, dynamic>{};
    for (final field in _fields) {
      if (field.type == 'boolean') {
        payload[field.id] = _boolValues[field.id] ?? false;
        continue;
      }
      if (field.options.isNotEmpty &&
          (field.type == 'text' || field.type == 'textarea')) {
        final selected = _selectedOptions[field.id];
        if (field.required && (selected == null || selected.isEmpty)) {
          _validationError = '${field.label} is required';
          return null;
        }
        if (selected != null && selected.isNotEmpty) {
          payload[field.id] = selected;
        }
        continue;
      }
      if (field.type == 'file') {
        final acked = widget.ackedDocumentIdForField?.call(field.id);
        final pending = widget.pendingFileForField?.call(field.id);
        final text = _controllers[field.id]?.text.trim() ?? '';
        final resolved = (acked != null && acked.isNotEmpty)
            ? acked
            : (text.isNotEmpty ? text : null);
        if (field.required &&
            resolved == null &&
            pending == null) {
          _validationError =
              '${field.label} is required — attach a file and wait for upload';
          return null;
        }
        if (pending != null && !pending.isTerminalFailure) {
          _validationError =
              '${field.label} is still uploading — wait or retry before submit';
          return null;
        }
        if (resolved != null) payload[field.id] = resolved;
        continue;
      }

      final text = _controllers[field.id]?.text.trim() ?? '';
      if (field.required && text.isEmpty) {
        _validationError = '${field.label} is required';
        return null;
      }
      if (text.isEmpty) continue;

      if (field.type == 'number') {
        final n = num.tryParse(text);
        if (n == null) {
          _validationError = '${field.label} must be a number';
          return null;
        }
        payload[field.id] = n;
      } else {
        payload[field.id] = text;
      }
    }
    _validationError = null;
    return payload;
  }

  Future<void> _submit() async {
    final payload = _buildPayload();
    if (payload == null) {
      setState(() {});
      return;
    }
    if (payload.isEmpty) {
      setState(
        () => _validationError = 'Enter at least one field before submit',
      );
      return;
    }
    setState(() => _validationError = null);
    await widget.onSubmit(payload);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.requirement.name ?? 'Form';
    final fields = _fields;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isSubmitted
                            ? 'Submitted ✓'
                            : (widget.requirement.isRequired
                                ? 'Required'
                                : 'Optional'),
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              widget.isSubmitted
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed:
                      !widget.canSubmit ||
                              widget.isSubmitting ||
                              widget.isSubmitted ||
                              fields.isEmpty
                          ? null
                          : _submit,
                  child: AsyncButtonChild(
                    isLoading: widget.isSubmitting,
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
            if (fields.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'This form has no fields in its template schema.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ] else ...[
              const SizedBox(height: 12),
              ..._buildFieldWidgets(fields),
            ],
            if (_validationError != null) ...[
              const SizedBox(height: 8),
              Text(
                _validationError!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFieldWidgets(List<VisitFormFieldSchema> fields) {
    final widgets = <Widget>[];
    String? lastSection;
    for (final field in fields) {
      if (field.section != null && field.section != lastSection) {
        lastSection = field.section;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 12, bottom: 8),
            child: Text(
              lastSection!,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        );
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _fieldInput(field),
        ),
      );
    }
    return widgets;
  }

  Widget _fieldInput(VisitFormFieldSchema field) {
    final label = field.required ? '${field.label} *' : field.label;

    if (field.type == 'boolean') {
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        value: _boolValues[field.id] ?? false,
        title: Text(label),
        controlAffinity: ListTileControlAffinity.leading,
        onChanged:
            widget.isSubmitted
                ? null
                : (v) => setState(() => _boolValues[field.id] = v ?? false),
      );
    }

    if (field.options.isNotEmpty &&
        (field.type == 'text' || field.type == 'textarea')) {
      return DropdownButtonFormField<String>(
        value: _selectedOptions[field.id],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          for (final opt in field.options)
            DropdownMenuItem(value: opt, child: Text(opt)),
        ],
        onChanged:
            widget.isSubmitted
                ? null
                : (v) => setState(() => _selectedOptions[field.id] = v),
      );
    }

    if (field.type == 'date') {
      final raw = _controllers[field.id]!.text.trim();
      final parsed = DateTime.tryParse(raw);
      final now = DateTime.now();
      return AppDateField(
        label: label,
        value: parsed,
        isDense: true,
        enabled: !widget.isSubmitted,
        firstDate: DateTime(1900),
        lastDate: DateTime(now.year + 5),
        onChanged: (picked) {
          _controllers[field.id]!.text = formatAppDate(picked);
          setState(() {});
        },
      );
    }

    final isNumber = field.type == 'number';
    final isMultiline = field.type == 'textarea';
    final isFile = field.type == 'file';

    if (isFile && widget.onEnqueueFile != null) {
      return _buildFileField(field, label);
    }

    return TextField(
      controller: _controllers[field.id],
      enabled: !widget.isSubmitted,
      maxLines: isMultiline ? 4 : 1,
      keyboardType:
          isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
      inputFormatters:
          isNumber
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))]
              : null,
      decoration: InputDecoration(
        labelText: label,
        hintText:
            isFile ? 'File name / reference (upload UI coming later)' : null,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildFileField(VisitFormFieldSchema field, String label) {
    final pending = widget.pendingFileForField?.call(field.id);
    final acked = widget.ackedDocumentIdForField?.call(field.id);
    final ctrl = _controllers[field.id];
    if (acked != null && acked.isNotEmpty && ctrl != null && ctrl.text != acked) {
      ctrl.text = acked;
    }
    final displayName = pending?.filename ??
        (acked != null
            ? 'Uploaded'
            : (ctrl?.text.isNotEmpty == true ? ctrl!.text : null));
    String? helper;
    if (pending != null) {
      if (pending.isTerminalFailure) {
        helper = pending.lastError ?? 'Upload failed';
      } else if (pending.stage == MediaOutboxStage.uploading) {
        final pct = (pending.uploadProgress * 100).round();
        helper = 'Uploading… $pct%';
      } else if (pending.stage == MediaOutboxStage.failed) {
        helper = pending.lastError ?? 'Upload pending retry';
      } else {
        helper = 'Queued for upload';
      }
    } else if (acked != null) {
      helper = 'Upload complete';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppFileField(
          label: label,
          fileName: displayName,
          enabled: !widget.isSubmitted,
          helperText: helper,
          errorText: pending?.isTerminalFailure == true
              ? (pending!.lastError ?? 'Upload failed')
              : null,
          onPick: () => _pickAndEnqueue(field),
          onClear: widget.isSubmitted
              ? null
              : () {
                  ctrl?.clear();
                  setState(() {});
                },
        ),
        if (pending != null &&
            (pending.stage == MediaOutboxStage.failed ||
                pending.isTerminalFailure) &&
            widget.onRetryMedia != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () async {
                await widget.onRetryMedia!();
                setState(() {});
              },
              child: const Text('Retry upload'),
            ),
          ),
      ],
    );
  }

  Future<void> _pickAndEnqueue(VisitFormFieldSchema field) async {
    final enqueue = widget.onEnqueueFile;
    if (enqueue == null) return;
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _validationError = 'Could not read file bytes.');
      return;
    }
    final name = file.name;
    final ext = file.extension?.toLowerCase();
    final contentType = _guessContentType(ext, name);
    await enqueue(
      fieldId: field.id,
      filename: name,
      contentType: contentType,
      bytes: bytes,
    );
    _controllers[field.id]?.text = name;
    setState(() => _validationError = null);
  }

  static String _guessContentType(String? ext, String name) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'mp4':
        return 'video/mp4';
      default:
        if (name.toLowerCase().endsWith('.pdf')) return 'application/pdf';
        return 'application/octet-stream';
    }
  }
}
