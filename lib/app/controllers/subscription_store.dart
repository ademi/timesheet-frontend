import 'package:get/get.dart';

import '../data/models/auth/subscription_snapshot.dart';

/// Holds the latest subscription snapshot from login/refresh (F-06).
class SubscriptionStore extends GetxController {
  final snapshot = Rxn<SubscriptionSnapshot>();

  void updateFromLogin(SubscriptionSnapshot? value) {
    snapshot.value = value;
  }

  void clear() => snapshot.value = null;
}
