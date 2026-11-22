import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parsu_motopass/main.dart';

void main() {
  testWidgets('Login screen shows and navigates to Home', (tester) async {
    await tester.pumpWidget(const MotopassApp());

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

    await tester.pumpWidget(const MotopassApp());
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

    // Step 3: upload required files
    while (find.text('Upload').evaluate().length > 1) {
      // skip the header title "Upload"; tap first slot button still showing Upload
      final buttons = find.widgetWithText(TextButton, 'Upload');
      if (buttons.evaluate().isEmpty) break;
      await tester.tap(buttons.first);
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
