#!/usr/bin/env bash
# Generates the android/ and ios/ platform folders for this project without
# clobbering the hand-written pubspec.yaml, then fetches packages.
set -euo pipefail

cd "$(dirname "$0")/.."

cp pubspec.yaml pubspec.yaml.bak

flutter create \
  --platforms=android,ios \
  --project-name companion \
  --org app.companion \
  --no-overwrite \
  .

# `flutter create` rewrites pubspec.yaml with its own template. Restore ours.
mv pubspec.yaml.bak pubspec.yaml

# `flutter create` writes a stock Info.plist. On a physical iPhone, reaching a
# dev server on the LAN needs this key or iOS silently refuses the connection.
PLIST=ios/Runner/Info.plist
if ! /usr/libexec/PlistBuddy -c "Print :NSLocalNetworkUsageDescription" "$PLIST" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Add :NSLocalNetworkUsageDescription string 'Companion connects to your local development server to load activities and profiles.'" "$PLIST"
fi

# `flutter create` also drops in its stock counter-app smoke test, which refers
# to a `MyApp` this project does not have. Left in place it fails to compile,
# and because `flutter test` builds the suite as a single kernel it takes
# unrelated test files down with it. The real smoke coverage lives in
# screens_test.dart and layout_resilience_test.dart.
rm -f test/widget_test.dart

flutter pub get

echo
echo "Mobile app ready. Run it with:"
echo "  flutter run --dart-define=API_BASE_URL=http://localhost:4000    # iOS simulator"
echo "  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000     # Android emulator"
