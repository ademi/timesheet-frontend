import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/compliance_ops/data/models/compliance_ops_models.dart';
import 'package:rostiq/features/payroll/controllers/staff_list_controller.dart';
import 'package:rostiq/features/payroll/data/staff_preset_catalog.dart';

void main() {
  group('StaffListController.memberRoleKey', () {
    test('normalizes preset keys and display labels', () {
      expect(
        StaffListController.memberRoleKey(
          const TenantMemberOut(
            id: '1',
            email: 'a@x.com',
            roleKey: 'supervisor',
          ),
        ),
        'supervisor',
      );
      expect(
        StaffListController.memberRoleKey(
          const TenantMemberOut(
            id: '2',
            email: 'b@x.com',
            role: 'Office / Intake',
          ),
        ),
        'office',
      );
    });

    test('falls back to role label when unknown', () {
      expect(
        StaffListController.memberRoleKey(
          const TenantMemberOut(
            id: '3',
            email: 'c@x.com',
            role: 'Custom Role',
          ),
        ),
        'custom role',
      );
    });
  });

  test('staffPresetDisplayName used for tab labels', () {
    expect(staffPresetDisplayName('finance'), 'Finance');
    expect(staffPresetDisplayName('admin'), 'Admin');
  });
}
