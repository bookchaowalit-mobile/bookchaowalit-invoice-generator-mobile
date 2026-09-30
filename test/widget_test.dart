import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_generator/main.dart';
import 'package:invoice_generator/screens/home_screen.dart';

void main() {
  testWidgets('Invoice Generator app builds with about tab', (tester) async {
    await tester.pumpWidget(const InvoiceGeneratorApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Invoice Generator'), findsWidgets);
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('Features'), findsOneWidget);
  });

  testWidgets('adding items updates the total', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(clock: () => DateTime(2026, 9, 30))),
    );
    String total() => tester.widget<Text>(find.byKey(const Key('total'))).data!;
    expect(total(), 'Total 0.00');

    await tester.tap(find.byKey(const Key('add-item')));
    await tester.pump();
    expect(find.text('Add a description'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('desc-input')), 'Logo');
    await tester.enterText(find.byKey(const Key('qty-input')), '2');
    await tester.enterText(find.byKey(const Key('price-input')), '50');
    await tester.tap(find.byKey(const Key('add-item')));
    await tester.pump();
    expect(total(), 'Total 107.00'); // 100 + 7% tax

    await tester.enterText(find.byKey(const Key('discount-input')), '10');
    await tester.pump();
    expect(total(), 'Total 96.30');

    await tester.enterText(find.byKey(const Key('tax-input')), '101');
    await tester.pump();
    expect(find.byKey(const Key('total')), findsNothing);
  });
}
