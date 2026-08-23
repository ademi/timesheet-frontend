import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';

void main() {
  test('parses NDIS catalogue search response', () {
    final response = NdisCatalogueSearchResponse.fromJson({
      'q': 'self care',
      'limit': 5,
      'items': [
        {
          'support_item_number': '01_011_0107_1_1',
          'support_item_name': 'Assistance With Self-Care Activities',
          'unit': 'H',
          'quote_required': false,
          'price_limit_national': '65.47',
        },
      ],
    });

    expect(response.q, 'self care');
    expect(response.items.single.supportItemNumber, '01_011_0107_1_1');
    expect(response.items.single.priceLimitNational, '65.47');
  });

  test('serializes support item and price tier patches', () {
    expect(
      const SupportItemPatch(
        supportItemCode: '01_011_0107_1_1',
        supportItemName: 'Self care',
      ).toJson(),
      {
        'support_item_code': '01_011_0107_1_1',
        'support_item_name': 'Self care',
      },
    );
    expect(
      const SupportItemPatch().toJson(),
      {'support_item_code': null, 'support_item_name': null},
    );
    expect(
      const VisitPriceTierPatch(priceTierOverride: PriceTier.remote).toJson(),
      {'price_tier_override': 'remote'},
    );
    expect(
      const VisitPriceTierPatch().toJson(),
      {'price_tier_override': null},
    );
    expect(
      const VisitTaskBillingPatch(billableMinutes: 90).toJson(),
      {'billable_minutes': 90},
    );
  });

  test('parses invoice export with lines', () {
    final export = InvoiceExportOut.fromJson({
      'id': 'export-1',
      'tenant_id': 'tenant-1',
      'status': 'finalized',
      'line_count': 1,
      'total_amount': 130.94,
      'currency_code': 'AUD',
      'catalogue_release_id': 'release-1',
      'created_by_user_id': 'user-1',
      'finalized_at': '2026-01-15T10:00:00Z',
      'created_at': '2026-01-15T10:00:00Z',
      'updated_at': '2026-01-15T10:00:00Z',
      'lines': [
        {
          'id': 'line-1',
          'visit_id': 'visit-1',
          'client_id': 'client-1',
          'client_name': 'Jane Participant',
          'participant_ndis_number': '430000000',
          'support_item_number': '01_011_0107_1_1',
          'support_item_name': 'Self care',
          'service_date': '2026-01-15',
          'quantity': 2.0,
          'unit': 'H',
          'unit_price': 65.47,
          'line_amount': 130.94,
          'price_tier': 'national',
          'visit_task_id': null,
        },
      ],
    });

    expect(export.isFinalized, isTrue);
    expect(export.lines.single.participantNdisNumber, '430000000');
    expect(export.lines.single.priceTier, PriceTier.national);
  });

  test('PriceTier.labelForOverride formats tier labels', () {
    expect(PriceTier.labelForOverride(null), 'Auto (MMM postcode)');
    expect(PriceTier.labelForOverride(PriceTier.national), 'National');
    expect(PriceTier.labelForOverride(PriceTier.remote), 'Remote');
    expect(PriceTier.labelForOverride(PriceTier.veryRemote), 'Very remote');
  });
}
