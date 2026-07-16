#!/bin/bash
#
# apply_fork.sh <smarttube-clone-root> <fork-dir>
#
# Applies the OpenClaw SmartTube (YouTube) mode fork to a fresh milika/SmartTubeIOS clone on CI.
# SmartTubeIOS is a Swift package (subdir SmartTubeIOS/) — no app->framework conversion; OpenClaw
# depends on the package directly. The only fork is dropping the FirebaseCrashlytics dependency
# (replaced by an os.Logger stub). Everything it touches is inside the clone (runner-only).
#
set -euo pipefail

CLONE="$1"                 # e.g. $PWD/smarttube (repo root)
FORK="$2"                  # e.g. $PWD/openclaw/Modes/SmartTube/fork
PKG="$CLONE/SmartTubeIOS"  # the SPM package dir (contains Package.swift)

echo "== apply_fork(SmartTube): clone=$CLONE =="
[ -f "$PKG/Package.swift" ] || { echo "ERROR: Package.swift not found at $PKG"; exit 1; }

# 1. Strip the firebase-ios-sdk dependency from Package.swift (the .package(url:...) entry and
#    the FirebaseCrashlytics product from the SmartTubeIOS target).
perl -0pi -e 's{\.package\(\s*url:\s*"https://github\.com/firebase/firebase-ios-sdk".*?\)\s*,?\s*}{}s' "$PKG/Package.swift"
perl -0pi -e 's{\s*,?\s*\.product\(\s*name:\s*"FirebaseCrashlytics"\s*,\s*package:\s*"firebase-ios-sdk"\s*\)}{}g' "$PKG/Package.swift"
if grep -q "firebase-ios-sdk" "$PKG/Package.swift"; then
  echo "ERROR: firebase-ios-sdk reference still present in Package.swift"; sed -n '1,80p' "$PKG/Package.swift"; exit 1
fi
echo "   stripped firebase-ios-sdk dependency + FirebaseCrashlytics product"

# 1b. Relax Swift language mode v6 -> v5. Upstream master trips the runner's newest-Xcode Swift 6
#     region-isolation checks ("sending 'x' risks data races") in files we don't touch; v5 mode
#     downgrades those to warnings (the code is the same one shipping on the App Store). Applies
#     to all targets that declare it.
perl -0pi -e 's/\.swiftLanguageMode\(\.v6\)/.swiftLanguageMode(.v5)/g' "$PKG/Package.swift"
echo "   relaxed swiftLanguageMode .v6 -> .v5"

# 2. Replace CrashlyticsLogger with the Firebase-free os.Logger stub (same public API).
cp "$FORK/CrashlyticsLogger.swift" "$PKG/Sources/SmartTubeIOS/Services/CrashlyticsLogger.swift"
echo "   replaced CrashlyticsLogger.swift with os.Logger stub"

# 3. Sanity: no residual Firebase coupling anywhere in the library sources.
if grep -rnE "import Firebase|Crashlytics\.crashlytics\(\)|FirebaseApp" "$PKG/Sources" ; then
  echo "ERROR: residual Firebase references remain in Sources/"; exit 1
fi
echo "== apply_fork(SmartTube): done =="
