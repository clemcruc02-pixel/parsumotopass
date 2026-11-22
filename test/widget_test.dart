import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parsu_motopass/data/app_state.dart';
import 'package:parsu_motopass/main.dart';
import 'package:parsu_motopass/screens/apply_screens.dart';
import 'package:parsu_motopass/widgets/common.dart';

void main() {
  setUp(AppState.instance.logout);

  testWidgets('Review keeps the original name on Back and refreshes on Save',
      (tester) async {
    final state = AppState.instance;
    state
      ..fullName = 'Original Student'
      ..studentId = '123456'
      ..course = 'BSCS'
      ..yearSection = '3A'
      ..contact = '09000000000'
      ..address = 'Test Address'
      ..plateNo = 'ABC123'
      ..color = 'Blue'
      ..brandModel = 'Test Motorcycle'
      ..orCrNo = 'TEST123';
    for (final slot in state.uploads.where((slot) => slot.required)) {
      state.markUploaded(slot, 'test-document.jpg');
    }

    await tester.pumpWidget(const MaterialApp(home: ReviewScreen()));

    Future<void> editName(String name) async {
      final edit = find.widgetWithText(SectionLabel, 'STUDENT');
      await tester.tap(find.descendant(of: edit, matching: find.text('Edit')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, name);
    }

    await editName('Discarded Student');
    await tester.tap(find.descendant(
      of: find.byType(BottomActionBar),
      matching: find.text('Back'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Original Student'), findsOneWidget);
    expect(state.fullName, 'Original Student');

    await editName('Updated Student');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Updated Student'), findsOneWidget);
    expect(state.fullName, 'Updated Student');
  });

  testWidgets('Login screen shows and navigates to Home', (tester) async {
    await tester.pumpWidget(const MotopassApp(demo: true));

    expect(find.text('ParSU Motopass'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);

    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), '202410654');
    await tester.enterText(fields.at(1), 'secret123');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('No active application'), findsOneWidget);
    expect(find.text('Apply now'), findsOneWidget);
  });

  testWidgets('Full apply flow: requirements -> submit -> tracking -> release',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MotopassApp(demo: true));
    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), '202410654');
    await tester.enterText(fields.at(1), 'secret123');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    Future<void> tapText(String t) async {
      await tester.tap(find.text(t).last);
      await tester.pumpAndSettle();
    }

    await tapText('Apply now');
    await tapText('Continue');
    await tapText('Not owned by me');
    await tapText('Next'); // ownership
    expect(find.text('OWNER DOCUMENTS'), findsOneWidget);
    await tapText('Next'); // checklist

    // Step 1
    for (var i = 0; i < 6; i++) {
      await tester.enterText(find.byType(EditableText).at(i), 'x$i');
    }
    await tapText('Next');

    // Step 2 (5 fields because not owned)
    for (var i = 0; i < 5; i++) {
      await tester.enterText(find.byType(EditableText).at(i), 'v$i');
    }
    await tapText('Next');

    // Leave the optional motorcycle photo empty.
    final requiredSlots = AppState.instance.uploads.where((slot) => slot.required);
    for (final slot in requiredSlots) {
      final card = find.ancestor(
        of: find.text('${slot.label} *'),
        matching: find.byType(OutlinedCard),
      );
      final button = find.descendant(
        of: card,
        matching: find.widgetWithText(TextButton, 'Upload'),
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tapText('Choose from gallery');
    }
    await tapText('Next');

    // Step 4
    expect(find.text('Review'), findsOneWidget);
    await tapText('Looks good');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tapText('Submit');
    expect(find.text('MS-2026-00123'), findsOneWidget);

    await tapText('Track application');
    expect(find.text('Tracking'), findsOneWidget);
    await tapText('Simulate next status (demo)');
    await tapText('Simulate next status (demo)');
    await tapText('View pickup details ›');
    expect(find.text('Ready for pickup'), findsOneWidget);
  });
}
