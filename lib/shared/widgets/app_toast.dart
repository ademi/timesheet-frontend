import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/themes/app_colors.dart';

/// Consistent snackbar wrapper — use instead of raw [Get.snackbar].
class AppToast {
  AppToast._();

  static const _margin = EdgeInsets.all(16);
  static const _borderRadius = 12.0;
  static const _duration = Duration(seconds: 4);

  static void error(String title, String message, {Duration? duration}) {
    Get.snackbar(
      title,
      message,
      backgroundColor: AppColors.error,
      colorText: AppColors.textLight,
      snackPosition: SnackPosition.BOTTOM,
      margin: _margin,
      borderRadius: _borderRadius,
      duration: duration ?? _duration,
      icon: const Icon(Icons.error_rounded, color: AppColors.textLight),
    );
  }

  static void success(String title, String message, {Duration? duration}) {
    Get.snackbar(
      title,
      message,
      backgroundColor: AppColors.primary,
      colorText: AppColors.onPrimary,
      snackPosition: SnackPosition.BOTTOM,
      margin: _margin,
      borderRadius: _borderRadius,
      duration: duration ?? _duration,
    );
  }

  static void info(String title, String message, {Duration? duration}) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: _margin,
      borderRadius: _borderRadius,
      duration: duration ?? _duration,
    );
  }
}
