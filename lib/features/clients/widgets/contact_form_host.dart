import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/onboarding_keys.dart';

/// Shared contract for [ContactFormFields] (standalone contact form + onboarding).
abstract class ContactFormHost {
  static const relationshipOtherKey = '_other';

  /// Kinship labels for Contacts (D1=A). Emergency is a flag, not a preset.
  static const kinshipPresets = <String, String>{
    'mother': 'Mother',
    'father': 'Father',
    'son': 'Son',
    'daughter': 'Daughter',
    'sibling': 'Sibling',
    'spouse': 'Spouse / partner',
    'friend': 'Friend',
    'neighbour': 'Neighbour',
    'carer': 'Carer', // CR5: kinship label only here; nominee step uses legalRolePresets
    'other': 'Other',
  };

  /// Legal roles for the representative step only.
  static const legalRolePresets = <String, String>{
    OnboardingKeys.relChildRepresentative: 'Child representative',
    OnboardingKeys.relNominee: 'Nominee',
  };

  /// Combined labels for list/detail display (not the Contacts dropdown).
  static const relationshipPresets = <String, String>{
    ...kinshipPresets,
    ...legalRolePresets,
  };

  TextEditingController get contactNameCtrl;
  TextEditingController get contactEmailCtrl;
  TextEditingController get contactPhoneCtrl;
  TextEditingController get contactRelationshipOtherCtrl;

  RxnString get contactRelationshipPreset;
  RxBool get contactIsPrimary;
  RxBool get contactIsEmergency;

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
