#!/bin/bash
#
# apply_fork.sh <feather-clone-dir> <fork-dir>
#
# Applies the OpenClaw FeatherMode fork to a fresh Feather clone on CI. Everything
# it touches is inside the clone (runner-only). Feather uses Xcode 16 synchronized
# groups, so our NEW files go in a separate non-synced FeatherModule/ dir (added
# explicitly by the Ruby); only in-place edits touch files inside the synced tree.
#
set -euo pipefail

CLONE="$1"                              # e.g. $PWD/feather
FORK="$2"                               # e.g. $PWD/openclaw/Modes/Feather/fork
APP="$CLONE/Feather"                    # Feather's synced app source dir
MOD="$CLONE/FeatherModule"              # our non-synced additions

echo "== apply_fork(feather): clone=$CLONE fork=$FORK =="

# 1a. Our additions -> non-synced FeatherModule/ (added explicitly by the Ruby).
mkdir -p "$MOD"
cp "$FORK/../App/FeatherHost.swift" "$MOD/FeatherHost.swift"
cp "$FORK/FeatherLauncher.h"        "$MOD/FeatherLauncher.h"
cp "$FORK/FeatherLauncher.m"        "$MOD/FeatherLauncher.m"
cp "$FORK/Feather-umbrella.h"       "$MOD/Feather.h"
cp "$FORK/FeatherMode-Info.plist"   "$CLONE/FeatherMode-Info.plist"
echo "   FeatherModule/: FeatherHost.swift, FeatherLauncher.{h,m}, Feather.h (umbrella)"

# 1b. Data-isolation overlay -> in the synced tree (replaces original in place).
cp "$FORK/FileManager+documents.swift" "$APP/Extensions/FileManager+documents.swift"
echo "   overlaid FileManager+documents.swift (Documents/Feather/ isolation)"

# 2. Neutralize the SwiftUI app entry — @main is illegal in a framework.
perl -0pi -e 's/^\@main/\/\/ \@main (removed for FeatherMode framework)/m' "$APP/FeatherApp.swift"
echo "   neutralized @main in FeatherApp.swift"

# 3. FRCreateCGColorFromHex is declared `static` in iconPoc.h and defined `static`
#    in iconPoc.m, which forward-references it. A static decl in a modular umbrella
#    header is invalid, but simply deleting it breaks the .m. Make both non-static
#    (a normal exported helper) — module-clean and the forward reference resolves.
perl -0pi -e 's/static\s+(CGColorRef\s+FRCreateCGColorFromHex\s*\()/$1/g' "$APP/Utilities/iconPoc.h"
perl -0pi -e 's/static\s+(CGColorRef\s+FRCreateCGColorFromHex\s*\()/$1/g' "$APP/Utilities/iconPoc.m"
echo "   made FRCreateCGColorFromHex non-static in iconPoc.h + iconPoc.m"

# 4. Isolate Core Data: point the store at Documents/Feather/Feather.sqlite.
perl -0pi -e 's/(container = NSPersistentContainer\(name: _name\)\n)/$1\n\t\tif !inMemory {\n\t\t\tlet _dir = URL.documentsDirectory.appendingPathComponent("Feather", isDirectory: true)\n\t\t\ttry? FileManager.default.createDirectory(at: _dir, withIntermediateDirectories: true)\n\t\t\tcontainer.persistentStoreDescriptions.first?.url = _dir.appendingPathComponent("Feather.sqlite")\n\t\t}\n/' \
  "$APP/Backend/Storage/Storage.swift"
echo "   redirected Core Data store -> Documents/Feather/Feather.sqlite"

# 5. Convert the app target into Feather.framework.
ruby "$FORK/convert_to_framework.rb" "$CLONE/Feather.xcodeproj"

# 6. Repoint the shared "Feather" scheme's buildable to the framework product.
SCHEME="$CLONE/Feather.xcodeproj/xcshareddata/xcschemes/Feather.xcscheme"
if [ -f "$SCHEME" ]; then
  sed -i '' -e 's/BuildableName = "Feather.app"/BuildableName = "Feather.framework"/g' "$SCHEME"
  echo "   repointed Feather.xcscheme buildable -> Feather.framework"
fi

echo "== apply_fork(feather): done =="
