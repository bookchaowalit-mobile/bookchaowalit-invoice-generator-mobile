# Upgrade Plan — Invoice Generator Mobile

## Current state

Score: 7.5/10 — integer-cent invoice with strict money/rate/quantity parsing, unicode-safe export, a11y guideline tests and fail-closed signing; no invoice history, PDF, icon or E2E flow yet.

## Backlog

### P0
- None open. (Release signing now fails closed without `android/key.properties`.)

### P1
- Keep a history of issued invoices and auto-increment the invoice number.
- Export/share the invoice as PDF (package:pdf + share sheet).
- Replace the template launcher icon with a real app icon (the application ID `com.bookchaowalit.*` is already set).
- Add a Maestro smoke flow for the main journey.
- Add a CI job that builds a signed release bundle from repository secrets (keystore decoded at runtime, never committed).

### P2
- Tablet layout (NavigationRail).
- Localisation (Thai/English) for UI strings.

## Done in this pass (pass 3)

- Bug fix: rates and prices stripped every comma, so a tax typed as `7,5` became **75%** and a price of `12,50` became 1,250.00. Commas are now only accepted as thousands separators in prices and not at all in percentages; such input shows the field error instead.
- Bug fix: the plain-text export truncated long descriptions with `substring(0, 25)`, which could cut an emoji in half (lone surrogate in the copied text); truncation now uses grapheme clusters (`characters`, now a direct dependency).
- Bug fix: quantity used `int.tryParse` (`0x10` → 16); new `parseQuantity` accepts plain digits 1–100,000 and the error names the range. The add-item error is a live region.
- Edge-case unit tests: decimal commas, percent bounds, quantity parsing, 100% discount, half-cent rounding and totals adding up across many prices, emoji/Thai truncation with a surrogate check, fractional percent labels, invalid line items. Widget tests: rejected comma/quantity input, a11y guidelines, 200% text scale at phone width.

## Done in pass 2

- Release builds no longer sign with the debug key: `android/app/build.gradle.kts` reads the ignored `android/key.properties` and a Gradle guard fails any release assemble/bundle without it (pattern from `bookchaowalit-goal-tracker-mobile`). Root `.gitignore` also ignores `key.properties`, `*.jks`, `*.keystore`; README documents the setup. Not build-verified here (no Android SDK/Gradle in this environment).
- The invoice draft (number, bill-to, discount/tax as typed, line items) now persists on device via `lib/data/draft_repository.dart` (`DraftRepository` interface, `shared_preferences` JSON store that skips malformed line items, in-memory store for tests); restored on launch, saved after every edit, error line when storage fails.
- Added a "Start a new invoice" action that clears items, bill-to and discount while keeping the number and tax rate.
- Added repository tests (round trip, empty, malformed items, non-object payload) and widget tests for restore/save, new invoice and load failure.

## Done in pass 1

- Replaced the Expo/npm CI (which could never fail) with fail-closed Flutter CI: `dart format` check, `flutter analyze`, `flutter test`, debug APK on `main`.
- Implemented the core feature (build an invoice from line items with tax and discount, then copy a plain-text version) with pure-Dart logic in `lib/logic/`.
- Replaced placeholder Explore/Profile tabs with an About screen describing features and privacy.
- Added unit tests for the logic and widget tests for the main journey.
- Removed unused `go_router` / `flutter_riverpod` dependencies; README now matches the code.
