import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/complete_account_controller.dart';

/// Redirect shell — `/contractor/complete-account` forwards to Profile.
class CompleteAccountView extends GetView<CompleteAccountController> {
  const CompleteAccountView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Opening profile…'),
          ],
        ),
      ),
    );
  }
}
