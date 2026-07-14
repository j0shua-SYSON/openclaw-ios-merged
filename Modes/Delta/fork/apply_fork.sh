#!/bin/bash
#
# apply_fork.sh <delta-clone-dir> <fork-dir>
#
# Applies the OpenClaw DeltaMode fork to a fresh Delta clone on CI. Everything it
# touches is inside the clone (which lives only on the runner) — nothing here
# writes to the OpenClaw repo or to any local F: path.
#
set -euo pipefail

CLONE="$1"                              # e.g. $PWD/delta
FORK="$2"                               # e.g. $PWD/openclaw/Modes/Delta/fork
APP="$CLONE/Delta"                      # Delta's app source dir

echo "== apply_fork: clone=$CLONE fork=$FORK =="

# 1. Drop in the public factory, the ObjC boundary, and the umbrella header.
cp "$FORK/../App/DeltaHost.swift" "$APP/DeltaHost.swift"
cp "$FORK/DeltaLauncher.h"        "$APP/DeltaLauncher.h"
cp "$FORK/DeltaLauncher.m"        "$APP/DeltaLauncher.m"
cp "$FORK/Delta-umbrella.h"       "$APP/Delta.h"
cp "$FORK/DeltaMode-Info.plist"   "$CLONE/DeltaMode-Info.plist"
echo "   copied DeltaHost.swift, DeltaLauncher.{h,m}, Delta.h (umbrella), DeltaMode-Info.plist"

# 2. Neutralize the app entry point — @UIApplicationMain is illegal in a framework.
perl -0pi -e 's/\@UIApplicationMain/\/\/ \@UIApplicationMain (removed for DeltaMode framework build)/g' \
  "$APP/AppDelegate.swift"
echo "   neutralized @UIApplicationMain in AppDelegate.swift"

# 2b. Redirect Delta's own-resource + asset-catalog lookups from Bundle.main (which
#     is OpenClaw.app when embedded) to the Delta.framework bundle. Delta bundles
#     openvgdb.sqlite, cheatbase.zip, plists, Profanity.txt, nibs AND its asset
#     catalog (Assets.car: colors "Purple"/"LightPurple"/"DarkGray", images) inside
#     the framework, but loads them via Bundle.main. UIColor(named:) defaults to
#     Bundle.main and Delta force-unwraps deltaPurple -> the actual launch crash.
#     UIImage(named:) / SwiftUI Color()/Image() do the same (missing assets). Bundle
#     .deltaResources (defined in DeltaHost.swift) points at the framework bundle.
find "$APP" -name "*.swift" -type f -exec perl -0pi -e \
  's/Bundle\.main\.url\(forResource/Bundle.deltaResources.url(forResource/g;
   s/Bundle\.main\.path\(forResource/Bundle.deltaResources.path(forResource/g;
   s/Bundle\.main\.loadNibNamed\(/Bundle.deltaResources.loadNibNamed(/g;
   s/UIColor\(named:\s*"([^"]+)"\)/UIColor(named: "$1", in: Bundle.deltaResources, compatibleWith: nil)/g;
   s/UIImage\(named:\s*"([^"]+)"\)/UIImage(named: "$1", in: Bundle.deltaResources, compatibleWith: nil)/g;
   s/#imageLiteral\(resourceName:\s*"([^"]+)"\)/(UIImage(named: "$1", in: Bundle.deltaResources, compatibleWith: nil) ?? UIImage())/g;
   s/(?<![A-Za-z])Color\(\s*"([^"]+)"\s*\)/Color("$1", bundle: Bundle.deltaResources)/g;
   s/(?<![A-Za-z])Image\(\s*"([^"]+)"\s*\)/Image("$1", bundle: Bundle.deltaResources)/g;
   s/UIStoryboard\(name:\s*("[^"]+"),\s*bundle:\s*(?:\.main|nil)\)/UIStoryboard(name: $1, bundle: Bundle.deltaResources)/g;
   s/UINib\(nibName:\s*("[^"]+"),\s*bundle:\s*(?:\.main|nil)\)/UINib(nibName: $1, bundle: Bundle.deltaResources)/g' {} +
echo "   redirected Bundle.main resource + asset-catalog + storyboard/nib lookups -> Bundle.deltaResources"

# 2c. Inject an "App Switcher" row at the top of Delta's Settings so the user can
#     return to OpenClaw / switch apps from *inside* Delta (OpenClaw's host settings
#     aren't reachable while a mode is presented). It posts the process-wide
#     OpenClawShowModeSwitcher notification that OpenClawApp observes — Delta runs in
#     OpenClaw's process, so the plain NotificationCenter post crosses the boundary.
perl -0pi -e 's/(Form \{\n)( +)(PatreonSection\(\))/$1$2Section {\n$2    Button {\n$2        NotificationCenter.default.post(name: Notification.Name("OpenClawShowModeSwitcher"), object: nil)\n$2    } label: {\n$2        Label("App Switcher", systemImage: "square.on.square.dashed")\n$2    }\n$2} footer: {\n$2    Text("Switch to another app embedded in OpenClaw.")\n$2}\n$2$3/' \
  "$APP/Settings/SettingsView.swift"
echo "   injected 'App Switcher' row into Delta Settings (SettingsView.swift)"

# 2d. Fix game audio being silent when embedded. OpenClaw keeps the shared
#     AVAudioSession in .playAndRecord with a *voice* mode (.voiceChat for Talk,
#     .measurement for wake-word) and leaves it active. DeltaCore's setDeltaCategory()
#     uses the 2-arg setCategory(_:options:) form, which does NOT reset the mode — so
#     game audio renders through iOS voice processing routed to the earpiece receiver
#     and is effectively muted (DeltaCore's own overrideOutputAudioPort(.speaker) can't
#     undo a voice-processing session). Forcing mode: .default gives Delta a clean
#     playback session so its speaker-routing works. Standalone behavior is unchanged
#     (there the mode was already effectively .default). Guarded: if the upstream call
#     format changes so nothing matches, fail the build instead of shipping no sound.
AUDIO_PATCHED=0
while IFS= read -r -d '' f; do
  perl -0pi -e 's/setCategory\(\.playAndRecord,\s+options:/setCategory(.playAndRecord, mode: .default, options:/g' "$f"
  if grep -q 'setCategory(.playAndRecord, mode: .default, options:' "$f"; then AUDIO_PATCHED=1; fi
done < <(find "$CLONE" -name "AudioManager.swift" -type f -exec grep -lZ setDeltaCategory {} +)
[ "$AUDIO_PATCHED" = 1 ] || { echo "ERROR: DeltaCore audio mode patch did not apply (setDeltaCategory format changed?)"; exit 1; }
echo "   forced AVAudioSession mode: .default in DeltaCore AudioManager (embedded audio routing)"

# 3. Convert the app target into DeltaMode.framework.
ruby "$FORK/convert_to_framework.rb" "$CLONE/Delta.xcodeproj"

# 4. Repoint the shared "Delta" scheme's app-target buildable to the framework
#    product. Target keeps its name "Delta" (so BlueprintName is unchanged); only
#    the produced file name changes from Delta.app to Delta.framework. macOS/BSD sed.
SCHEME="$CLONE/Delta.xcodeproj/xcshareddata/xcschemes/Delta.xcscheme"
if [ -f "$SCHEME" ]; then
  sed -i '' \
    -e 's/BuildableName = "Delta.app"/BuildableName = "Delta.framework"/g' \
    "$SCHEME"
  echo "   repointed Delta.xcscheme buildable -> Delta.framework"
fi

echo "== apply_fork: done =="
