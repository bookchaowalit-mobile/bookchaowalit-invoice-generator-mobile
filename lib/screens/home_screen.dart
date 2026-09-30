import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/draft_repository.dart';
import '../logic/invoice.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.clock = DateTime.now, this.repository});

  final DateTime Function() clock;

  /// Where the draft is stored. Defaults to an in-memory store (tests); the
  /// app passes [deviceDraftRepository].
  final DraftRepository? repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<LineItem> _items = [];
  final _number = TextEditingController(text: 'INV-0001');
  final _billTo = TextEditingController();
  final _desc = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _discount = TextEditingController();
  final _tax = TextEditingController(text: '7');
  String? _itemError;
  late final DraftRepository _repository =
      widget.repository ?? InMemoryDraftRepository();
  bool _loading = true;
  String? _storageError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final draft = await _repository.load();
      if (!mounted) return;
      setState(() {
        if (draft != null) _apply(draft);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _storageError = 'The saved invoice could not be read.';
      });
    }
  }

  void _apply(InvoiceDraft draft) {
    _number.text = draft.number;
    _billTo.text = draft.billTo;
    _discount.text = draft.discount;
    _tax.text = draft.tax;
    _items
      ..clear()
      ..addAll(draft.items);
  }

  InvoiceDraft get _draft => InvoiceDraft(
        number: _number.text,
        billTo: _billTo.text,
        discount: _discount.text,
        tax: _tax.text,
        items: List.of(_items),
      );

  Future<void> _persist() async {
    if (_loading) return;
    try {
      await _repository.save(_draft);
      if (mounted && _storageError != null) {
        setState(() => _storageError = null);
      }
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _storageError = 'Could not save the invoice on this device.');
    }
  }

  void _newInvoice() {
    setState(() {
      _apply(InvoiceDraft(number: _number.text, tax: _tax.text));
      _itemError = null;
    });
    _persist();
  }

  @override
  void dispose() {
    for (final c in [_number, _billTo, _desc, _qty, _price, _discount, _tax]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    final qty = parseQuantity(_qty.text);
    final price = parseMoneyCents(_price.text);
    String? error;
    if (_desc.text.trim().isEmpty) {
      error = 'Add a description';
    } else if (qty == null) {
      error = 'Quantity must be a whole number from 1 to $maxQuantity';
    } else if (price == null) {
      error = 'Enter a price like 49.99';
    }
    setState(() {
      _itemError = error;
      if (error != null) return;
      _items.add(
        LineItem(
          description: _desc.text,
          quantity: qty!,
          unitPriceCents: price!,
        ),
      );
      _desc.clear();
      _qty.text = '1';
      _price.clear();
    });
    if (error == null) _persist();
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? key,
    String? error,
    TextInputType? keyboard,
  }) {
    return TextField(
      key: key == null ? null : Key(key),
      controller: c,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) {
        setState(() {});
        _persist();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final discount = parsePercentBasisPoints(_discount.text);
    final tax = parsePercentBasisPoints(_tax.text);
    const decimal = TextInputType.numberWithOptions(decimal: true);
    final ratesOk = discount != null && tax != null;
    final totals = ratesOk
        ? computeTotals(
            _items,
            discountBasisPoints: discount,
            taxBasisPoints: tax,
          )
        : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Generator'),
        actions: [
          IconButton(
            key: const Key('new-invoice'),
            tooltip: 'Start a new invoice',
            icon: const Icon(Icons.note_add_outlined),
            onPressed: _loading ? null : _newInvoice,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_storageError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _storageError!,
                key: const Key('storage-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Row(
            children: [
              Expanded(child: _field(_number, 'Invoice #')),
              const SizedBox(width: 8),
              Expanded(child: _field(_billTo, 'Bill to')),
            ],
          ),
          const SizedBox(height: 16),
          Text('Line items', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          _field(_desc, 'Description', key: 'desc-input'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _field(
                  _qty,
                  'Qty',
                  key: 'qty-input',
                  keyboard: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _field(
                  _price,
                  'Unit price',
                  key: 'price-input',
                  keyboard: decimal,
                ),
              ),
              IconButton(
                key: const Key('add-item'),
                tooltip: 'Add line item',
                icon: const Icon(Icons.add_circle),
                onPressed: _addItem,
              ),
            ],
          ),
          if (_itemError != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _itemError!,
                key: const Key('item-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          for (final item in _items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.description),
              subtitle: Text(
                '${item.quantity} x ${formatMoney(item.unitPriceCents)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(formatMoney(item.amountCents)),
                  IconButton(
                    tooltip: 'Remove ${item.description}',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() => _items.remove(item));
                      _persist();
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _field(
                  _discount,
                  'Discount %',
                  key: 'discount-input',
                  keyboard: decimal,
                  error: discount == null ? '0-100' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _field(
                  _tax,
                  'Tax %',
                  key: 'tax-input',
                  keyboard: decimal,
                  error: tax == null ? '0-100' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (totals != null) ...[
            Text(
              'Total ${formatMoney(totals.totalCents)}',
              key: const Key('total'),
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Preview', style: textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy invoice text',
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _render(discount!, tax!)),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invoice copied')),
                    );
                  },
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: SelectableText(
                _render(discount!, tax!),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _render(int discount, int tax) => renderPlainText(
        invoiceNumber: _number.text,
        billTo: _billTo.text,
        date: widget.clock(),
        items: _items,
        discountBasisPoints: discount,
        taxBasisPoints: tax,
      );
}
