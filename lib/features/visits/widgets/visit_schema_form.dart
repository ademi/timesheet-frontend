import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
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
  });

  final VisitFormRequirement requirement;
  final bool canSubmit;
  final bool isSubmitting;
  final bool isSubmitted;
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;

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
        final text = _controllers[field.id]?.text.trim() ?? '';
        if (field.required && text.isEmpty) {
          _validationError =
              '${field.label} is required (enter a file name / reference)';
          return null;
        }
        if (text.isNotEmpty) payload[field.id] = text;
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
      setState(() => _validationError = 'Enter at least one field before submit');
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
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        widget.isSubmitted
                            ? 'Submitted ✓'
                            : (widget.requirement.isRequired
                                ? 'Required'
                                : 'Optional'),
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isSubmitted
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: !widget.canSubmit ||
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
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
        onChanged: widget.isSubmitted
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
        onChanged: widget.isSubmitted
            ? null
            : (v) => setState(() => _selectedOptions[field.id] = v),
      );
    }

    if (field.type == 'date') {
      return TextFormField(
        controller: _controllers[field.id],
        readOnly: true,
        enabled: !widget.isSubmitted,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        onTap: widget.isSubmitted
            ? null
            : () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(now.year + 5),
                );
                if (picked != null) {
                  final y = picked.year.toString().padLeft(4, '0');
                  final m = picked.month.toString().padLeft(2, '0');
                  final d = picked.day.toString().padLeft(2, '0');
                  _controllers[field.id]!.text = '$y-$m-$d';
                  setState(() {});
                }
              },
      );
    }

    final isNumber = field.type == 'number';
    final isMultiline = field.type == 'textarea';
    final isFile = field.type == 'file';

    return TextField(
      controller: _controllers[field.id],
      enabled: !widget.isSubmitted,
      maxLines: isMultiline ? 4 : 1,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: isFile
            ? 'File name / reference (upload UI coming later)'
            : null,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
