import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../data/platform_info_repository.dart';

/// Shows the backend residency label only when claimable (FE-0.5 / BE-1.3).
class DataResidencyFootnote extends StatefulWidget {
  const DataResidencyFootnote({super.key});

  @override
  State<DataResidencyFootnote> createState() => _DataResidencyFootnoteState();
}

class _DataResidencyFootnoteState extends State<DataResidencyFootnote> {
  String? _line;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await PlatformInfoRepository.ensureRegistered().load();
    if (!mounted) return;
    setState(() => _line = info.residencyLine);
  }

  @override
  Widget build(BuildContext context) {
    final line = _line;
    if (line == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.public_outlined,
            size: 16,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
