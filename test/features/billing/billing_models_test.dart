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
    expect(const SupportItemPatch().toJson(), {
      'support_item_code': null,
      'support_item_name': null,
    });
    expect(
      const VisitPriceTierPatch(priceTierOverride: PriceTier.remote).toJson(),
      {'price_tier_override': 'remote'},
    );
    expect(const VisitPriceTierPatch().toJson(), {'price_tier_override': null});
    expect(const VisitTaskBillingPatch(billableMinutes: 90).toJson(), {
      'billable_minutes': 90,
    });
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
      'budget_warnings': [
        {
          'code': 'budget_exceeded',
          'client_id': 'client-1',
          'envelope': 'core',
          'line_amount': 130.94,
          'remaining_before': 50,
          'remaining_after': -80.94,
          'support_item_number': '01_011_0107_1_1',
          'support_category_number': '01',
        },
      ],
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
    expect(export.budgetWarnings, hasLength(1));
    expect(export.budgetWarnings.single.code, 'budget_exceeded');
    expect(export.budgetWarnings.single.remainingAfter, -80.94);
    expect(export.budgetWarnings.single.supportCategoryNumber, '01');
  });

  test('invoice export defaults budget warnings to empty', () {
    final export = InvoiceExportOut.fromJson({
      'id': 'export-1',
      'tenant_id': 'tenant-1',
      'status': 'finalized',
      'line_count': 0,
      'total_amount': 0,
      'currency_code': 'AUD',
      'created_at': '2026-01-15T10:00:00Z',
      'updated_at': '2026-01-15T10:00:00Z',
    });

    expect(export.budgetWarnings, isEmpty);
  });

  test('PriceTier.labelForOverride formats tier labels', () {
    expect(PriceTier.labelForOverride(null), 'Auto (MMM postcode)');
    expect(PriceTier.labelForOverride(PriceTier.national), 'National');
    expect(PriceTier.labelForOverride(PriceTier.remote), 'Remote');
    expect(PriceTier.labelForOverride(PriceTier.veryRemote), 'Very remote');
  });

  test('PriceTier.sourceHint names staff override', () {
    expect(
      PriceTier.sourceHint(
        priceTierOverride: PriceTier.remote,
        lockedExported: false,
      ),
      contains('staff override'),
    );
  });

  test('PriceTier.sourceHint names Auto MMM when no override', () {
    expect(
      PriceTier.sourceHint(priceTierOverride: null, lockedExported: false),
      contains('Auto (MMM'),
    );
  });

  test('PriceTier.sourceHint locked when exported', () {
    expect(
      PriceTier.sourceHint(
        priceTierOverride: PriceTier.national,
        lockedExported: true,
      ),
      startsWith('Locked'),
    );
  });
}
