import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/onboarding_keys.dart';

/// Shared contract for [ContactFormFields] (standalone contact form + onboarding).
abstract class ContactFormHost {
  static const relationshipOtherKey = '_other';

  static const relationshipPresets = <String, String>{
    OnboardingKeys.relEmergency: 'Emergency',
    OnboardingKeys.relCarer: 'Carer',
    OnboardingKeys.relChildRepresentative: 'Child representative',
    OnboardingKeys.relNominee: 'Nominee',
  };

  TextEditingController get contactNameCtrl;
  TextEditingController get contactEmailCtrl;
  TextEditingController get contactPhoneCtrl;
  TextEditingController get contactRelationshipOtherCtrl;

  RxnString get contactRelationshipPreset;
  RxBool get contactIsPrimary;

  String? get resolvedContactRelationship {
    final preset = contactRelationshipPreset.value;
    if (preset == null || preset.isEmpty) return null;
    if (preset == relationshipOtherKey) {
      final other = contactRelationshipOtherCtrl.text.trim();
      return other.isEmpty ? null : other;
    }
    return preset;
  }
}
