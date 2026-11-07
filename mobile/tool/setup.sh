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

# `flutter create` only grants internet access to debug builds, so a release
# build could not reach the server without this.
MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  sed -i.bak 's|<application|<uses-permission android:name="android.permission.INTERNET"/>\n    <application|' "$MANIFEST"
  rm -f "$MANIFEST.bak"
fi
sed -i.bak 's|android:label="companion"|android:label="Companion"|' "$MANIFEST"
rm -f "$MANIFEST.bak"

# `flutter create` writes a stock Info.plist. On a physical iPhone, reaching a
# dev server on the LAN needs this key or iOS silently refuses the connection.
PLIST=ios/Runner/Info.plist
if ! /usr/libexec/PlistBuddy -c "Print :NSLocalNetworkUsageDescription" "$PLIST" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Add :NSLocalNetworkUsageDescription string 'Companion connects to your local development server to load activities and profiles.'" "$PLIST"
fi

# Profile photos come from the gallery or camera; iOS closes an app that asks
# for either without saying why.
if ! /usr/libexec/PlistBuddy -c "Print :NSCameraUsageDescription" "$PLIST" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Add :NSCameraUsageDescription string 'Companion uses the camera so you can take a profile photo.'" "$PLIST"
fi
if ! /usr/libexec/PlistBuddy -c "Print :NSPhotoLibraryUsageDescription" "$PLIST" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Add :NSPhotoLibraryUsageDescription string 'Companion lets you choose a profile photo from your library.'" "$PLIST"
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
