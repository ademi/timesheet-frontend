import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/views/staff_record_visit_dialog.dart';

final _now = DateTime(2026, 9, 1, 9);

VisitOut _visit({
  String status = 'scheduled',
  DateTime? scheduledStart,
  DateTime? scheduledEnd,
  DateTime? clockInAt,
  DateTime? clockOutAt,
  List<VisitFormRequirement> formRequirements = const [],
  List<VisitFormSubmissionOut> formSubmissions = const [],
  String? supportItemCode,
}) {
  final start = scheduledStart ?? _now;
  return VisitOut(
    id: 'visit-1',
    tenantId: 'tenant-1',
    jobId: 'job-1',
    contractorId: 'contractor-1',
    contractorName: 'Alex Morgan',
    jobTitle: 'Community access',
    scheduledStart: start,
    scheduledEnd: scheduledEnd ?? start.add(const Duration(hours: 2)),
    status: status,
    source: 'manual',
    latitude: 0,
    longitude: 0,
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    paymentStatus: 'unpaid',
    createdAt: start,
    updatedAt: start,
    clockInAt: clockInAt,
    clockOutAt: clockOutAt,
    formRequirements: formRequirements,
    formSubmissions: formSubmissions,
    supportItemCode: supportItemCode,
  );
}

void main() {
  testWidgets('full-screen Record visit shows app bar title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showStaffRecordVisitDialog(
                    context: context,
                    visit: _visit(),
                    onSubmit: ({
                      required clockInAt,
                      required clockOutAt,
                      required reason,
                    }) async => true,
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Record visit'), findsWidgets);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('submit with reason calls onSubmit and pops', (tester) async {
    AdminRecordVisitRequest? captured;
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showStaffRecordVisitDialog(
                    context: context,
                    visit: _visit(
                      scheduledStart: DateTime(2026, 9, 1, 9),
                      scheduledEnd: DateTime(2026, 9, 1, 11),
                    ),
                    onSubmit: ({
                      required clockInAt,
                      required clockOutAt,
                      required reason,
                    }) async {
                      captured = AdminRecordVisitRequest(
                        visitId: 'visit-1',
                        clockInAt: clockInAt,
                        clockOutAt: clockOutAt,
                        reason: reason,
                      );
                      return true;
                    },
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Paper timesheet',
    );
    await tester.tap(find.text('Record visit').last);
    await tester.pumpAndSettle();
    expect(captured?.reason, 'Paper timesheet');
    expect(find.text('open'), findsOneWidget);
  });

  test('defaultRecordArrival prefers clockInAt', () {
    final visit = _visit(
      scheduledStart: DateTime(2026, 9, 1, 8),
      scheduledEnd: DateTime(2026, 9, 1, 9),
      clockInAt: DateTime(2026, 9, 1, 8, 7),
      status: 'checked_in',
    );
    expect(defaultRecordArrival(visit).hour, 8);
    expect(defaultRecordArrival(visit).minute, 7);
  });

  test('defaultRecordArrival falls back to scheduled', () {
    final visit = _visit(
      scheduledStart: DateTime(2026, 9, 1, 9),
      scheduledEnd: DateTime(2026, 9, 1, 11),
    );
    expect(defaultRecordArrival(visit).hour, 9);
    expect(defaultRecordDeparture(visit).hour, 11);
  });

  testWidgets('Before you record panel when forms and NDIS missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showStaffRecordVisitDialog(
                    context: context,
                    visit: _visit(
                      formRequirements: const [
                        VisitFormRequirement(
                          formTemplateId: 'f1',
                          name: 'Progress report',
                          isRequired: true,
                        ),
                      ],
                      supportItemCode: null,
                    ),
                    onSubmit: ({
                      required clockInAt,
                      required clockOutAt,
                      required reason,
                    }) async => true,
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Before you record'), findsOneWidget);
    expect(find.textContaining('Progress report'), findsOneWidget);
    expect(find.textContaining('NDIS support item'), findsOneWidget);
  });
}
