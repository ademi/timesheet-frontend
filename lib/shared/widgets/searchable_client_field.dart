import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/themes/app_colors.dart';
import '../../features/clients/data/models/client_models.dart';
import '../models/profile_photo_models.dart';
import '../utils/client_search.dart';
import 'profile_photo_editor.dart';

/// In-page type-to-search client field (not Overlay autocomplete).
///
/// Empty query shows browse/recents; typing ranks matches. Results live in a
/// max-height scroll region so parent scroll views stay usable.
class SearchableClientField extends StatefulWidget {
  const SearchableClientField({
    super.key,
    required this.candidates,
    required this.onSelected,
    this.excludeIds = const {},
    this.recentIds = const [],
    this.photosByClient = const {},
    this.query,
    this.onQueryChanged,
    this.labelText = 'Search clients',
    this.hintText = 'Name, email, or phone',
    this.enabled = true,
    this.loading = false,
    this.autofocus = false,
    this.resultLimit = 20,
    this.browseLimit = 8,
    this.maxResultsHeight = 260,
    this.allowClearSelection = false,
    this.clearSelectionLabel = 'All clients',
    this.onClearSelection,
    this.showPhotos = true,
    this.focusNode,
    this.selectedId,
    this.selectedLabel,
    this.compactSelected = false,
  });

  final List<ClientSearchCandidate> candidates;
  final Future<void> Function(ClientSearchCandidate client) onSelected;
  final Set<String> excludeIds;
  final List<String> recentIds;
  final Map<String, ProfilePhotoOut> photosByClient;
  final String? query;
  final ValueChanged<String>? onQueryChanged;
  final String labelText;
  final String hintText;
  final bool enabled;
  final bool loading;
  final bool autofocus;
  final int resultLimit;
  final int browseLimit;
  final double maxResultsHeight;
  final bool allowClearSelection;
  final String clearSelectionLabel;
  final VoidCallback? onClearSelection;
  final bool showPhotos;
  final FocusNode? focusNode;
  /// When set with [compactSelected], shows a selected tile until change/clear.
  final String? selectedId;
  final String? selectedLabel;
  final bool compactSelected;

  /// Convenience when the source list is [ClientOut].
  static List<ClientSearchCandidate> candidatesFromClients(
    Iterable<ClientOut> clients,
  ) => [for (final c in clients) ClientSearchCandidate.fromClient(c)];

  @override
  State<SearchableClientField> createState() => _SearchableClientFieldState();
}

class _SearchableClientFieldState extends State<SearchableClientField> {
  late final TextEditingController _text;
  late final FocusNode _focus;
  var _ownsFocus = false;
  var _focused = false;
  var _editingSelection = false;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.query ?? '');
    if (widget.focusNode != null) {
      _focus = widget.focusNode!;
    } else {
      _focus = FocusNode();
      _ownsFocus = true;
    }
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant SearchableClientField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final q = widget.query;
    if (q != null && q != _text.text) {
      _text.value = TextEditingValue(
        text: q,
        selection: TextSelection.collapsed(offset: q.length),
      );
    }
    if (widget.selectedId != oldWidget.selectedId &&
        widget.selectedId != null) {
      _editingSelection = false;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    if (_ownsFocus) _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() => _focused = _focus.hasFocus);
  }

  void _setQuery(String value) {
    widget.onQueryChanged?.call(value);
    setState(() {});
  }

  Future<void> _selectTopOrFocused() async {
    final rows = _visibleRows();
    if (rows.isEmpty) return;
    await widget.onSelected(rows.first);
    _text.clear();
    _setQuery('');
  }

  List<ClientSearchCandidate> _visibleRows() {
    final q = _text.text.trim();
    if (q.isEmpty) {
      return browseClients(
        candidates: widget.candidates,
        recentIds: widget.recentIds,
        limit: widget.browseLimit,
        excludeIds: widget.excludeIds,
      );
    }
    return searchClients(
      candidates: widget.candidates,
      query: q,
      limit: widget.resultLimit,
      excludeIds: widget.excludeIds,
    ).items;
  }

  ClientSearchResult? _searchMeta() {
    final q = _text.text.trim();
    if (q.isEmpty) return null;
    return searchClients(
      candidates: widget.candidates,
      query: q,
      limit: widget.resultLimit,
      excludeIds: widget.excludeIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCompactSelection =
        widget.compactSelected &&
        widget.selectedId != null &&
        widget.selectedId!.isNotEmpty &&
        !_editingSelection;

    if (hasCompactSelection) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: widget.labelText,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.selectedLabel ?? widget.selectedId!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (widget.enabled) ...[
              TextButton(
                onPressed: () => setState(() => _editingSelection = true),
                child: const Text('Change'),
              ),
              if (widget.allowClearSelection && widget.onClearSelection != null)
                IconButton(
                  tooltip: widget.clearSelectionLabel,
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: widget.onClearSelection,
                ),
            ],
          ],
        ),
      );
    }

    final q = _text.text.trim();
    final searching = q.isNotEmpty;
    final meta = _searchMeta();
    final rows =
        searching
            ? (meta?.items ?? const <ClientSearchCandidate>[])
            : browseClients(
              candidates: widget.candidates,
              recentIds: widget.recentIds,
              limit: widget.browseLimit,
              excludeIds: widget.excludeIds,
            );
    final showBrowse =
        !searching && (_focused || rows.isNotEmpty || widget.loading);
    final hasRecents =
        !searching &&
        widget.recentIds.any(
          (id) =>
              widget.candidates.any((c) => c.id == id) &&
              !widget.excludeIds.contains(id),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.enter): _selectTopOrFocused,
          },
          child: TextField(
            controller: _text,
            focusNode: _focus,
            enabled: widget.enabled && !widget.loading,
            autofocus: widget.autofocus || _editingSelection,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _selectTopOrFocused(),
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              border: const OutlineInputBorder(),
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon:
                  widget.loading
                      ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                      : q.isEmpty
                      ? null
                      : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _text.clear();
                          _setQuery('');
                        },
                      ),
            ),
            onChanged: _setQuery,
          ),
        ),
        if (widget.allowClearSelection && widget.onClearSelection != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed:
                  widget.enabled
                      ? () {
                        _text.clear();
                        _setQuery('');
                        setState(() => _editingSelection = false);
                        widget.onClearSelection!();
                      }
                      : null,
              child: Text(widget.clearSelectionLabel),
            ),
          ),
        ],
        if (_editingSelection &&
            widget.compactSelected &&
            widget.selectedId != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _editingSelection = false),
              child: const Text('Cancel'),
            ),
          ),
        const SizedBox(height: 8),
        if (widget.loading && widget.candidates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Loading clients…',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          )
        else if (!widget.loading && widget.candidates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No clients in this directory yet.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          )
        else if (searching && rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No clients match “$q”.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          )
        else if (showBrowse || searching) ...[
          Text(
            searching
                ? (meta != null && meta.isTruncated
                    ? 'Showing ${rows.length} of ${meta.totalMatches} — type more to narrow'
                    : '${rows.length} match${rows.length == 1 ? '' : 'es'}')
                : (hasRecents ? 'Recent & browse' : 'Browse clients'),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxResultsHeight),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final client = rows[index];
                return _ClientResultRow(
                  key: ValueKey(client.id),
                  client: client,
                  query: q,
                  photo:
                      widget.showPhotos
                          ? widget.photosByClient[client.id]
                          : null,
                  showPhoto: widget.showPhotos,
                  onTap: () async {
                    await widget.onSelected(client);
                    if (!mounted) return;
                    _text.clear();
                    _setQuery('');
                    setState(() => _editingSelection = false);
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _ClientResultRow extends StatelessWidget {
  const _ClientResultRow({
    super.key,
    required this.client,
    required this.query,
    required this.onTap,
    this.photo,
    this.showPhoto = true,
  });

  final ClientSearchCandidate client;
  final String query;
  final ProfilePhotoOut? photo;
  final bool showPhoto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = const TextStyle(
      fontWeight: FontWeight.w600,
      color: AppColors.textDark,
    );
    final highlight = base.copyWith(
      color: AppColors.brand,
      backgroundColor: AppColors.brandSoft,
    );
    final subtitle = clientSearchSubtitle(client);

    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              if (showPhoto) ...[
                ProfilePhotoEditor(
                  networkUrl: photo?.downloadUrl,
                  documentId: photo?.documentId,
                  readOnly: true,
                  size: 40,
                  showLabel: false,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      highlightQuerySpan(
                        text: client.fullName,
                        query: query,
                        base: base,
                        highlight: highlight,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline, color: AppColors.brand),
            ],
          ),
        ),
      ),
    );
  }
}
