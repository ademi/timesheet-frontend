import 'package:get/get.dart';

/// Tracks independently pending UI actions by stable keys.
mixin PendingActionMixin on GetxController {
  final pendingActionKeys = <String>[].obs;

  bool isPending(String key) => pendingActionKeys.contains(key);

  bool get hasPendingAction => pendingActionKeys.isNotEmpty;

  Future<T> runPendingAction<T>(String key, Future<T> Function() action) async {
    pendingActionKeys.add(key);
    try {
      return await action();
    } finally {
      pendingActionKeys.remove(key);
    }
  }
}

/// Keeps a shared saving indicator active until all nested saves complete.
mixin SavingCounterMixin on GetxController {
  final isSaving = false.obs;
  var _saveDepth = 0;

  Future<T> runSaving<T>(Future<T> Function() action) async {
    _saveDepth++;
    isSaving.value = true;
    try {
      return await action();
    } finally {
      _saveDepth--;
      if (_saveDepth <= 0) {
        _saveDepth = 0;
        isSaving.value = false;
      }
    }
  }
}
