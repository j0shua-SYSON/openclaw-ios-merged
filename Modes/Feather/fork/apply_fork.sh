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

# 4. Core Data fixes for the embedded framework:
#    (a) NSPersistentContainer(name:) looks for the "Feather" model in Bundle.main
#        (= OpenClaw when embedded) and can't find it -> load persistent stores fails
#        -> Storage's fatalError. Load the model from the framework bundle instead.
#    (b) Isolate the store at Documents/Feather/Feather.sqlite.
perl -0pi -e 's/container = NSPersistentContainer\(name: _name\)\n/container = {\n\t\t\tif let _url = Bundle(for: Storage.self).url(forResource: "Feather", withExtension: "momd"),\n\t\t\t   let _model = NSManagedObjectModel(contentsOf: _url) {\n\t\t\t\treturn NSPersistentContainer(name: "Feather", managedObjectModel: _model)\n\t\t\t}\n\t\t\treturn NSPersistentContainer(name: "Feather")\n\t\t}()\n\t\tif !inMemory {\n\t\t\tlet _dir = URL.documentsDirectory.appendingPathComponent("Feather", isDirectory: true)\n\t\t\ttry? FileManager.default.createDirectory(at: _dir, withIntermediateDirectories: true)\n\t\t\tcontainer.persistentStoreDescriptions.first?.url = _dir.appendingPathComponent("Feather.sqlite")\n\t\t}\n/' \
  "$APP/Backend/Storage/Storage.swift"
echo "   loaded Core Data model from framework bundle + isolated store -> Documents/Feather/"

# 4b. Redirect Feather's own-bundle asset/resource lookups from Bundle.main (which
#     is OpenClaw.app when embedded) to the Feather.framework bundle. Feather has no
#     force-unwrapped lookups (so no launch crash, unlike Delta), but SwiftUI
#     Image("...") asset icons + Bundle.main.url(forResource:) (signing-assets, tweak
#     resource) would silently resolve to the host and come up empty. Bundle
#     .featherResources (defined in FeatherHost.swift) points at the framework bundle.
find "$APP" -name "*.swift" -type f -exec perl -0pi -e \
  's/Bundle\.main\.url\(forResource/Bundle.featherResources.url(forResource/g;
   s/Bundle\.main\.path\(forResource/Bundle.featherResources.path(forResource/g;
   s/(?<![A-Za-z])Image\(\s*"([^"]+)"\s*\)/Image("$1", bundle: Bundle.featherResources)/g;
   s/(?<![A-Za-z])Color\(\s*"([^"]+)"\s*\)/Color("$1", bundle: Bundle.featherResources)/g;
   s/UIImage\(named:\s*"([^"]+)"\)/UIImage(named: "$1", in: Bundle.featherResources, compatibleWith: nil)/g;
   s/UIColor\(named:\s*"([^"]+)"\)/UIColor(named: "$1", in: Bundle.featherResources, compatibleWith: nil)/g' {} +
echo "   redirected Bundle.main + asset-catalog lookups -> Bundle.featherResources"

# 5. Convert the app target into Feather.framework.
ruby "$FORK/convert_to_framework.rb" "$CLONE/Feather.xcodeproj"

# 6. Repoint the shared "Feather" scheme's buildable to the framework product.
SCHEME="$CLONE/Feather.xcodeproj/xcshareddata/xcschemes/Feather.xcscheme"
if [ -f "$SCHEME" ]; then
  sed -i '' -e 's/BuildableName = "Feather.app"/BuildableName = "Feather.framework"/g' "$SCHEME"
  echo "   repointed Feather.xcscheme buildable -> Feather.framework"
fi

echo "== apply_fork(feather): done =="
