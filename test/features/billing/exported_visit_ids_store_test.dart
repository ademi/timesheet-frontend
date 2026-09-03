import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/billing/data/exported_visit_ids_store.dart';

void main() {
  test('mark then contains; release removes; clear empties', () {
    final store = ExportedVisitIdsStore();
    store.mark(['visit-1', 'visit-2', '']);
    expect(store.contains('visit-1'), isTrue);
    expect(store.contains('visit-2'), isTrue);
    expect(store.ids, {'visit-1', 'visit-2'});

    store.release(['visit-1']);
    expect(store.contains('visit-1'), isFalse);
    expect(store.contains('visit-2'), isTrue);

    store.clear();
    expect(store.ids, isEmpty);
  });
}
