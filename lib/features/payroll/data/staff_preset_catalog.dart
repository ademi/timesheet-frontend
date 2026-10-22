/// Job-title (i) can/cannot copy for staff presets.
///
/// Source of truth: `docs/2026-10-20-staff-preset-permission-matrix.md`.
library;

class StaffPresetInfo {
  const StaffPresetInfo({
    required this.key,
    required this.displayName,
    required this.can,
    required this.cannot,
  });

  final String key;
  final String displayName;
  final String can;
  final String cannot;
}

/// Default create preset when FE omits / initial selection (BE default too).
const kStaffPresetDefaultKey = 'office';

/// System-global assignable preset keys (picker allowlist).
const kStaffPresetKeysAll = {
  'admin',
  'supervisor',
  'office',
  'roster',
  'finance',
  'auditor',
};

/// Display order in the Add Staff picker (least-privilege-friendly mid list).
const kStaffPresetPickerOrder = <String>[
  'office',
  'supervisor',
  'roster',
  'finance',
  'auditor',
  'admin',
];

const kStaffPresetCatalog = <String, StaffPresetInfo>{
  'admin': StaffPresetInfo(
    key: 'admin',
    displayName: 'Admin',
    can:
        'Near-full tenant ops: participants, support workers invite/approve, roster, '
        'payments, billing, credentials review, create/manage staff',
    cannot:
        'Manage platform / other tenants; assign owner or platform admin; '
        'change RBAC catalog (rbac.manage)',
  ),
  'supervisor': StaffPresetInfo(
    key: 'supervisor',
    displayName: 'Supervisor / Coordinator',
    can:
        'Roster + shifts manage; invite and approve support workers; participants read + '
        'manage; credentials read/review',
    cannot:
        'Create/deactivate staff; manage billing; manage payments; manage '
        'credential catalog; change RBAC',
  ),
  'office': StaffPresetInfo(
    key: 'office',
    displayName: 'Office / Intake',
    can:
        'Participants read; invite support workers; basic support workers/roster read; see '
        'team list',
    cannot:
        'Create/edit participants; manage roster; approve support workers; '
        'payments/billing; create staff; credential review/manage; RBAC',
  ),
  'roster': StaffPresetInfo(
    key: 'roster',
    displayName: 'Roster only',
    can:
        'Shifts read + manage; supports/visits manage; support workers read; participants '
        'read',
    cannot:
        'Create/edit participants; invite or approve support workers; payments/billing; '
        'create staff; credential review/manage; RBAC',
  ),
  'finance': StaffPresetInfo(
    key: 'finance',
    displayName: 'Finance',
    can: 'Payments and billing view/manage; participants read; audit view',
    cannot:
        'Invite/approve support workers; manage roster; create/edit participants; '
        'create staff; credentials; RBAC',
  ),
  'auditor': StaffPresetInfo(
    key: 'auditor',
    displayName: 'Read-only auditor',
    can:
        'Read/view across participants, support workers, roster, payments, billing, '
        'credentials, audit',
    cannot:
        'Any create/update/delete, invite, approve, roster manage, '
        'payments/billing manage, staff create, credential review, RBAC',
  ),
};

StaffPresetInfo? staffPresetInfo(String key) =>
    kStaffPresetCatalog[key.trim().toLowerCase()];

String staffPresetDisplayName(String key, {String? fallback}) {
  final info = staffPresetInfo(key);
  if (info != null) return info.displayName;
  if (isPrivilegedSystemRole(key)) {
    final s = key.trim().toLowerCase();
    if (s.contains('platform')) return 'Platform admin';
    return 'Owner';
  }
  final f = fallback?.trim();
  if (f != null && f.isNotEmpty) return f;
  return key;
}

/// Roles that must never be assigned/changed via staff create/detail UI.
bool isPrivilegedSystemRole(String? raw) {
  if (raw == null) return false;
  final s = raw.trim().toLowerCase().replaceAll('.', '_');
  if (s.isEmpty) return false;
  return s == 'owner' ||
      s == 'platform_admin' ||
      s == 'platformadmin';
}

/// Map API role key / display name / aliases → preset key (`supervisor`, …).
///
/// List/detail responses sometimes return `role: "Supervisor / Coordinator"`
/// without `role_key` / `preset_key`. Without normalization the UI falls back
/// to Office.
String? normalizeStaffPresetKey(String? raw) {
  if (raw == null) return null;
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) return null;
  if (kStaffPresetKeysAll.contains(s)) return s;

  for (final e in kStaffPresetCatalog.entries) {
    if (e.value.displayName.toLowerCase() == s) return e.key;
  }

  if (s.contains('supervisor') || s.contains('coordinator')) {
    return 'supervisor';
  }
  if (s.contains('office') || s.contains('intake')) return 'office';
  if (s.contains('roster')) return 'roster';
  if (s.contains('finance')) return 'finance';
  if (s.contains('auditor') || s.contains('read-only') || s.contains('readonly')) {
    return 'auditor';
  }
  if (s == 'admin' || s.startsWith('admin ')) return 'admin';
  return null;
}

/// Stable picker order; unknown keys sort last by display name.
int staffPresetPickerCompare(String a, String b) {
  final ia = kStaffPresetPickerOrder.indexOf(a);
  final ib = kStaffPresetPickerOrder.indexOf(b);
  if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
  if (ia >= 0) return -1;
  if (ib >= 0) return 1;
  return staffPresetDisplayName(a).compareTo(staffPresetDisplayName(b));
}
