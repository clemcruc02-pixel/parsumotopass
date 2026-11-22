import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parsu_motopass/widgets/common.dart';

void main() {
  testWidgets('Shared actions expose labels and Android touch targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Column(
              children: [
                PageHeader(
                  title: 'Tracking',
                  showBack: true,
                  actions: [AlertBell(onTap: () {})],
                ),
                PrimaryButton(label: 'Track application', onPressed: () {}),
              ],
            ),
          ),
        ),
      );
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byTooltip('Alerts, new updates'), findsOneWidget);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
