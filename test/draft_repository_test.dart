import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_generator/data/draft_repository.dart';
import 'package:invoice_generator/logic/invoice.dart';
import 'package:invoice_generator/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final draft = InvoiceDraft(
    number: 'INV-0042',
    billTo: 'Acme Co',
    discount: '10',
    tax: '7',
    items: [LineItem(description: 'Logo', quantity: 2, unitPriceCents: 5000)],
  );
  const repo = SharedPreferencesDraftRepository();
  const key = 'invoice_generator_draft_v1';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('round-trips the draft through shared_preferences', () async {
    await repo.save(draft);
    final loaded = await repo.load();
    expect(loaded!.toJson(), draft.toJson());
  });

  test('empty storage loads null', () async {
    expect(await repo.load(), isNull);
  });

  test('skips malformed line items and rejects non-object payloads', () async {
    final json = draft.toJson()
      ..['items'] = [
        {'description': 'Logo', 'quantity': 2, 'unitPriceCents': 5000},
        {'description': 'Bad', 'quantity': 0, 'unitPriceCents': 1},
        {'description': 'Bad', 'quantity': 'x'},
        7,
      ];
    SharedPreferences.setMockInitialValues({key: jsonEncode(json)});
    expect((await repo.load())!.items, hasLength(1));

    SharedPreferences.setMockInitialValues({key: '[]'});
    expect(repo.load(), throwsFormatException);
  });

  Future<void> pumpHome(WidgetTester tester, DraftRepository repo) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          clock: () => DateTime(2026, 9, 30),
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String total(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('total'))).data!;

  testWidgets('restores a saved draft and saves edits', (tester) async {
    final memory = InMemoryDraftRepository(draft);
    await pumpHome(tester, memory);
    expect(find.text('Logo'), findsOneWidget);
    expect(total(tester), 'Total 96.30');

    await tester.enterText(find.byKey(const Key('tax-input')), '0');
    await tester.pump();
    expect((await memory.load())!.tax, '0');

    await tester.tap(find.byTooltip('Remove Logo'));
    await tester.pumpAndSettle();
    expect((await memory.load())!.items, isEmpty);
  });

  testWidgets('new invoice clears items but keeps number and tax',
      (tester) async {
    final memory = InMemoryDraftRepository(draft);
    await pumpHome(tester, memory);
    await tester.tap(find.byKey(const Key('new-invoice')));
    await tester.pumpAndSettle();
    final saved = (await memory.load())!;
    expect(saved.items, isEmpty);
    expect(saved.billTo, '');
    expect(saved.discount, '');
    expect(saved.number, 'INV-0042');
    expect(saved.tax, '7');
  });

  testWidgets('shows an error when the saved invoice cannot be read',
      (tester) async {
    await pumpHome(tester, _FailingRepository());
    expect(find.byKey(const Key('storage-error')), findsOneWidget);
  });
}

class _FailingRepository implements DraftRepository {
  @override
  Future<InvoiceDraft?> load() async => throw const FormatException('bad');

  @override
  Future<void> save(InvoiceDraft draft) async => throw StateError('full');
}
