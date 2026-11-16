import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_navigator.dart';
import '../../../app/routes/middlewares/auth_route_utils.dart';
import '../data/tutorial_catalog.dart';
import '../models/tutorial_guide.dart';

/// Staff-web tutorials panel state (open/close, search, selected guide).
class TutorialsController extends GetxController {
  final isOpen = false.obs;
  final searchQuery = ''.obs;
  final selectedGuideId = RxnString();
  final searchController = TextEditingController();

  static void ensureRegistered() {
    if (!Get.isRegistered<TutorialsController>()) {
      Get.put(TutorialsController(), permanent: true);
    }
  }

  String get _currentPath => locationPath(AppNavigator.currentLocation);

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  void open() {
    isOpen.value = true;
  }

  void close() {
    isOpen.value = false;
    searchController.clear();
    searchQuery.value = '';
    selectedGuideId.value = null;
  }

  void toggle() {
    if (isOpen.value) {
      close();
    } else {
      open();
    }
  }

  void setSearch(String value) {
    searchQuery.value = value;
  }

  void openGuide(TutorialGuide guide) {
    selectedGuideId.value = guide.id;
  }

  void backToHome() {
    selectedGuideId.value = null;
  }

  TutorialGuide? get selectedGuide {
    final id = selectedGuideId.value;
    if (id == null) return null;
    return TutorialCatalog.byId(id);
  }

  /// Guides matching search, with route-relevant items pinned first.
  List<TutorialGuide> get visibleGuides {
    final path = _currentPath;
    final q = searchQuery.value;
    final matched =
        TutorialCatalog.guides.where((g) => g.matchesQuery(q)).toList();

    final suggested = <TutorialGuide>[];
    final rest = <TutorialGuide>[];
    for (final g in matched) {
      if (g.matchesRoute(path)) {
        suggested.add(g);
      } else {
        rest.add(g);
      }
    }
    return [...suggested, ...rest];
  }

  bool isSuggested(TutorialGuide guide) => guide.matchesRoute(_currentPath);
}
