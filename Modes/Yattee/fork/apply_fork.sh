#!/bin/bash
#
# apply_fork.sh <yattee-clone-dir> <fork-dir>
#
# Applies the OpenClaw Yattee (YouTube) mode fork to a fresh yattee/yattee clone on CI.
# Everything it touches is inside the clone (runner-only); nothing writes to the OpenClaw repo.
#
set -euo pipefail

CLONE="$1"   # e.g. $PWD/yattee
FORK="$2"    # e.g. $PWD/openclaw/Modes/Yattee/fork

echo "== apply_fork(Yattee): clone=$CLONE =="

# 1. Drop in the launcher (compiles inside Yattee's module so it can reach internal types).
cp "$FORK/YatteeLauncher.swift" "$CLONE/Shared/YatteeLauncher.swift"
echo "   copied YatteeLauncher.swift"

# 2. Neutralize the app entry point — @main is illegal in a framework. YatteeApp.main() is never
#    called (we boot via YatteeLauncher, which reproduces its ContentView + configure()). CRLF-safe.
perl -0pi -e 's/\@main(\r?\n)(struct YatteeApp)/\/\/ \@main (removed for Yattee.framework)$1$2/' \
  "$CLONE/Shared/YatteeApp.swift"
grep -q "// @main (removed for Yattee.framework)" "$CLONE/Shared/YatteeApp.swift" \
  || { echo "ERROR: @main neutralization did not apply"; exit 1; }
echo "   neutralized @main in Shared/YatteeApp.swift"

# 3. CORE DATA (hard crash otherwise). NSPersistentContainer(name:) looks up the compiled
#    Yattee.momd in Bundle.main ONLY. Embedded, Bundle.main is the HOST app (OpenClaw), which has
#    no Yattee.momd -> the store load fails and PersistenceController's completion hits fatalError.
#    Load the model explicitly from the framework bundle instead.
PC="$CLONE/Model/PersistenceController.swift"
perl -0pi -e 's/NSPersistentContainer\(name: "Yattee"\)/OpenClawYatteeContainer.make()/' "$PC"
if grep -q 'NSPersistentContainer(name: "Yattee")' "$PC"; then
  echo "ERROR: PersistenceController patch did not apply"; sed -n '1,40p' "$PC"; exit 1
fi
cat >> "$PC" <<'EOF'

// OpenClaw embed: NSPersistentContainer(name:) resolves the managed object model from Bundle.main,
// which is the HOST app once Yattee runs as an embedded framework — it would not find Yattee.momd
// and PersistenceController would fatalError. Resolve the model from the framework bundle instead.
enum OpenClawYatteeContainer {
    static func make() -> NSPersistentContainer {
        let bundle = Bundle(for: BundleToken.self)
        if let url = bundle.url(forResource: "Yattee", withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: url)
        {
            return NSPersistentContainer(name: "Yattee", managedObjectModel: model)
        }
        // Fall back to the stock lookup (standalone builds, or if the model moved).
        return NSPersistentContainer(name: "Yattee")
    }

    private final class BundleToken {}
}
EOF
echo "   patched PersistenceController -> framework-bundle Core Data model"

# 4. LOCALIZATION. String+Localizable hardcodes `bundle: .main`, so embedded it resolves against the
#    HOST app's bundle and silently drops all of Yattee's *.lproj translations. Point it at the
#    framework bundle.
LOC="$CLONE/Extensions/String+Localizable.swift"
perl -0pi -e 's/bundle: \.main/bundle: Bundle(for: OpenClawYatteeLocalizationToken.self)/' "$LOC"
cat >> "$LOC" <<'EOF'

/// OpenClaw embed: anchors NSLocalizedString to the framework bundle (Bundle.main is the host app).
final class OpenClawYatteeLocalizationToken {}
EOF
echo "   patched String+Localizable -> framework bundle"

# 5. Default the player backend to AVPlayer (MPV stays linked but unused at runtime): PlayerModel's
#    activeBackend, the Defaults key, and the default QualityProfile.
perl -0pi -e 's/activeBackend = PlayerBackendType\.mpv/activeBackend = PlayerBackendType.appleAVPlayer/' \
  "$CLONE/Model/Player/PlayerModel.swift"
perl -0pi -e 's/("activeBackend", default: )\.mpv/${1}.appleAVPlayer/' "$CLONE/Shared/Defaults.swift"
perl -0pi -e 's/(id: "default", backend: )\.mpv/${1}.appleAVPlayer/' "$CLONE/Model/QualityProfile.swift"
echo "   defaulted player backend -> AVPlayer"

# 6. Convert the iOS app target -> Yattee.framework.
ruby "$FORK/convert_to_framework.rb" "$CLONE/Yattee.xcodeproj"

echo "== apply_fork(Yattee): done =="
