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

/// Keys used in P0 Add Staff picker (Admin / Supervisor only).
const kStaffPresetKeysP0 = {'admin', 'supervisor'};

/// All system-global assignable preset keys (P1+).
const kStaffPresetKeysAll = {
  'admin',
  'supervisor',
  'office',
  'roster',
  'finance',
  'auditor',
};

const kStaffPresetCatalog = <String, StaffPresetInfo>{
  'admin': StaffPresetInfo(
    key: 'admin',
    displayName: 'Admin',
    can:
        'Near-full tenant ops: clients, contractors invite/approve, roster, '
        'payments, billing, credentials review, create/manage staff',
    cannot:
        'Manage platform / other tenants; assign owner or platform admin; '
        'change RBAC catalog (rbac.manage)',
  ),
  'supervisor': StaffPresetInfo(
    key: 'supervisor',
    displayName: 'Supervisor / Coordinator',
    can:
        'Roster + shifts manage; invite and approve contractors; clients read + '
        'manage; credentials read/review',
    cannot:
        'Create/deactivate staff; manage billing; manage payments; manage '
        'credential catalog; change RBAC',
  ),
  'office': StaffPresetInfo(
    key: 'office',
    displayName: 'Office / Intake',
    can:
        'Clients read; invite contractors; basic workforce/roster read; see '
        'team list',
    cannot:
        'Create/edit clients; manage roster; approve contractors; '
        'payments/billing; create staff; credential review/manage; RBAC',
  ),
  'roster': StaffPresetInfo(
    key: 'roster',
    displayName: 'Roster only',
    can:
        'Shifts read + manage; jobs/visits manage; contractors read; clients '
        'read',
    cannot:
        'Create/edit clients; invite or approve contractors; payments/billing; '
        'create staff; credential review/manage; RBAC',
  ),
  'finance': StaffPresetInfo(
    key: 'finance',
    displayName: 'Finance',
    can: 'Payments and billing view/manage; clients read; audit view',
    cannot:
        'Invite/approve contractors; manage roster; create/edit clients; '
        'create staff; credentials; RBAC',
  ),
  'auditor': StaffPresetInfo(
    key: 'auditor',
    displayName: 'Read-only auditor',
    can:
        'Read/view across clients, contractors, roster, payments, billing, '
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
  final f = fallback?.trim();
  if (f != null && f.isNotEmpty) return f;
  return key;
}
