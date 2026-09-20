#!/bin/bash
# Builds LazyNotch and runs it from LazyNotch.app with a STABLE code identity.
#
# Why: TCC (privacy permissions) binds grants to the app's code identity. Ad-hoc
# signed binaries without a designated requirement are identified by their exact
# hash, so every `swift build` invalidates previously-granted Calendar/Camera
# permissions. Signing with an explicit designated requirement
# (`identifier "com.lazynotch.app"`) makes TCC key the grant on the bundle
# identifier instead — one grant, survives all rebuilds.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> swift build (release)"
swift build -c release

echo "==> installing binary into LazyNotch.app"
cp -f .build/release/LazyNotch LazyNotch.app/Contents/MacOS/LazyNotch

# Sign with the Apple Development identity (stable Team ID) so TCC permission
# grants (Calendar, Camera) survive rebuilds. Falls back to ad-hoc if absent,
# but ad-hoc grants are invalidated by every rebuild (cdhash changes).
IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/{print $2; exit}')
if [ -n "${IDENTITY:-}" ]; then
  echo "==> codesigning with: $IDENTITY"
  codesign --force --options runtime --entitlements Entitlements.plist --sign "$IDENTITY" LazyNotch.app
else
  echo "==> no Apple Development identity found; using ad-hoc (permissions won't persist across rebuilds)"
  codesign --force --entitlements Entitlements.plist --sign - --identifier com.lazynotch.app LazyNotch.app
fi

echo "==> restarting LazyNotch"
pkill -x LazyNotch 2>/dev/null || true
sleep 1
open LazyNotch.app

echo "==> done. If permissions were granted to the old binary, reset once:"
echo "    tccutil reset Calendar com.lazynotch.app && tccutil reset Camera com.lazynotch.app"
echo "    then re-grant in System Settings — this grant will now stick."
