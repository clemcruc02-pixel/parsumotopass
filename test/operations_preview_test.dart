import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parsu_motopass/screens/operations_preview.dart';

void main() {
  testWidgets('Student status shows a sample rejection reason', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OperationsPreview()));
    await tester.tap(find.text('DEMO-002'));
    await tester.pumpAndSettle();

    final reject = find.text('Reject request');
    await tester.ensureVisible(reject);
    await tester.tap(reject);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Registration is unreadable');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();

    final preview = find.text('Preview student status');
    await tester.ensureVisible(preview);
    await tester.tap(preview);
    await tester.pumpAndSettle();
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('Registration is unreadable'), findsOneWidget);
  });

  testWidgets('Operations preview verifies documents before approval', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OperationsPreview()));
    await tester.tap(find.text('DEMO-002'));
    await tester.pumpAndSettle();

    final approve = find.widgetWithText(FilledButton, 'Approve');
    expect(tester.widget<FilledButton>(approve).onPressed, isNull);
    for (final label in ['Student ID', 'ID photocopy', 'Registration (OR/CR)']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await tester.ensureVisible(approve);
    await tester.tap(approve);
    await tester.pumpAndSettle();
    expect(find.text('Mark ready for pickup'), findsOneWidget);
  });
}
