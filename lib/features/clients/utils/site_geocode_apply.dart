import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/client_models.dart';

class GeocodeApplyOutcome {
  const GeocodeApplyOutcome({required this.accepted, this.errorMessage});

  final bool accepted;
  final String? errorMessage;
}

/// Shared low-confidence gate + lat/lng/formatted write for site forms.
GeocodeApplyOutcome applyGeocodeResponse({
  required GeocodeResponse result,
  required TextEditingController latCtrl,
  required TextEditingController lngCtrl,
  required RxnString formattedAddress,
  required RxBool addressConfirmed,
  required String addressFallback,
}) {
  final confidence = result.confidence?.toLowerCase();
  if (confidence == 'low') {
    latCtrl.clear();
    lngCtrl.clear();
    formattedAddress.value = null;
    addressConfirmed.value = false;
    return const GeocodeApplyOutcome(
      accepted: false,
      errorMessage:
          'Address lookup has low confidence. Check the street and city, '
          'then try again.',
    );
  }
  latCtrl.text = result.latitude.toString();
  lngCtrl.text = result.longitude.toString();
  final formatted = result.formattedAddress;
  formattedAddress.value =
      (formatted != null && formatted.isNotEmpty) ? formatted : addressFallback;
  addressConfirmed.value = false;
  return const GeocodeApplyOutcome(accepted: true);
}
