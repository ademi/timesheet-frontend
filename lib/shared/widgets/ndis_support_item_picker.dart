import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/themes/app_colors.dart';
import '../../core/errors/app_failure.dart';
import '../../features/billing/bindings/billing_binding.dart';
import '../../features/billing/data/models/billing_models.dart';
import '../../features/billing/data/ndis_catalogue_filter_prefs.dart';
import '../../features/billing/data/ndis_catalogue_local_filter.dart';
import '../../features/billing/data/repositories/ndis_catalogue_repository.dart';

/// NDIS support item number shape: `NN_NNN_NNNN_N_N`.
final RegExp ndisSupportItemCodePattern = RegExp(r'^\d{2}_\d{3}_\d{4}_\d_\d$');

bool isValidNdisSupportItemCode(String code) =>
    ndisSupportItemCodePattern.hasMatch(code.trim());

typedef NdisSupportItemChanged = void Function({
  required String? supportItemCode,
  required String? supportItemName,
});

String ndisCatalogueFacetLabel(NdisCatalogueFacet facet) {
  final name = facet.name?.trim();
  if (name == null || name.isEmpty) return facet.number;
  return '${facet.number} · $name';
}

Key ndisCategoryChipKey(String number) => ValueKey('ndis-category-$number');

const Key ndisCategoryKey = ValueKey('ndis-category');
const Key ndisRegistrationGroupKey = ValueKey('ndis-reg-group');

/// Catalogue typeahead with frontend-only category / registration / text filters.
///
/// Loads the active catalogue once via [NdisCatalogueRepository.fetchAllActiveItems]
/// (D20). Facet chips, registration-group cascade, and the debounced text box
/// filter the session cache in memory — no per-keystroke [NdisCatalogueRepository.searchItems].
class NdisSupportItemPicker extends StatefulWidget {
  const NdisSupportItemPicker({
    super.key,
    this.supportItemCode,
    this.supportItemName,
    required this.onChanged,
    this.enabled = true,
    this.repository,
    this.filterPrefs,
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
  final NdisCatalogueFilterPrefs? filterPrefs;
  final Duration debounceDuration;

  /// Unused by the local-filter path; kept so existing call sites compile.
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
  List<NdisCatalogueItemOut> _allItems = const [];
  List<NdisCatalogueItemOut> _options = const [];
  bool _loading = true;
  bool _fetchStarted = false;
  bool _catalogueLoaded = false;
  String? _loadError;
  String? _formatError;
  String? _categoryNumber;
  String? _registrationGroupNumber;

  late final NdisCatalogueFilterPrefs _filterPrefs =
      widget.filterPrefs ?? NdisCatalogueFilterPrefs();

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

  List<NdisCatalogueFacet> get _categoryFacets =>
      NdisCatalogueLocalFilter.facets(_allItems).supportCategories;

  List<NdisCatalogueFacet> get _regGroupFacets =>
      NdisCatalogueLocalFilter.registrationGroupsFor(
        NdisCatalogueLocalFilter.apply(
          _allItems,
          categoryNumber: _categoryNumber,
        ),
      );

  @override
  void initState() {
    super.initState();
    final saved = _filterPrefs.load();
    _categoryNumber = saved.categoryNumber;
    _registrationGroupNumber = saved.registrationGroupNumber;
    _syncQueryFromSelection();
    _focusNode.addListener(_onFocusChange);
    _loadCatalogue();
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
      _loadCatalogue();
      return;
    }
    // Web: pointer-down on a result blurs the field before onTap. Delay
    // format validation so onTapDown / onTap can still select the row.
    _blurClearTimer?.cancel();
    _blurClearTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || _focusNode.hasFocus || _applyingSelection) return;
      _validateTypedCode();
    });
  }

  Future<void> _loadCatalogue() async {
    if (_fetchStarted) return;
    _fetchStarted = true;
    _loading = true;
    try {
      final items = await _repository.fetchAllActiveItems();
      if (!mounted) return;
      setState(() {
        _allItems = List<NdisCatalogueItemOut>.of(items);
        _catalogueLoaded = true;
        _loadError = null;
        _loading = false;
        _recomputeOptions();
      });
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _catalogueLoaded = false;
        _loadError = e.message;
        _options = const [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _catalogueLoaded = false;
        _loadError = 'Could not load the catalogue.';
        _options = const [];
      });
    }
  }

  void _recomputeOptions() {
    _options = NdisCatalogueLocalFilter.apply(
      _allItems,
      categoryNumber: _categoryNumber,
      registrationGroupNumber: _registrationGroupNumber,
      query: _queryCtrl.text,
    );
  }

  void _clearRegIfInvalid() {
    final selected = _registrationGroupNumber;
    if (selected == null || selected.isEmpty) return;
    final valid = _regGroupFacets.map((g) => g.number).toSet();
    if (!valid.contains(selected)) {
      _registrationGroupNumber = null;
    }
  }

  void _persistFilters() {
    _filterPrefs.save(
      categoryNumber: _categoryNumber,
      registrationGroupNumber: _registrationGroupNumber,
    );
  }

  void _onCategorySelected(String? number) {
    setState(() {
      _categoryNumber = number;
      _clearRegIfInvalid();
      _recomputeOptions();
    });
    _persistFilters();
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
      _formatError = null;
      _loading = false;
      _recomputeOptions();
    });
    widget.onChanged(supportItemCode: null, supportItemName: null);
  }

  void _select(NdisCatalogueItemOut item) {
    _debounce?.cancel();
    _blurClearTimer?.cancel();
    _applyingSelection = true;
    setState(() {
      _options = const [];
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
    setState(() => _formatError = null);

    _debounce = Timer(widget.debounceDuration, () {
      if (!mounted) return;
      setState(_recomputeOptions);
    });
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

    final showOptions = _catalogueLoaded && _options.isNotEmpty;
    final query = _queryCtrl.text.trim();

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
            suffixIcon: (query.isNotEmpty && widget.enabled)
                ? IconButton(
                    tooltip: 'Clear',
                    onPressed: _clear,
                    icon: const Icon(Icons.clear),
                  )
                : _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
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
        ] else if (_loadError != null) ...[
          const SizedBox(height: 6),
          Text(
            _loadError!,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
        if (_catalogueLoaded) ...[
          const SizedBox(height: 6),
          Text(
            'Filtered locally (${_options.length} of ${_allItems.length})',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
        if (_categoryFacets.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ndisCategoryKey,
            isExpanded: true,
            value: _categoryNumber ?? '',
            decoration: const InputDecoration(
              labelText: 'Support category',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('All categories'),
              ),
              for (final facet in _categoryFacets)
                DropdownMenuItem<String>(
                  value: facet.number,
                  child: Text(
                    ndisCatalogueFacetLabel(facet),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: widget.enabled
                ? (value) => _onCategorySelected(
                      (value == null || value.isEmpty) ? null : value,
                    )
                : null,
          ),
        ],
        if (_catalogueLoaded) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ndisRegistrationGroupKey,
            isExpanded: true,
            value: _registrationGroupNumber ?? '',
            decoration: const InputDecoration(
              labelText: 'Registration group',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('All groups'),
              ),
              for (final group in _regGroupFacets)
                DropdownMenuItem<String>(
                  value: group.number,
                  child: Text(
                    ndisCatalogueFacetLabel(group),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: widget.enabled
                ? (value) {
                    setState(() {
                      _registrationGroupNumber =
                          (value == null || value.isEmpty) ? null : value;
                      _recomputeOptions();
                    });
                    _persistFilters();
                  }
                : null,
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
