/// Persistence for the invoice draft.
///
/// The UI depends only on [DraftRepository]; the app wires in
/// [SharedPreferencesDraftRepository] and tests use [InMemoryDraftRepository].
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logic/invoice.dart';

abstract interface class DraftRepository {
  /// Returns the saved draft, or null when nothing has been saved yet.
  Future<InvoiceDraft?> load();
  Future<void> save(InvoiceDraft draft);
}

/// Stores the draft as one JSON object under [storageKey].
class SharedPreferencesDraftRepository implements DraftRepository {
  const SharedPreferencesDraftRepository({
    this.storageKey = 'invoice_generator_draft_v1',
  });

  final String storageKey;

  @override
  Future<InvoiceDraft?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString(storageKey);
    if (payload == null || payload.isEmpty) return null;
    final decoded = jsonDecode(payload);
    if (decoded is! Map) {
      throw const FormatException('Saved invoice is not an object.');
    }
    return InvoiceDraft.fromJson(Map<String, Object?>.from(decoded));
  }

  @override
  Future<void> save(InvoiceDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(storageKey, jsonEncode(draft.toJson()));
    if (!ok) throw StateError('The device did not save the invoice.');
  }
}

class InMemoryDraftRepository implements DraftRepository {
  InMemoryDraftRepository([this._draft]);

  InvoiceDraft? _draft;

  @override
  Future<InvoiceDraft?> load() async => _draft;

  @override
  Future<void> save(InvoiceDraft draft) async => _draft = draft;
}

const DraftRepository deviceDraftRepository =
    SharedPreferencesDraftRepository();
