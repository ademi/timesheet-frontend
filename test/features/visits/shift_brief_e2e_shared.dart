/// Shared contractor shift-brief E2E body (Task 11 / CR4).
///
/// Used by:
/// - `test/features/visits/shift_brief_e2e_test.dart` (VM / CI)
/// - `integration_test/shift_brief_e2e_test.dart` (device when desktop deps present)
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/features/clients/data/models/support_plan_models.dart';
import 'package:rostiq/features/visits/controllers/visit_shift_brief_controller.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';
import 'package:rostiq/features/visits/widgets/shift_brief_panel.dart';

class MockVisitsRepositoryForShiftBriefE2e extends Mock
    implements VisitsRepository {}

/// Thin visit-detail slice: loads brief on mount, binds panel like production
/// ([ContractorVisitDetailView] brief wiring).
class VisitShiftBriefSlice extends StatefulWidget {
  const VisitShiftBriefSlice({super.key, required this.visitId});

  final String visitId;

  @override
  State<VisitShiftBriefSlice> createState() => _VisitShiftBriefSliceState();
}

class _VisitShiftBriefSliceState extends State<VisitShiftBriefSlice> {
  @override
  void initState() {
    super.initState();
    Get.find<VisitShiftBriefController>().load(widget.visitId);
  }

  @override
  Widget build(BuildContext context) {
    final briefCtrl = Get.find<VisitShiftBriefController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Visit detail')),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Assigned visit'),
            ShiftBriefPanel(
              brief: briefCtrl.brief.value,
              isLoading: briefCtrl.isLoading.value,
              errorMessage: briefCtrl.errorMessage.value,
            ),
            const Divider(height: 32),
            const Text('Tasks'),
          ],
        ),
      ),
    );
  }
}

const sampleShiftBriefForE2e = ShiftBriefDto(
  clientId: 'c1',
  clientName: 'Ada Lovelace',
  planBodyInvalid: false,
  allergies: 'Peanuts',
  accessNotes: 'Gate code 1234',
  goals: [
    {
      'ndis_goal': 'Cook independently',
      'strategy': 'Prompt fade',
      'worker_instructions': 'Use visual card',
      // Budget keys must never surface in contractor brief UI (CR4).
      'budget_core': '999',
      'Core budget': 'should not render',
    },
  ],
);

/// Registers GetX + mock repo and declares the CR4 widget test.
void declareShiftBriefContractorE2e() {
  late MockVisitsRepositoryForShiftBriefE2e mock;

  setUp(() {
    Get.reset();
    mock = MockVisitsRepositoryForShiftBriefE2e();
    when(() => mock.getVisitShiftBrief('v1'))
        .thenAnswer((_) async => sampleShiftBriefForE2e);
    Get.put(VisitShiftBriefController(repo: mock));
  });

  tearDown(Get.reset);

  testWidgets('contractor visit shows shift brief', (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(
        home: VisitShiftBriefSlice(visitId: 'v1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shift brief'), findsOneWidget);
    expect(find.textContaining('Use visual card'), findsOneWidget);
    expect(find.textContaining('Allergies: Peanuts'), findsOneWidget);
    expect(find.textContaining('Core budget'), findsNothing);
    expect(find.textContaining('budget_core'), findsNothing);
    verify(() => mock.getVisitShiftBrief('v1')).called(1);
  });
}
