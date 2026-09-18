import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/themes/app_colors.dart';

/// Rostiq wordmark (R + analog clock) from the SVG asset.
///
/// The source SVG is monochrome black. [color] is applied with
/// [BlendMode.srcIn] so every opaque pixel becomes that tint — sharp at any
/// size, no colored PNG variants needed.
class RostiqLogo extends StatelessWidget {
  const RostiqLogo({
    super.key,
    this.height = 56,
    this.color = AppColors.brand,
    this.semanticsLabel = 'Rostiq',
  });

  /// Teal brand chrome (default). Use [AppColors.cta] for coral.
  static const Color brand = AppColors.brand;
  static const Color cta = AppColors.cta;

  final double height;
  final Color color;
  final String semanticsLabel;

  static const assetPath = 'assets/images/logo.svg';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      height: height,
      fit: BoxFit.contain,
      semanticsLabel: semanticsLabel,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      placeholderBuilder:
          (_) => Icon(Icons.schedule_rounded, size: height, color: color),
    );
  }
}
