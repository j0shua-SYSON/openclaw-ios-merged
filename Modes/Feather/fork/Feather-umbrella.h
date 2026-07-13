//
//  Feather.h  (umbrella header for Feather.framework, module name "Feather")
//
//  Copied into the clone as FeatherModule/Feather.h by apply_fork.sh and added as a
//  public header by the Ruby (Feather uses synchronized groups, so our files live
//  outside the synced tree). A framework target cannot use an ObjC bridging header,
//  so the two ObjC headers Feather exposed via Feather-Bridging-Header.h are pulled
//  in here (quoted; resolved via HEADER_SEARCH_PATHS into the synced tree) so the
//  framework's own Swift sees them.
//

#import <Foundation/Foundation.h>

#import "MachOUtils.h"
#import "iconPoc.h"
// OpenClaw's entry point into Feather (UIKit-only surface; see FeatherLauncher.h).
#import "FeatherLauncher.h"

FOUNDATION_EXPORT double FeatherVersionNumber;
FOUNDATION_EXPORT const unsigned char FeatherVersionString[];
