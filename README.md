# Invoice Generator — Mobile

Build an invoice from line items with tax and discount, then copy a plain-text version.

Part of [Chaowalit Greepoke](https://bookchaowalit.com)'s 101 Portfolio Projects.

## Features

- Line items with quantity and unit price
- Discount percentage and tax rate applied in integer cents
- Plain-text invoice preview you can copy

The invoice being edited (header, rates and line items) is saved on this
device with `shared_preferences` and restored on launch; "Start a new
invoice" clears it. There is no account, backend, analytics or network access.

## Tech Stack

- **Framework:** Flutter (CI pinned to 3.47.5) + Material 3
- **Language:** Dart
- **State:** `StatefulWidget` / `setState`; the core logic is pure Dart in
  `lib/logic/` and unit-tested without widgets
- **Persistence:** `shared_preferences` behind a small `DraftRepository`
  interface in `lib/data/` (in-memory implementation for tests)

## Develop and verify

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter run
```

CI (`.github/workflows/build.yml`) runs the same format/analyze/test checks
and fails closed; a debug APK is built on pushes to `main`.

## Build

```bash
# Android
flutter build apk --debug
```

Release builds (`flutter build apk --release` / `appbundle`) fail on purpose
until signing is configured; they never fall back to the debug key. To sign,
create an upload keystore outside the repo and add the ignored
`android/key.properties`:

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

Never commit `key.properties` or keystores (both are git-ignored).

## Related

- **Frontend:** [bookchaowalit-website/invoice-generator-frontend](https://github.com/bookchaowalit-website/invoice-generator-frontend)
- **Portfolio:** [bookchaowalit.com](https://bookchaowalit.com)

## License

MIT
