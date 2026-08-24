import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../../shifts/widgets/shift_slot_pips.dart';
import 'roster_grid_model.dart';

const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String formatRosterDayHeader(DateTime day) {
  final local = DateTime(day.year, day.month, day.day);
  return '${_wd[local.weekday - 1]} ${local.day}';
}

String formatRosterTileTime(DateTime start) {
  final l = start.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.hour)}:${two(l.minute)}';
}

String? visitStatusChipLabel(String? visitStatus) {
  switch (visitStatus) {
    case 'scheduled':
      return 'Live';
    case 'checked_in':
      return 'In';
    case 'completed':
      return 'Done';
    default:
      return null;
  }
}

/// People-by-day roster board (staff laptop/web — D17).
///
/// Each person is one horizontal [Row] (sticky name + day cells) so name and
/// day columns share a single row height when cells have multiple tiles.
class RosterGridView extends StatefulWidget {
  const RosterGridView({
    super.key,
    required this.grid,
    required this.onTileTap,
    this.onTileLongPress,
  });

  final RosterGrid grid;
  final ValueChanged<RosterTile> onTileTap;
  final ValueChanged<RosterTile>? onTileLongPress;

  static const double nameColWidth = 140;
  static const double dayColWidth = 150;

  @override
  State<RosterGridView> createState() => _RosterGridViewState();
}

class _RosterGridViewState extends State<RosterGridView> {
  late ScrollController _headerHScroll;
  late List<ScrollController> _rowHScrolls;
  bool _syncingH = false;

  @override
  void initState() {
    super.initState();
    _headerHScroll = ScrollController();
    _headerHScroll.addListener(() => _syncFrom(_headerHScroll));
    _rowHScrolls = _controllersForRowCount(widget.grid.rows.length);
  }

  @override
  void didUpdateWidget(covariant RosterGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.grid.rows.length != widget.grid.rows.length) {
      _disposeRowControllers();
      _rowHScrolls = _controllersForRowCount(widget.grid.rows.length);
    }
  }

  List<ScrollController> _controllersForRowCount(int count) {
    return List.generate(count, (_) {
      final c = ScrollController();
      c.addListener(() => _syncFrom(c));
      return c;
    });
  }

  void _syncFrom(ScrollController source) {
    if (_syncingH || !source.hasClients) return;
    _syncingH = true;
    final offset = source.offset;
    void jump(ScrollController c) {
      if (c != source && c.hasClients && c.offset != offset) {
        c.jumpTo(offset);
      }
    }

    jump(_headerHScroll);
    for (final c in _rowHScrolls) {
      jump(c);
    }
    _syncingH = false;
  }

  void _disposeRowControllers() {
    for (final c in _rowHScrolls) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _headerHScroll.dispose();
    _disposeRowControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grid = widget.grid;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _RosterHeaderDelegate(
            header: _RosterHeaderRow(
              grid: grid,
              headerHScroll: _headerHScroll,
            ),
          ),
        ),
        SliverList.builder(
          itemCount: grid.rows.length,
          itemBuilder: (context, index) {
            return _RosterBodyRow(
              row: grid.rows[index],
              hScroll: _rowHScrolls[index],
              onTileTap: widget.onTileTap,
              onTileLongPress: widget.onTileLongPress,
            );
          },
        ),
      ],
    );
  }
}

class _RosterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _RosterHeaderDelegate({required this.header});

  final Widget header;

  @override
  double get minExtent => 36;

  @override
  double get maxExtent => 36;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: AppColors.background,
      child: header,
    );
  }

  @override
  bool shouldRebuild(covariant _RosterHeaderDelegate oldDelegate) {
    return oldDelegate.header != header;
  }
}

class _RosterHeaderRow extends StatelessWidget {
  const _RosterHeaderRow({
    required this.grid,
    required this.headerHScroll,
  });

  final RosterGrid grid;
  final ScrollController headerHScroll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _HeaderCell(
          label: '',
          width: RosterGridView.nameColWidth,
          sticky: true,
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: headerHScroll,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final day in grid.dayStarts)
                  _HeaderCell(
                    label: formatRosterDayHeader(day),
                    width: RosterGridView.dayColWidth,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RosterBodyRow extends StatelessWidget {
  const _RosterBodyRow({
    required this.row,
    required this.hScroll,
    required this.onTileTap,
    this.onTileLongPress,
  });

  final RosterRow row;
  final ScrollController hScroll;
  final ValueChanged<RosterTile> onTileTap;
  final ValueChanged<RosterTile>? onTileLongPress;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NameCell(
            key: ValueKey('roster-name-${row.id}'),
            label: row.label,
            isUnfilled: row.isUnfilled,
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: hScroll,
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final cell in row.cells)
                    _DayCell(
                      cell: cell,
                      isUnfilledRow: row.isUnfilled,
                      onTileTap: onTileTap,
                      onTileLongPress: onTileLongPress,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    required this.width,
    this.sticky = false,
  });

  final String label;
  final double width;
  final bool sticky;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 36,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: sticky ? AppColors.background : AppColors.surface,
        border: const Border(
          bottom: BorderSide(color: AppColors.divider),
          right: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: AppColors.slate700,
        ),
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({
    super.key,
    required this.label,
    required this.isUnfilled,
  });

  final String label;
  final bool isUnfilled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: RosterGridView.nameColWidth,
      constraints: const BoxConstraints(minHeight: 72),
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
          right: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isUnfilled ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13,
          color: isUnfilled ? AppColors.openSlot : AppColors.textDark,
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.cell,
    required this.isUnfilledRow,
    required this.onTileTap,
    this.onTileLongPress,
  });

  final RosterCell cell;
  final bool isUnfilledRow;
  final ValueChanged<RosterTile> onTileTap;
  final ValueChanged<RosterTile>? onTileLongPress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: RosterGridView.dayColWidth,
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cell.onLeave ? AppColors.slate100 : AppColors.surface,
        border: const Border(
          bottom: BorderSide(color: AppColors.divider),
          right: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cell.onLeave)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'Leave',
                style: TextStyle(fontSize: 10, color: AppColors.slate500),
              ),
            )
          else if (cell.availabilityHint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                cell.availabilityHint!,
                style: const TextStyle(fontSize: 10, color: AppColors.slate500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          for (final tile in cell.tiles)
            _ShiftTile(
              tile: tile,
              emphasizeOpen: isUnfilledRow || tile.openSlots > 0,
              onTap: () => onTileTap(tile),
              onLongPress:
                  onTileLongPress == null
                      ? null
                      : () => onTileLongPress!(tile),
            ),
        ],
      ),
    );
  }
}

class _ShiftTile extends StatelessWidget {
  const _ShiftTile({
    required this.tile,
    required this.emphasizeOpen,
    required this.onTap,
    this.onLongPress,
  });

  final RosterTile tile;
  final bool emphasizeOpen;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final chip = visitStatusChipLabel(tile.visitStatus);
    final filled = tile.requiredSlots - tile.openSlots;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: emphasizeOpen && tile.openSlots > 0
            ? AppColors.openSlotBackground
            : AppColors.background,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tile.clientName.isEmpty ? '—' : tile.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatRosterTileTime(tile.start),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                ShiftSlotPips(
                  requiredSlots: tile.requiredSlots,
                  filledSlots: filled < 0 ? 0 : filled,
                ),
                if (chip != null) ...[
                  const SizedBox(height: 4),
                  _ShiftStatusChip(label: chip),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShiftStatusChip extends StatelessWidget {
  const _ShiftStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.slate200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.slate700,
        ),
      ),
    );
  }
}
