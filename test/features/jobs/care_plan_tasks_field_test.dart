import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/themes/app_colors.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';
import 'package:rostiq/features/billing/data/ndis_catalogue_filter_prefs.dart';
import 'package:rostiq/features/billing/data/repositories/ndis_catalogue_repository.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/utils/task_title_presets.dart';
import 'package:rostiq/features/jobs/widgets/care_plan_tasks_field.dart';

class _MockNdisCatalogueRepository extends Mock
    implements NdisCatalogueRepository {}

const _catalogueItem = NdisCatalogueItemOut(
  supportItemNumber: '01_011_0107_1_1',
  supportItemName:
      'Assistance With Self-Care Activities - Standard - Weekday Daytime',
  unit: 'H',
);

void main() {
  late _MockNdisCatalogueRepository catalogue;
  late Map<String, dynamic> filterBox;
  late RxList<TaskTemplateItem> tasks;
  late TextEditingController otherTitleCtrl;
  late RxBool showOtherTitleField;
  late List<({String code, String name})> cataloguePicks;

  setUp(() {
    catalogue = _MockNdisCatalogueRepository();
    filterBox = <String, dynamic>{};
    tasks = <TaskTemplateItem>[].obs;
    otherTitleCtrl = TextEditingController();
    showOtherTitleField = false.obs;
    cataloguePicks = [];
    when(() => catalogue.fetchAllActiveItems())
        .thenAnswer((_) async => const [_catalogueItem]);
  });

  tearDown(() {
    otherTitleCtrl.dispose();
  });

  NdisCatalogueFilterPrefs isolatedPrefs() => NdisCatalogueFilterPrefs(
        read: (key) => filterBox[key],
        write: (key, value) => filterBox[key] = value,
        remove: (key) => filterBox.remove(key),
      );

  Widget harness() {
    return GetMaterialApp(
      home: Scaffold(
        body: CarePlanTasksField(
          tasks: tasks,
          otherTitleCtrl: otherTitleCtrl,
          showOtherTitleField: showOtherTitleField,
          onPresetSelected: (_) {},
          onAppendOtherTitle: () {},
          onRemoveTask: (index) => tasks.removeAt(index),
          onCataloguePicked: ({required code, required name}) {
            cataloguePicks.add((code: code, name: name));
            tasks.add(
              TaskTemplateItem(
                title: name,
                supportItemCode: code,
                sortOrder: tasks.length,
              ),
            );
          },
          catalogueRepository: catalogue,
          filterPrefs: isolatedPrefs(),
        ),
      ),
    );
  }

  testWidgets('row shows title and muted catalogue code', (tester) async {
    tasks.add(
      const TaskTemplateItem(
        title: 'Self care',
        supportItemCode: '01_011_0107_1_1',
      ),
    );
    await tester.pumpWidget(harness());

    expect(find.text('Self care'), findsOneWidget);
    final code = tester.widget<Text>(find.text('01_011_0107_1_1'));
    expect(code.style?.color, AppColors.textMuted);
    expect(find.widgetWithText(TextField, 'Task titles (one per line)'),
        findsNothing);
  });

  testWidgets('remove drops the coded row', (tester) async {
    tasks.add(
      const TaskTemplateItem(
        title: 'Self care',
        supportItemCode: '01_011_0107_1_1',
      ),
    );
    await tester.pumpWidget(harness());

    await tester.tap(find.byKey(const ValueKey('remove-care-plan-task-0')));
    await tester.pumpAndSettle();

    expect(tasks, isEmpty);
    expect(find.text('Self care'), findsNothing);
  });

  testWidgets('Add from catalogue picks stamp code via picker dialog',
      (tester) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.byKey(const Key('add-from-catalogue')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('catalogue-task-picker-dialog')),
        matching: find.text(_catalogueItem.supportItemNumber),
      ),
    );
    await tester.pumpAndSettle();

    expect(cataloguePicks, hasLength(1));
    expect(cataloguePicks.single.code, '01_011_0107_1_1');
    expect(find.textContaining('Self-Care'), findsOneWidget);
  });

  testWidgets('preset Other is secondary to catalogue add', (tester) async {
    await tester.pumpWidget(harness());

    expect(find.text('Add from catalogue'), findsOneWidget);
    expect(find.text('Add preset task'), findsOneWidget);
    expect(find.text(taskTitlePresetOther), findsNothing);
  });
}
