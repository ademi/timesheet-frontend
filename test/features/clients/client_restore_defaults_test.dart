import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/controllers/clients_controller.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';

final _now = DateTime.utc(2026, 9, 23, 12);

ClientOut _archived({Map<String, dynamic> metadata = const {}}) {
  return ClientOut(
    id: 'client-1',
    tenantId: 'tenant-1',
    fullName: 'Archived Client',
    status: 'archived',
    metadata: metadata,
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
  test(
    'defaultRestoreTargetStatus returns inactive when status_before_archive is inactive',
    () {
      final client = _archived(
        metadata: const {'status_before_archive': 'inactive'},
      );
      expect(
        ClientsController.defaultRestoreTargetStatus(client),
        'inactive',
      );
    },
  );

  test(
    'defaultRestoreTargetStatus defaults to active when prior status unknown',
    () {
      expect(
        ClientsController.defaultRestoreTargetStatus(_archived()),
        'active',
      );
      expect(
        ClientsController.defaultRestoreTargetStatus(
          _archived(metadata: const {'status_before_archive': 'active'}),
        ),
        'active',
      );
    },
  );

  test(
    'defaultRestoreTargetStatus falls back to previous_status metadata key',
    () {
      final client = _archived(
        metadata: const {'previous_status': 'inactive'},
      );
      expect(
        ClientsController.defaultRestoreTargetStatus(client),
        'inactive',
      );
    },
  );
}
