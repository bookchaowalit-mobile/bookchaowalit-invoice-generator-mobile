# Upgrade Plan — Invoice Generator Mobile

## Current state

Score: 6/10 — core feature implemented with tested pure-Dart logic and honest
CI; still session-only (no persistence) and release signing uses debug keys.

## Backlog

### P0
- Android release signing must fail closed: `android/app/build.gradle.kts`
  still signs `release` with the debug key. Mirror the `key.properties` guard
  used in `bookchaowalit-goal-tracker-mobile`.

### P1
- Persist user data locally (`shared_preferences`) with load/save error
  handling and tests.
- Set a real application ID (currently the template default) and app icon.
- Add a Maestro smoke flow for the main journey.

### P2
- Tablet layout (NavigationRail) and 130% text-scale widget test.
- Localisation (Thai/English) for UI strings.

## Done in this pass

- Replaced the Expo/npm CI (which could never fail) with fail-closed Flutter CI: `dart format` check, `flutter analyze`, `flutter test`, debug APK on `main`.
- Implemented the core feature (build an invoice from line items with tax and discount, then copy a plain-text version) with pure-Dart logic in `lib/logic/`.
- Replaced placeholder Explore/Profile tabs with an About screen describing features and privacy.
- Added unit tests for the logic and widget tests for the main journey.
- Removed unused `go_router` / `flutter_riverpod` dependencies; README now matches the code.
