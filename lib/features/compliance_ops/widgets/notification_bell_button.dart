import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/auth_controller.dart';
import '../../../app/themes/app_colors.dart';
import '../controllers/notifications_feed_controller.dart';
import '../data/models/notification_display.dart';

/// Standard AppBar actions: notification bell (+ optional extras) + logout.
List<Widget> shellAppBarActions({
  List<Widget> leadingActions = const [],
  VoidCallback? onRefresh,
}) {
  return [
    ...leadingActions,
    const NotificationBellButton(),
    if (onRefresh != null)
      IconButton(
        tooltip: 'Refresh',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh),
      ),
    if (Get.isRegistered<AuthController>())
      IconButton(
        tooltip: 'Log out',
        onPressed: () => Get.find<AuthController>().logout(),
        icon: const Icon(Icons.logout),
      ),
  ];
}

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<NotificationsFeedController>()) {
      return IconButton(
        tooltip: 'Notifications',
        onPressed: () async {
          NotificationsFeedController.ensureRegistered();
          await showNotificationsSheet(context);
        },
        icon: const Icon(Icons.notifications_outlined),
      );
    }

    final feed = Get.find<NotificationsFeedController>();

    return Obx(() {
      final count = feed.badgeCount;
      return IconButton(
        tooltip: 'Notifications',
        onPressed: () => showNotificationsSheet(context),
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          backgroundColor: AppColors.error,
          textColor: AppColors.onPrimary,
          child: const Icon(Icons.notifications_outlined),
        ),
      );
    });
  }
}

Future<void> showNotificationsSheet(BuildContext context) async {
  NotificationsFeedController.ensureRegistered();
  final feed = Get.find<NotificationsFeedController>();
  feed.markOpened();
  if (feed.events.isEmpty && !feed.isLoading.value) {
    await feed.load();
  }

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Obx(() {
            final err = feed.errorMessage.value;
            final events = feed.events.toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.slate300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Notifications',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed:
                            feed.isLoading.value
                                ? null
                                : () => feed.load(force: true),
                        icon:
                            feed.isLoading.value
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (err != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      err,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                Expanded(
                  child:
                      events.isEmpty && !feed.isLoading.value
                          ? ListView(
                            controller: scrollController,
                            children: const [
                              SizedBox(height: 48),
                              Center(
                                child: Text(
                                  'No notifications yet.',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              ),
                            ],
                          )
                          : RefreshIndicator(
                            onRefresh: () => feed.load(force: true),
                            child: ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: events.length,
                              separatorBuilder:
                                  (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final e = events[index];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.notifications_outlined,
                                  ),
                                  title: Text(
                                    notificationTitle(e.eventType, e.payload),
                                  ),
                                  subtitle: Text(
                                    formatNotificationTime(e.createdAt),
                                  ),
                                );
                              },
                            ),
                          ),
                ),
              ],
            );
          });
        },
      );
    },
  );
}
