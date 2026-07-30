import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rostiq/core/mixins/pending_action_mixin.dart';

class _PendingActionController extends GetxController with PendingActionMixin {}

void main() {
  test('keeps concurrent action keys pending independently', () async {
    final controller = _PendingActionController();
    final terms = Completer<void>();
    final privacy = Completer<void>();

    final termsAction = controller.runPendingAction('accept-terms', () {
      return terms.future;
    });
    final privacyAction = controller.runPendingAction('accept-privacy', () {
      return privacy.future;
    });

    expect(controller.isPending('accept-terms'), isTrue);
    expect(controller.isPending('accept-privacy'), isTrue);
    expect(controller.hasPendingAction, isTrue);

    terms.complete();
    await termsAction;

    expect(controller.isPending('accept-terms'), isFalse);
    expect(controller.isPending('accept-privacy'), isTrue);

    privacy.complete();
    await privacyAction;

    expect(controller.hasPendingAction, isFalse);
  });
}
