import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/feature_flags.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/max_width_box.dart';
import '../controllers/gateway_controller.dart';
import '../themes/app_colors.dart';

class GatewayView extends GetView<GatewayController> {
  const GatewayView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: MaxWidthBox(
                  maxWidth: Breakpoints.formMaxWidth,
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Image.asset(
                        'assets/images/logo.png',
                        height: 56,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.schedule_rounded,
                          size: 56,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Rostiq',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Contractor platform',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primaryDark,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Obx(
                        () => IgnorePointer(
                          ignoring: controller.isRestoringSession.value,
                          child: Opacity(
                            opacity:
                                controller.isRestoringSession.value ? 0.5 : 1,
                            child: Column(
                              children: [
                                _ActionCard(
                                  icon: Icons.login_rounded,
                                  title: 'Sign in',
                                  subtitle: 'Staff or contractor account',
                                  onTap: controller.goToSignIn,
                                ),
                                const SizedBox(height: 16),
                                _ActionCard(
                                  icon: Icons.person_add_alt_1_rounded,
                                  title: 'Register as contractor',
                                  subtitle: 'Create your contractor profile',
                                  onTap: controller.goToContractorRegister,
                                ),
                                const SizedBox(height: 16),
                                _ActionCard(
                                  icon: Icons.business_rounded,
                                  title: 'Provider signup',
                                  subtitle: 'Company account on the website',
                                  onTap: controller.openProviderSignup,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Billing & company signup live on the landing site.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppEnv.landingUrl,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Obx(
            () => controller.isRestoringSession.value
                ? const ColoredBox(
                    color: Color(0x33000000),
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Restoring your session…'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
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
                        color: AppColors.textDark,
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
