import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';
import 'package:rostiq/features/billing/data/repositories/ndis_catalogue_repository.dart';
import 'package:rostiq/shared/widgets/ndis_support_item_picker.dart';

class _MockNdisCatalogueRepository extends Mock
    implements NdisCatalogueRepository {}

const _item = NdisCatalogueItemOut(
  supportItemNumber: '01_011_0107_1_1',
  supportItemName: 'Assistance With Self-Care Activities - Standard - Weekday Daytime',
  unit: 'H',
);

class _Harness extends StatefulWidget {
  const _Harness({
    required this.repository,
    this.initialCode,
    this.initialName,
    this.onChanged,
  });

  final NdisCatalogueRepository repository;
  final String? initialCode;
  final String? initialName;
  final void Function(String? code, String? name)? onChanged;

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

  setUp(() {
    repository = _MockNdisCatalogueRepository();
  });

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
      _Harness(
        repository: repository,
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
      () => repository.searchItems(q: any(named: 'q'), limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => const NdisCatalogueSearchResponse(
        q: 'self care',
        limit: 20,
        items: [_item],
      ),
    );

    String? pickedCode;
    String? pickedName;

    await tester.pumpWidget(
      _Harness(
        repository: repository,
        onChanged: (code, name) {
          pickedCode = code;
          pickedName = name;
        },
      ),
    );

    await tester.enterText(find.byType(TextField), 'self care');
    await tester.pump();
    await tester.pump();

    expect(find.text(_item.supportItemName), findsWidgets);
    await tester.tap(find.text(_item.supportItemNumber).last);
    await tester.pump();

    expect(pickedCode, _item.supportItemNumber);
    expect(pickedName, _item.supportItemName);
    expect(find.text(_item.supportItemName), findsOneWidget);
    expect(find.byTooltip('Clear support item'), findsOneWidget);
    verify(
      () => repository.searchItems(q: 'self care', limit: 20),
    ).called(1);
  });

  testWidgets('select survives field blur before tap (web gesture order)', (
    tester,
  ) async {
    when(
      () => repository.searchItems(q: any(named: 'q'), limit: any(named: 'limit')),
    ).thenAnswer(
      (_) async => const NdisCatalogueSearchResponse(
        q: '01_011',
        limit: 20,
        items: [_item],
      ),
    );

    String? pickedCode;
    String? pickedName;

    await tester.pumpWidget(
      _Harness(
        repository: repository,
        onChanged: (code, name) {
          pickedCode = code;
          pickedName = name;
        },
      ),
    );

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
  });

  testWidgets('clear in search mode sends null pair', (tester) async {
    String? clearedCode = 'keep';
    String? clearedName = 'keep';

    await tester.pumpWidget(
      _Harness(
        repository: repository,
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
      _Harness(
        repository: repository,
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
      _Harness(
        repository: repository,
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
}
