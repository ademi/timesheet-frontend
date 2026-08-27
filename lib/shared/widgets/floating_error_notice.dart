import 'package:flutter/material.dart';

import '../../app/themes/app_colors.dart';

/// Persistent form error, placed between the scrolling body and sticky footer.
///
/// [SemanticsRole.alert] is omitted because Flutter forbids combining it with
/// liveRegion; this widget uses liveRegion only.
class FloatingErrorNotice extends StatefulWidget {
  const FloatingErrorNotice({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  static const animationDuration = Duration(milliseconds: 200);

  @override
  State<FloatingErrorNotice> createState() => _FloatingErrorNoticeState();
}

class _FloatingErrorNoticeState extends State<FloatingErrorNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _dismissPending = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: FloatingErrorNotice.animationDuration,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    if (_dismissPending) return;
    _dismissPending = true;
    await _controller.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizeTransition(
        sizeFactor: _animation,
        axisAlignment: -1,
        child: FadeTransition(
          opacity: _animation,
          child: Semantics(
            liveRegion: true,
            container: true,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.errorBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          widget.message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      onPressed: _handleDismiss,
                      icon: const Icon(Icons.close, color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
