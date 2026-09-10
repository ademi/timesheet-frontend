import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/billing/data/models/invoice_export_models.dart';

void main() {
  group('InvoiceExportLineOut', () {
    test('parses backend snake_case fields', () {
      final line = InvoiceExportLineOut.fromJson({
        'id': 'line-1',
        'visit_id': 'visit-1',
        'client_id': 'client-1',
        'participant_ndis_number': '430000000',
        'support_item_number': '01_011_0107_1_1',
        'support_item_name': 'Assistance with self-care',
        'service_date': '2026-09-10',
        'quantity': 2.5,
        'unit': 'H',
        'unit_price': 65.5,
        'line_amount': 163.75,
        'client_name': 'Taylor Smith',
        'price_tier': 'national',
        'visit_task_id': 'task-1',
        'shift_participant_id': 'participant-1',
      });

      expect(line.id, 'line-1');
      expect(line.visitId, 'visit-1');
      expect(line.clientId, 'client-1');
      expect(line.participantNdisNumber, '430000000');
      expect(line.supportItemNumber, '01_011_0107_1_1');
      expect(line.supportItemName, 'Assistance with self-care');
      expect(line.serviceDate, DateTime(2026, 9, 10));
      expect(line.quantity, 2.5);
      expect(line.unit, 'H');
      expect(line.unitPrice, 65.5);
      expect(line.lineAmount, 163.75);
      expect(line.clientName, 'Taylor Smith');
      expect(line.priceTier, 'national');
      expect(line.visitTaskId, 'task-1');
      expect(line.shiftParticipantId, 'participant-1');
    });
  });

  group('InvoiceExportOut', () {
    test('parses export and nested lines', () {
      final export = InvoiceExportOut.fromJson({
        'id': 'export-1',
        'tenant_id': 'tenant-1',
        'status': 'finalized',
        'line_count': 1,
        'total_amount': 163.75,
        'currency_code': 'AUD',
        'catalogue_release_id': 'catalogue-1',
        'created_by_user_id': 'user-1',
        'finalized_at': '2026-09-10T01:02:03Z',
        'created_at': '2026-09-10T01:00:00Z',
        'updated_at': '2026-09-10T01:02:03Z',
        'lines': [
          {
            'id': 'line-1',
            'visit_id': 'visit-1',
            'client_id': null,
            'participant_ndis_number': null,
            'support_item_number': '01_011_0107_1_1',
            'support_item_name': 'Assistance with self-care',
            'service_date': '2026-09-10',
            'quantity': 1,
            'unit': 'H',
            'unit_price': 65.5,
            'line_amount': 65.5,
          },
        ],
      });

      expect(export.id, 'export-1');
      expect(export.lineCount, 1);
      expect(export.totalAmount, 163.75);
      expect(export.finalizedAt, DateTime.utc(2026, 9, 10, 1, 2, 3));
      expect(export.lines.single.visitId, 'visit-1');
      expect(export.isVoided, isFalse);
    });

    test('recognises void and voided statuses', () {
      Map<String, dynamic> json(String status) => {
            'id': 'export-1',
            'tenant_id': 'tenant-1',
            'status': status,
            'line_count': 0,
            'total_amount': 0,
            'currency_code': 'AUD',
            'created_at': '2026-09-10T01:00:00Z',
            'updated_at': '2026-09-10T01:00:00Z',
          };

      expect(InvoiceExportOut.fromJson(json('void')).isVoided, isTrue);
      expect(InvoiceExportOut.fromJson(json('voided')).isVoided, isTrue);
    });
  });

  test('InvoiceExportCreateRequest serializes visit IDs as snake_case', () {
    const request = InvoiceExportCreateRequest(
      visitIds: ['visit-1', 'visit-2'],
    );

    expect(request.toJson(), {
      'visit_ids': ['visit-1', 'visit-2'],
    });
  });
}
