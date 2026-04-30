import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/gateway_controller.dart';
import '../themes/app_colors.dart';

class GatewayView extends GetView<GatewayController> {
  const GatewayView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 24),

                // ── Logo ─────────────────────────────────
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 18,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder:
                          (_, __, ___) => const Center(
                            child: Icon(
                              Icons.restaurant,
                              size: 60,
                              color: AppColors.primary,
                            ),
                          ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Title ────────────────────────────────
                const Text(
                  'مطعم باب اليمن',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBrown,
                    fontFamily: 'Cairo',
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select Your Portal',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primaryDark,
                    letterSpacing: 1.0,
                  ),
                ),

                const SizedBox(height: 40),

                // ── Role Cards ───────────────────────────
                _RoleCard(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Admin Panel',
                  subtitle: 'Manage employees & reports',
                  onTap: () => controller.selectRole(UserRole.admin),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.fingerprint_rounded,
                  title: 'Attendance',
                  subtitle: 'Clock in & clock out',
                  onTap: () => controller.selectRole(UserRole.attendance),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Role Selection Card ────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(22),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: AppColors.primary.withValues(alpha: 0.12),
        highlightColor: AppColors.primary.withValues(alpha: 0.06),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.divider, width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 30, color: AppColors.primary),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkBrown,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: AppColors.primaryDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
