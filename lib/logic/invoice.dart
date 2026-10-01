/// Invoice maths in integer cents plus a plain-text renderer.
library;

import 'package:characters/characters.dart';

class LineItem {
  LineItem({
    required String description,
    required this.quantity,
    required this.unitPriceCents,
  }) : description = description.trim() {
    if (quantity < 1) throw ArgumentError.value(quantity, 'quantity');
    if (unitPriceCents < 0) {
      throw ArgumentError.value(unitPriceCents, 'unitPriceCents');
    }
  }

  final String description;
  final int quantity;
  final int unitPriceCents;

  int get amountCents => quantity * unitPriceCents;

  Map<String, Object?> toJson() => {
        'description': description,
        'quantity': quantity,
        'unitPriceCents': unitPriceCents,
      };

  /// Throws on wrong types or invalid quantity/price.
  static LineItem fromJson(Map<String, Object?> json) => LineItem(
        description: json['description'] as String,
        quantity: json['quantity'] as int,
        unitPriceCents: json['unitPriceCents'] as int,
      );
}

/// The invoice being edited: header fields, rate inputs (as typed) and items.
class InvoiceDraft {
  const InvoiceDraft({
    this.number = 'INV-0001',
    this.billTo = '',
    this.discount = '',
    this.tax = '7',
    this.items = const [],
  });

  final String number;
  final String billTo;

  /// Discount and tax are kept as the user typed them so an in-progress,
  /// not-yet-valid value is restored exactly.
  final String discount;
  final String tax;
  final List<LineItem> items;

  Map<String, Object?> toJson() => {
        'number': number,
        'billTo': billTo,
        'discount': discount,
        'tax': tax,
        'items': [for (final i in items) i.toJson()],
      };

  /// Malformed line items are skipped; a malformed header throws.
  static InvoiceDraft fromJson(Map<String, Object?> json) {
    final items = <LineItem>[];
    for (final raw in (json['items'] as List? ?? const []).whereType<Map>()) {
      try {
        items.add(LineItem.fromJson(Map<String, Object?>.from(raw)));
      } on TypeError {
        continue;
      } on ArgumentError {
        continue;
      }
    }
    return InvoiceDraft(
      number: json['number'] as String? ?? 'INV-0001',
      billTo: json['billTo'] as String? ?? '',
      discount: json['discount'] as String? ?? '',
      tax: json['tax'] as String? ?? '7',
      items: items,
    );
  }
}

class InvoiceTotals {
  const InvoiceTotals({
    required this.subtotalCents,
    required this.discountCents,
    required this.taxCents,
    required this.totalCents,
  });

  final int subtotalCents;
  final int discountCents;
  final int taxCents;
  final int totalCents;
}

/// Rounds `value * basisPoints / 10000` half-up (value >= 0).
int _applyBasisPoints(int value, int basisPoints) =>
    (value * basisPoints + 5000) ~/ 10000;

/// Discount is applied to the subtotal first, then tax to the discounted
/// amount. Rates are in basis points (1% = 100) so 7.5% is exact.
InvoiceTotals computeTotals(
  List<LineItem> items, {
  int discountBasisPoints = 0,
  int taxBasisPoints = 0,
}) {
  if (discountBasisPoints < 0 || discountBasisPoints > 10000) {
    throw ArgumentError.value(discountBasisPoints, 'discountBasisPoints');
  }
  if (taxBasisPoints < 0 || taxBasisPoints > 10000) {
    throw ArgumentError.value(taxBasisPoints, 'taxBasisPoints');
  }
  final subtotal = items.fold<int>(0, (s, i) => s + i.amountCents);
  final discount = _applyBasisPoints(subtotal, discountBasisPoints);
  final taxable = subtotal - discount;
  final tax = _applyBasisPoints(taxable, taxBasisPoints);
  return InvoiceTotals(
    subtotalCents: subtotal,
    discountCents: discount,
    taxCents: tax,
    totalCents: taxable + tax,
  );
}

/// Commas only as thousands separators: `1,234.56` is fine, but `12,50`
/// must not silently become 1250.
final _moneyPattern = RegExp(r'^(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{0,2})?$');

/// Parses `12`, `12.5`, `1,234.56` into cents; null if invalid, negative or
/// using a comma as the decimal separator (`12,50`).
int? parseMoneyCents(String input) {
  final trimmed = input.trim();
  if (!_moneyPattern.hasMatch(trimmed)) return null;
  final m = RegExp(r'^(\d{1,9})(?:\.(\d{0,2}))?$')
      .firstMatch(trimmed.replaceAll(',', ''));
  if (m == null) return null;
  return int.parse(m.group(1)!) * 100 +
      int.parse((m.group(2) ?? '').padRight(2, '0'));
}

/// Parses a percentage like `7`, `7.5`, `7.25` into basis points (0-10000).
int? parsePercentBasisPoints(String input) {
  final s = input.trim();
  if (s.isEmpty) return 0;
  // No commas at all: `7,5` used to be read as 75%.
  if (s.contains(',')) return null;
  final cents = parseMoneyCents(s);
  if (cents == null || cents > 10000) return null;
  return cents;
}

/// Largest quantity accepted for one line item.
const maxQuantity = 100000;

/// Parses a whole quantity from 1 to [maxQuantity] (plain digits only;
/// `int.tryParse` would also accept `0x10` or `+5`).
int? parseQuantity(String input) {
  final s = input.trim();
  if (!RegExp(r'^[0-9]{1,6}$').hasMatch(s)) return null;
  final q = int.parse(s);
  return q < 1 || q > maxQuantity ? null : q;
}

String formatMoney(int cents, {String currency = ''}) {
  final whole = (cents ~/ 100).toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );
  return '$currency$whole.${(cents % 100).toString().padLeft(2, '0')}';
}

String _pct(int bp) {
  final whole = bp ~/ 100;
  final frac = bp % 100;
  if (frac == 0) return '$whole%';
  return '$whole.${frac.toString().padLeft(2, '0').replaceAll(RegExp(r'0$'), '')}%';
}

/// Fixed-width plain-text invoice suitable for copying into a message.
String renderPlainText({
  required String invoiceNumber,
  required String billTo,
  required DateTime date,
  required List<LineItem> items,
  int discountBasisPoints = 0,
  int taxBasisPoints = 0,
}) {
  final t = computeTotals(
    items,
    discountBasisPoints: discountBasisPoints,
    taxBasisPoints: taxBasisPoints,
  );
  String two(int v) => v.toString().padLeft(2, '0');
  String row(String left, String right) =>
      '${left.padRight(28)}${right.padLeft(14)}';
  final b = StringBuffer()
    ..writeln('INVOICE ${invoiceNumber.trim()}')
    ..writeln('Date: ${date.year}-${two(date.month)}-${two(date.day)}')
    ..writeln('Bill to: ${billTo.trim().isEmpty ? '-' : billTo.trim()}')
    ..writeln('-' * 42);
  for (final i in items) {
    // Truncate by grapheme cluster so emoji and Thai marks are never cut in
    // half (substring on UTF-16 could leave a lone surrogate).
    final chars = i.description.characters;
    final desc = chars.length > 26 ? '${chars.take(25)}…' : i.description;
    b.writeln(row(desc, formatMoney(i.amountCents)));
    b.writeln('  ${i.quantity} x ${formatMoney(i.unitPriceCents)}');
  }
  b
    ..writeln('-' * 42)
    ..writeln(row('Subtotal', formatMoney(t.subtotalCents)));
  if (t.discountCents > 0) {
    b.writeln(
      row('Discount (${_pct(discountBasisPoints)})',
          '-${formatMoney(t.discountCents)}'),
    );
  }
  if (taxBasisPoints > 0) {
    b.writeln(row('Tax (${_pct(taxBasisPoints)})', formatMoney(t.taxCents)));
  }
  b.write(row('TOTAL', formatMoney(t.totalCents)));
  return b.toString();
}
