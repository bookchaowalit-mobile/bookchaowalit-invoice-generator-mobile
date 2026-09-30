import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_generator/logic/invoice.dart';

void main() {
  final items = [
    LineItem(description: 'Design', quantity: 3, unitPriceCents: 12000),
    LineItem(description: 'Hosting', quantity: 1, unitPriceCents: 999),
  ];

  test('line items validate and compute amounts', () {
    expect(items.first.amountCents, 36000);
    expect(
      () => LineItem(description: 'x', quantity: 0, unitPriceCents: 1),
      throwsArgumentError,
    );
    expect(
      () => LineItem(description: 'x', quantity: 1, unitPriceCents: -1),
      throwsArgumentError,
    );
  });

  test('discount before tax with half-up rounding', () {
    final t = computeTotals(
      items,
      discountBasisPoints: 1000,
      taxBasisPoints: 750,
    );
    expect(t.subtotalCents, 36999);
    expect(t.discountCents, 3700); // 3699.9
    expect(t.taxCents, 2497); // 33299 * 7.5% = 2497.425
    expect(t.totalCents, 36999 - 3700 + 2497);
  });

  test('no items and invalid rates', () {
    expect(computeTotals(const []).totalCents, 0);
    expect(
        () => computeTotals(items, taxBasisPoints: 10001), throwsArgumentError);
    expect(() => computeTotals(items, discountBasisPoints: -1),
        throwsArgumentError);
  });

  test('parsers', () {
    expect(parseMoneyCents('1,234.5'), 123450);
    expect(parseMoneyCents('0.99'), 99);
    expect(parseMoneyCents('-1'), isNull);
    expect(parseMoneyCents('1.999'), isNull);
    expect(parsePercentBasisPoints(''), 0);
    expect(parsePercentBasisPoints('7.5'), 750);
    expect(parsePercentBasisPoints('100'), 10000);
    expect(parsePercentBasisPoints('100.01'), isNull);
    expect(parsePercentBasisPoints('abc'), isNull);
  });

  test('formatMoney', () {
    expect(formatMoney(5), '0.05');
    expect(formatMoney(123456789, currency: r'$'), r'$1,234,567.89');
  });

  test('plain-text rendering', () {
    final text = renderPlainText(
      invoiceNumber: 'INV-7',
      billTo: 'ACME Ltd',
      date: DateTime(2026, 9, 30),
      items: items,
      discountBasisPoints: 1000,
      taxBasisPoints: 750,
    );
    final lines = text.split('\n');
    expect(lines.first, 'INVOICE INV-7');
    expect(lines[1], 'Date: 2026-09-30');
    expect(lines[2], 'Bill to: ACME Ltd');
    expect(text, contains('Discount (10%)'));
    expect(text, contains('Tax (7.5%)'));
    expect(lines.last, '${'TOTAL'.padRight(28)}${'357.96'.padLeft(14)}');
    for (final l in lines) {
      expect(l.length, lessThanOrEqualTo(42), reason: l);
    }
  });
}
