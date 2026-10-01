/// Classify which NDIS catalogue items may be stored on shift travel claims.
///
/// Mirrors `backend/.../billing/travel_item_rules.py` — keep tables identical.

/// NDIS support item number shape: `NN_MMM_RRRR_N_N`.
final RegExp _ndisItemRe = RegExp(r'^[0-9]{2}_[0-9]{3}_[0-9]{4}_[0-9]_[0-9]$');

/// Mid segment of NN_MMM_RRRR_N_N — provider travel non-labour + activity transport.
const Set<String> travelClaimMidSegments = {
  '799',
  '590',
  '591',
  '592',
  '821',
  '501',
};

/// Travel claims accept catalogue unit `E` only.
const Set<String> travelClaimUnits = {'E'};

bool isTravelClaimableItemNumber(String? code) {
  if (code == null) return false;
  final trimmed = code.trim();
  if (!_ndisItemRe.hasMatch(trimmed)) return false;
  final mid = trimmed.split('_')[1];
  return travelClaimMidSegments.contains(mid);
}

String? registrationGroupFromItemNumber(String? code) {
  if (code == null) return null;
  final trimmed = code.trim();
  if (!_ndisItemRe.hasMatch(trimmed)) return null;
  return trimmed.split('_')[2];
}

/// True when travel reg-group equals at least one anchor's reg-group.
///
/// Empty anchors → true (soft option 4: caller skipped narrowing).
bool travelCodeMatchesAnchors({
  required String travelCode,
  required List<String> anchorCodes,
}) {
  if (anchorCodes.isEmpty) return true;
  final travelRg = registrationGroupFromItemNumber(travelCode);
  if (travelRg == null) return false;
  for (final anchor in anchorCodes) {
    if (registrationGroupFromItemNumber(anchor) == travelRg) {
      return true;
    }
  }
  return false;
}

Set<String> uniqueRegistrationGroups(List<String> codes) {
  final groups = <String>{};
  for (final code in codes) {
    final rg = registrationGroupFromItemNumber(code);
    if (rg != null) groups.add(rg);
  }
  return groups;
}

/// Soft Provider Travel labour time cap (minutes) for an MMM category.
///
/// Mirrors BE `mmm_travel_cap_minutes`: MMM 1–3 → 30; 4–5 → 60; 6–7 / null → none.
int? mmmTravelCapMinutes(int? mmmCategory) {
  if (mmmCategory == null) return null;
  if (mmmCategory >= 1 && mmmCategory <= 3) return 30;
  if (mmmCategory >= 4 && mmmCategory <= 5) return 60;
  return null;
}

/// True when [minutes] exceed the soft MMM travel cap (strictly greater).
bool isOverMmmCap(num minutes, int? mmmCategory) {
  final cap = mmmTravelCapMinutes(mmmCategory);
  if (cap == null) return false;
  return minutes > cap;
}

/// Convert minutes to hours quantized to 4 decimal places (mirrors BE).
double minutesToHours(num minutes) {
  final hours = minutes / 60.0;
  final scaled = hours * 10000;
  final rounded = scaled.roundToDouble();
  return rounded / 10000;
}

/// Convert hours back to minutes (same 4dp precision as [minutesToHours]).
double hoursToMinutes(num hours) {
  final minutes = hours * 60.0;
  final scaled = minutes * 10000;
  final rounded = scaled.roundToDouble();
  return rounded / 10000;
}

/// Therapy / early childhood capacity-building registration groups where
/// Provider Travel labour is claimed at 50% of the catalogue hourly limit.
///
/// Keep in sync with BE `THERAPY_HALF_RATE_REGISTRATION_GROUPS`.
const Set<String> therapyHalfRateRegistrationGroups = {
  '0110',
  '0115',
  '0117',
  '0118',
  '0126',
  '0128',
  '0129',
  '0134',
  '0135',
  '0136',
  '0156',
};

bool isTherapyHalfRate(String? registrationGroup) {
  if (registrationGroup == null) return false;
  return therapyHalfRateRegistrationGroups.contains(registrationGroup.trim());
}

/// True when any of [itemCodes] sits in a therapy half-rate registration group.
bool anyTherapyHalfRateItem(Iterable<String> itemCodes) {
  for (final code in itemCodes) {
    if (isTherapyHalfRate(registrationGroupFromItemNumber(code))) {
      return true;
    }
  }
  return false;
}

/// Strip trailing zeros from a decimal quantity for display.
String formatTravelQty(num value) {
  return value.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
}
