//
//  Feather.h  (umbrella header for Feather.framework, module name "Feather")
//
//  Copied into the Feather clone as Feather/Feather.h by apply_fork.sh. A framework
//  target cannot use an Objective-C bridging header, so the two ObjC headers Feather
//  previously exposed via Feather-Bridging-Header.h are promoted to *public* framework
//  headers and re-exported here so the framework's own Swift sees them (same-module).
//

#import <Foundation/Foundation.h>

#import <Feather/MachOUtils.h>
#import <Feather/iconPoc.h>
// OpenClaw's entry point into Feather (UIKit-only surface; see FeatherLauncher.h).
#import <Feather/FeatherLauncher.h>

FOUNDATION_EXPORT double FeatherVersionNumber;
FOUNDATION_EXPORT const unsigned char FeatherVersionString[];
