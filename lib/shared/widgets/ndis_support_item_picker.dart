import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/themes/app_colors.dart';
import '../../core/errors/app_failure.dart';
import '../../features/billing/bindings/billing_binding.dart';
import '../../features/billing/data/models/billing_models.dart';
import '../../features/billing/data/repositories/ndis_catalogue_repository.dart';

/// NDIS support item number shape: `NN_NNN_NNNN_N_N`.
final RegExp ndisSupportItemCodePattern = RegExp(r'^\d{2}_\d{3}_\d{4}_\d_\d$');

bool isValidNdisSupportItemCode(String code) =>
    ndisSupportItemCodePattern.hasMatch(code.trim());

typedef NdisSupportItemChanged = void Function({
  required String? supportItemCode,
  required String? supportItemName,
});

/// Debounced catalogue typeahead for NDIS support items.
///
/// Picking a row stores [NdisCatalogueItemOut.supportItemNumber] as the code and
/// the canonical [supportItemName]. Clear sends both null.
class NdisSupportItemPicker extends StatefulWidget {
  const NdisSupportItemPicker({
    super.key,
    this.supportItemCode,
    this.supportItemName,
    required this.onChanged,
    this.enabled = true,
    this.repository,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.searchLimit = 20,
    this.labelText = 'NDIS support item',
    this.searchHintText = 'Search catalogue by name or item number',
  });

  final String? supportItemCode;
  final String? supportItemName;
  final NdisSupportItemChanged onChanged;
  final bool enabled;
  final NdisCatalogueRepository? repository;
  final Duration debounceDuration;
  final int searchLimit;
  final String labelText;
  final String searchHintText;

  @override
  State<NdisSupportItemPicker> createState() => _NdisSupportItemPickerState();
}

class _NdisSupportItemPickerState extends State<NdisSupportItemPicker> {
  final _queryCtrl = TextEditingController();
  final _focusNode = FocusNode();

  Timer? _debounce;
  Timer? _blurClearTimer;
  List<NdisCatalogueItemOut> _options = const [];
  bool _loading = false;
  String? _searchError;
  String? _formatError;
  int _searchGeneration = 0;

  /// True while applying a catalogue pick so blur/query side-effects are ignored.
  bool _applyingSelection = false;

  bool get _hasSelection {
    final code = widget.supportItemCode?.trim();
    final name = widget.supportItemName?.trim();
    return code != null &&
        code.isNotEmpty &&
        name != null &&
        name.isNotEmpty;
  }

  NdisCatalogueRepository get _repository {
    if (widget.repository != null) return widget.repository!;
    BillingBinding.ensureShared();
    return Get.find<NdisCatalogueRepository>();
  }

  @override
  void initState() {
    super.initState();
    _syncQueryFromSelection();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant NdisSupportItemPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.supportItemCode != widget.supportItemCode ||
        oldWidget.supportItemName != widget.supportItemName) {
      _syncQueryFromSelection();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _blurClearTimer?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _queryCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _syncQueryFromSelection() {
    if (_hasSelection) {
      _queryCtrl.value = TextEditingValue(
        text: widget.supportItemName!.trim(),
        selection: TextSelection.collapsed(
          offset: widget.supportItemName!.trim().length,
        ),
      );
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _blurClearTimer?.cancel();
      return;
    }
    // Web: pointer-down on a result blurs the field before onTap. Delay clearing
    // options so onTapDown / onTap can still select the row.
    _blurClearTimer?.cancel();
    _blurClearTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || _focusNode.hasFocus || _applyingSelection) return;
      setState(() => _options = const []);
      _validateTypedCode();
    });
  }

  void _validateTypedCode() {
    if (_hasSelection || !widget.enabled || _applyingSelection) {
      setState(() => _formatError = null);
      return;
    }
    final query = _queryCtrl.text.trim();
    if (query.isEmpty) {
      setState(() => _formatError = null);
      return;
    }
    // Name-like leftover text (e.g. after a pick that didn't stick) — same guidance
    // as a typed item number that still needs a catalogue row.
    if (isValidNdisSupportItemCode(query) ||
        query.contains(' ') ||
        !RegExp(r'^[\d_]+$').hasMatch(query)) {
      setState(
        () => _formatError = 'Pick a catalogue row so the name matches.',
      );
      return;
    }
    setState(
      () => _formatError = 'Invalid NDIS item number format.',
    );
  }

  void _clear() {
    _debounce?.cancel();
    _blurClearTimer?.cancel();
    _queryCtrl.clear();
    setState(() {
      _options = const [];
      _searchError = null;
      _formatError = null;
      _loading = false;
    });
    widget.onChanged(supportItemCode: null, supportItemName: null);
  }

  void _select(NdisCatalogueItemOut item) {
    _debounce?.cancel();
    _blurClearTimer?.cancel();
    _applyingSelection = true;
    setState(() {
      _options = const [];
      _searchError = null;
      _formatError = null;
      _loading = false;
      _queryCtrl.value = TextEditingValue(
        text: item.supportItemName,
        selection: TextSelection.collapsed(
          offset: item.supportItemName.length,
        ),
      );
    });
    widget.onChanged(
      supportItemCode: item.supportItemNumber,
      supportItemName: item.supportItemName,
    );
    _focusNode.unfocus();
    // Parent Obx may rebuild after the PATCH; allow blur handlers again next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyingSelection = false;
    });
  }

  void _onQueryChanged(String value) {
    if (_applyingSelection) return;
    if (_hasSelection) {
      widget.onChanged(supportItemCode: null, supportItemName: null);
    }
    _debounce?.cancel();
    setState(() {
      _searchError = null;
      _formatError = null;
    });

    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _options = const [];
        _loading = false;
      });
      return;
    }

    _debounce = Timer(widget.debounceDuration, () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final generation = ++_searchGeneration;
    setState(() {
      _loading = true;
      _searchError = null;
    });
    try {
      final response = await _repository.searchItems(
        q: query,
        limit: widget.searchLimit,
      );
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _options = response.items;
        _loading = false;
      });
    } on AppFailure catch (e) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _options = const [];
        _loading = false;
        _searchError = e.message;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _options = const [];
        _loading = false;
        _searchError = 'Could not search the catalogue.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasSelection) {
      return _SelectedTile(
        labelText: widget.labelText,
        code: widget.supportItemCode!.trim(),
        name: widget.supportItemName!.trim(),
        enabled: widget.enabled,
        onClear: _clear,
      );
    }

    // Keep results visible briefly after blur so web taps can land (see _onFocusChange).
    final showOptions = _options.isNotEmpty &&
        (_focusNode.hasFocus || _blurClearTimer?.isActive == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _queryCtrl,
          focusNode: _focusNode,
          enabled: widget.enabled,
          onChanged: _onQueryChanged,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.searchHintText,
            border: const OutlineInputBorder(),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_queryCtrl.text.trim().isNotEmpty && widget.enabled)
                    ? IconButton(
                        tooltip: 'Clear',
                        onPressed: _clear,
                        icon: const Icon(Icons.clear),
                      )
                    : null,
          ),
        ),
        if (_formatError != null) ...[
          const SizedBox(height: 6),
          Text(
            _formatError!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ] else if (_searchError != null) ...[
          const SizedBox(height: 6),
          Text(
            _searchError!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
        if (showOptions)
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _options.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _options[index];
                  return Listener(
                    behavior: HitTestBehavior.opaque,
                    // Pointer down fires before TextField blur removes the list on web.
                    onPointerDown: widget.enabled
                        ? (_) => _select(item)
                        : null,
                    child: ListTile(
                      dense: true,
                      title: Text(item.supportItemName),
                      subtitle: Text(item.supportItemNumber),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectedTile extends StatelessWidget {
  const _SelectedTile({
    required this.labelText,
    required this.code,
    required this.name,
    required this.enabled,
    required this.onClear,
  });

  final String labelText;
  final String code;
  final String name;
  final bool enabled;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        suffixIcon: enabled
            ? IconButton(
                tooltip: 'Clear support item',
                onPressed: onClear,
                icon: const Icon(Icons.clear),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name),
          const SizedBox(height: 4),
          Text(
            code,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
