import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/themes/app_colors.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';
import 'package:rostiq/features/billing/data/ndis_catalogue_filter_prefs.dart';
import 'package:rostiq/features/billing/data/ndis_catalogue_local_filter.dart';
import 'package:rostiq/features/billing/data/repositories/ndis_catalogue_repository.dart';
import 'package:rostiq/shared/widgets/ndis_support_item_picker.dart';

class _MockNdisCatalogueRepository extends Mock
    implements NdisCatalogueRepository {}

const _item = NdisCatalogueItemOut(
  supportItemNumber: '01_011_0107_1_1',
  supportItemName: 'Assistance With Self-Care Activities - Standard - Weekday Daytime',
  unit: 'H',
);

/// Unpadded category numbers match the live catalogue (`'1'` not `'01'`).
const _liveCatalogue = [
  NdisCatalogueItemOut(
    supportItemNumber: '01_011_0107_1_1',
    supportItemName:
        'Assistance With Self-Care Activities - Standard - Weekday Daytime',
    supportCategoryNumber: '1',
    supportCategoryName: 'Assistance with Daily Life',
    registrationGroupNumber: '0107',
    registrationGroupName: 'Daily Personal Activities',
    unit: 'H',
  ),
  NdisCatalogueItemOut(
    supportItemNumber: '01_019_0120_1_1',
    supportItemName: 'House or Yard Maintenance',
    supportCategoryNumber: '1',
    supportCategoryName: 'Assistance with Daily Life',
    registrationGroupNumber: '0120',
    registrationGroupName: 'Household Tasks',
    unit: 'H',
  ),
  NdisCatalogueItemOut(
    supportItemNumber: '04_104_0125_6_1',
    supportItemName: 'Access Community Social and Rec Activities',
    supportCategoryNumber: '4',
    supportCategoryName: 'Community Participation',
    registrationGroupNumber: '0125',
    registrationGroupName:
        'Participation In Community, Social And Civic Activities',
    unit: 'H',
  ),
];

NdisCatalogueFacet _categoryFacet(String number) =>
    NdisCatalogueLocalFilter.facets(_liveCatalogue).supportCategories.singleWhere(
      (facet) => facet.number == number,
    );

class _Harness extends StatefulWidget {
  const _Harness({
    required this.repository,
    this.initialCode,
    this.initialName,
    this.onChanged,
    this.filterPrefs,
  });

  final NdisCatalogueRepository repository;
  final String? initialCode;
  final String? initialName;
  final void Function(String? code, String? name)? onChanged;
  final NdisCatalogueFilterPrefs? filterPrefs;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String? code;
  String? name;

  @override
  void initState() {
    super.initState();
    code = widget.initialCode;
    name = widget.initialName;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: NdisSupportItemPicker(
          supportItemCode: code,
          supportItemName: name,
          repository: widget.repository,
          filterPrefs: widget.filterPrefs,
          debounceDuration: Duration.zero,
          onChanged: ({
            required String? supportItemCode,
            required String? supportItemName,
          }) {
            setState(() {
              code = supportItemCode;
              name = supportItemName;
            });
            widget.onChanged?.call(supportItemCode, supportItemName);
          },
        ),
      ),
    );
  }
}

void main() {
  late _MockNdisCatalogueRepository repository;
  late Map<String, dynamic> filterBox;

  setUp(() {
    repository = _MockNdisCatalogueRepository();
    filterBox = <String, dynamic>{};
    when(
      () => repository.fetchAllActiveItems(),
    ).thenAnswer((_) async => const <NdisCatalogueItemOut>[]);
  });

  NdisCatalogueFilterPrefs isolatedFilterPrefs() => NdisCatalogueFilterPrefs(
        read: (key) => filterBox[key],
        write: (key, value) => filterBox[key] = value,
        remove: (key) => filterBox.remove(key),
      );

  Widget isolatedHarness({
    String? initialCode,
    String? initialName,
    void Function(String? code, String? name)? onChanged,
  }) {
    return _Harness(
      repository: repository,
      initialCode: initialCode,
      initialName: initialName,
      onChanged: onChanged,
      filterPrefs: isolatedFilterPrefs(),
    );
  }

  group('isValidNdisSupportItemCode', () {
    test('accepts canonical NDIS item numbers', () {
      expect(isValidNdisSupportItemCode('01_011_0107_1_1'), isTrue);
    });

    test('rejects malformed codes', () {
      expect(isValidNdisSupportItemCode('1_011_0107_1_1'), isFalse);
      expect(isValidNdisSupportItemCode('bad'), isFalse);
      expect(isValidNdisSupportItemCode(''), isFalse);
    });
  });

  testWidgets('shows selected item with clear action', (tester) async {
    String? clearedCode;
    String? clearedName;

    await tester.pumpWidget(
      isolatedHarness(
        initialCode: _item.supportItemNumber,
        initialName: _item.supportItemName,
        onChanged: (code, name) {
          clearedCode = code;
          clearedName = name;
        },
      ),
    );

    expect(find.text(_item.supportItemName), findsOneWidget);
    expect(find.text(_item.supportItemNumber), findsOneWidget);

    await tester.tap(find.byTooltip('Clear support item'));
    await tester.pumpAndSettle();

    expect(clearedCode, isNull);
    expect(clearedName, isNull);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('debounced search selects code and canonical name', (tester) async {
    when(
      () => repository.fetchAllActiveItems(),
    ).thenAnswer((_) async => const [_item]);

    String? pickedCode;
    String? pickedName;

    await tester.pumpWidget(
      isolatedHarness(
        onChanged: (code, name) {
          pickedCode = code;
          pickedName = name;
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'self');
    await tester.pump();
    await tester.pump();

    expect(find.text(_item.supportItemName), findsWidgets);
    await tester.tap(find.text(_item.supportItemNumber).last);
    await tester.pump();

    expect(pickedCode, _item.supportItemNumber);
    expect(pickedName, _item.supportItemName);
    expect(find.text(_item.supportItemName), findsOneWidget);
    expect(find.byTooltip('Clear support item'), findsOneWidget);
    verify(() => repository.fetchAllActiveItems()).called(1);
    verifyNever(
      () => repository.searchItems(q: any(named: 'q'), limit: any(named: 'limit')),
    );
  });

  testWidgets('select survives field blur before tap (web gesture order)', (
    tester,
  ) async {
    when(
      () => repository.fetchAllActiveItems(),
    ).thenAnswer((_) async => const [_item]);

    String? pickedCode;
    String? pickedName;

    await tester.pumpWidget(
      isolatedHarness(
        onChanged: (code, name) {
          pickedCode = code;
          pickedName = name;
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), '01_011');
    await tester.pump();
    await tester.pump();
    expect(find.text(_item.supportItemNumber), findsWidgets);

    // Simulate web: TextField blurs before the list row receives the tap.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.text(_item.supportItemNumber), findsWidgets);

    await tester.tap(find.text(_item.supportItemNumber).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(pickedCode, _item.supportItemNumber);
    expect(pickedName, _item.supportItemName);
    expect(find.byTooltip('Clear support item'), findsOneWidget);
    verifyNever(
      () => repository.searchItems(q: any(named: 'q'), limit: any(named: 'limit')),
    );
  });

  testWidgets('clear in search mode sends null pair', (tester) async {
    String? clearedCode = 'keep';
    String? clearedName = 'keep';

    await tester.pumpWidget(
      isolatedHarness(
        onChanged: (code, name) {
          clearedCode = code;
          clearedName = name;
        },
      ),
    );

    await tester.enterText(find.byType(TextField), 'p');
    await tester.pump();
    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();

    expect(clearedCode, isNull);
    expect(clearedName, isNull);
    verifyNever(
      () => repository.searchItems(q: any(named: 'q'), limit: any(named: 'limit')),
    );
  });

  testWidgets('shows format error for invalid typed code on blur', (tester) async {
    await tester.pumpWidget(
      isolatedHarness(
      ),
    );

    // Digits/underscores only but not a full NDIS item number.
    await tester.enterText(find.byType(TextField), '01_011');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Invalid NDIS item number format.'), findsOneWidget);
  });

  testWidgets('shows pick-row hint for name-like typed text on blur', (tester) async {
    await tester.pumpWidget(
      isolatedHarness(
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      'Assistance With Self-Care Activities',
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Pick a catalogue row so the name matches.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'picker loads catalogue once then filters by category without new HTTP',
    (tester) async {
      var fetches = 0;
      when(() => repository.fetchAllActiveItems()).thenAnswer((_) async {
        fetches += 1;
        return _liveCatalogue;
      });

      await tester.pumpWidget(isolatedHarness());
      await tester.pump();
      await tester.pump();

      expect(fetches, 1);
      expect(
        find.text('Access Community Social and Rec Activities'),
        findsOneWidget,
      );

      final categoryOne = _categoryFacet('1');
      await tester.tap(find.byKey(ndisCategoryChipKey(categoryOne.number)));
      await tester.pump();

      expect(fetches, 1);
      verifyNever(
        () => repository.searchItems(
          q: any(named: 'q'),
          limit: any(named: 'limit'),
        ),
      );
      expect(find.text('House or Yard Maintenance'), findsOneWidget);
      expect(
        find.text('Access Community Social and Rec Activities'),
        findsNothing,
      );

      await tester.enterText(find.byType(TextField), 'self');
      await tester.pump();
      await tester.pump();

      expect(fetches, 1);
      verifyNever(
        () => repository.searchItems(
          q: any(named: 'q'),
          limit: any(named: 'limit'),
        ),
      );
      expect(
        find.text(
          'Assistance With Self-Care Activities - Standard - Weekday Daytime',
        ),
        findsWidgets,
      );
      expect(find.text('House or Yard Maintenance'), findsNothing);
    },
  );

  testWidgets(
    'registration group options cascade from selected category',
    (tester) async {
      when(
        () => repository.fetchAllActiveItems(),
      ).thenAnswer((_) async => _liveCatalogue);

      await tester.pumpWidget(isolatedHarness());
      await tester.pump();
      await tester.pump();

      final categoryOne = _categoryFacet('1');
      await tester.tap(find.byKey(ndisCategoryChipKey(categoryOne.number)));
      await tester.pump();

      await tester.tap(find.byKey(ndisRegistrationGroupKey));
      await tester.pumpAndSettle();

      expect(find.textContaining('0107'), findsWidgets);
      expect(find.textContaining('0120'), findsWidgets);
      expect(find.textContaining('0125'), findsNothing);

      await tester.tap(find.textContaining('0107').last);
      await tester.pumpAndSettle();

      final categoryFour = _categoryFacet('4');
      await tester.tap(find.byKey(ndisCategoryChipKey(categoryFour.number)));
      await tester.pump();

      expect(find.textContaining('0107'), findsNothing);
      await tester.tap(find.byKey(ndisRegistrationGroupKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('0125'), findsWidgets);
      expect(find.textContaining('0107'), findsNothing);
      expect(find.textContaining('0120'), findsNothing);
    },
  );

  testWidgets('shows Filtered locally (N of M) helper', (tester) async {
    when(
      () => repository.fetchAllActiveItems(),
    ).thenAnswer((_) async => _liveCatalogue);

    await tester.pumpWidget(isolatedHarness());
    await tester.pump();
    await tester.pump();

    expect(find.text('Filtered locally (3 of 3)'), findsOneWidget);

    final categoryOne = _categoryFacet('1');
    await tester.tap(find.byKey(ndisCategoryChipKey(categoryOne.number)));
    await tester.pump();

    expect(find.text('Filtered locally (2 of 3)'), findsOneWidget);
  });

  testWidgets(
    'catalogue fetch failure shows muted error; field still usable',
    (tester) async {
      const failure = AppFailure(
        code: 'network_error',
        message: 'Could not reach the API.',
        presentation: AppFailurePresentation.inline,
      );
      when(
        () => repository.fetchAllActiveItems(),
      ).thenAnswer((_) async => throw failure);

      await tester.pumpWidget(isolatedHarness());
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Could not reach the API.'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Could not reach the API.')).style?.color,
        AppColors.textMuted,
      );
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '01_011');
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      verifyNever(
        () => repository.searchItems(
          q: any(named: 'q'),
          limit: any(named: 'limit'),
        ),
      );
    },
  );
}
