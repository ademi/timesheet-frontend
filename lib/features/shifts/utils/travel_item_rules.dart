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
