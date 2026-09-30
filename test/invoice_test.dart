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

  group('edge cases (pass 3)', () {
    test('a decimal comma is rejected, not read as a bigger number', () {
      expect(parseMoneyCents('12,50'), isNull); // used to be 1250.00
      expect(parseMoneyCents('1,2'), isNull);
      expect(parseMoneyCents('1,234,567.89'), 123456789);
      expect(parsePercentBasisPoints('7,5'), isNull); // used to be 75%
      expect(parsePercentBasisPoints('7.5'), 750);
      expect(parsePercentBasisPoints(' '), 0);
      expect(parsePercentBasisPoints('100'), 10000);
      expect(parsePercentBasisPoints('100.01'), isNull);
    });

    test('parseQuantity accepts 1..maxQuantity decimals only', () {
      expect(parseQuantity(' 1 '), 1);
      expect(parseQuantity('$maxQuantity'), maxQuantity);
      for (final bad in [
        '0',
        '-1',
        '+5',
        '0x10',
        '1.5',
        '',
        '${maxQuantity + 1}'
      ]) {
        expect(parseQuantity(bad), isNull, reason: bad);
      }
    });

    test('100% discount and 0% tax', () {
      final items = [
        LineItem(description: 'x', quantity: 3, unitPriceCents: 333)
      ];
      final t =
          computeTotals(items, discountBasisPoints: 10000, taxBasisPoints: 700);
      expect(t.discountCents, 999);
      expect(t.taxCents, 0);
      expect(t.totalCents, 0);
      expect(computeTotals(items).totalCents, 999);
    });

    test('rounding is half-up at the half cent and totals add up', () {
      // 1 cent at 50% discount -> 0.5 -> 1; tax 7% of 0 -> 0.
      final one = [LineItem(description: 'x', quantity: 1, unitPriceCents: 1)];
      expect(computeTotals(one, discountBasisPoints: 5000).discountCents, 1);
      for (var price = 0; price < 2000; price += 37) {
        final t = computeTotals(
          [LineItem(description: 'x', quantity: 3, unitPriceCents: price)],
          discountBasisPoints: 1250,
          taxBasisPoints: 725,
        );
        expect(t.subtotalCents - t.discountCents + t.taxCents, t.totalCents);
        expect(t.totalCents, greaterThanOrEqualTo(0));
      }
    });

    test('long emoji and Thai descriptions truncate on whole characters', () {
      final text = renderPlainText(
        invoiceNumber: '1',
        billTo: '',
        date: DateTime(2026),
        items: [
          LineItem(
            description: '😀' * 30,
            quantity: 1,
            unitPriceCents: 100,
          ),
          LineItem(
              description: 'ออกแบบโลโก้และนามบัตรสำหรับร้าน',
              quantity: 1,
              unitPriceCents: 1),
        ],
      );
      final line = text.split('\n')[4];
      expect(line, startsWith('${'😀' * 25}…'));
      // No lone surrogates anywhere in the output (substring(0, 25) used to
      // cut the 13th emoji in half).
      final units = text.codeUnits;
      for (var i = 0; i < units.length; i++) {
        final u = units[i];
        if (u >= 0xD800 && u <= 0xDBFF) {
          expect(units[i + 1], inInclusiveRange(0xDC00, 0xDFFF));
          i++;
        } else {
          expect(u, isNot(inInclusiveRange(0xDC00, 0xDFFF)));
        }
      }
      expect(text, contains('Bill to: -'));
    });

    test('percent labels for fractional rates', () {
      final items = [
        LineItem(description: 'x', quantity: 1, unitPriceCents: 10000)
      ];
      String render(int bp) => renderPlainText(
            invoiceNumber: '1',
            billTo: 'a',
            date: DateTime(2026),
            items: items,
            taxBasisPoints: bp,
          );
      expect(render(705), contains('Tax (7.05%)'));
      expect(render(710), contains('Tax (7.1%)'));
      expect(render(1), contains('Tax (0.01%)'));
    });

    test('line items reject zero quantity and negative prices', () {
      expect(
        () => LineItem(description: 'x', quantity: 0, unitPriceCents: 1),
        throwsArgumentError,
      );
      expect(
        () => LineItem(description: 'x', quantity: 1, unitPriceCents: -1),
        throwsArgumentError,
      );
    });
  });
}
