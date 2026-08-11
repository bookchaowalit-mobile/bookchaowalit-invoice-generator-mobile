import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_generator/main.dart';

void main() {
  testWidgets('Invoice Generator app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const InvoiceGeneratorApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Invoice Generator'), findsWidgets);
  });
}
