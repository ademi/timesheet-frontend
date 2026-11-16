import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../controllers/tutorials_controller.dart';

/// Circular teal tutorials FAB (ShiftCare-style pattern, Rostiq brand).
class TutorialsFab extends StatelessWidget {
  const TutorialsFab({super.key, required this.controller});

  final TutorialsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final open = controller.isOpen.value;
      return Tooltip(
        message: open ? 'Close tutorials' : 'Tutorials',
        child: Material(
          color: AppColors.brand,
          shape: const CircleBorder(),
          elevation: 6,
          shadowColor: Colors.black38,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: controller.toggle,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(
                open ? Icons.keyboard_arrow_down_rounded : Icons.school_rounded,
                color: AppColors.onPrimary,
                size: 28,
              ),
            ),
          ),
        ),
      );
    });
  }
}
