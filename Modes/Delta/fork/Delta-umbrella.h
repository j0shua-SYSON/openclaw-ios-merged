//
//  Delta.h  (umbrella header for DeltaMode.framework, module name "Delta")
//
//  Copied into the Delta clone as Delta/Delta.h by apply_fork.sh. A framework
//  target cannot use an Objective-C bridging header, so the three ObjC headers
//  Delta previously exposed via Delta-Bridging-Header.h are promoted to *public*
//  framework headers and re-exported here. Swift code inside the framework then
//  sees them automatically (same-module), which is exactly what the old bridging
//  header provided.
//

#import <Foundation/Foundation.h>

#import <Delta/ControllerSkinConfigurations.h>
#import <Delta/GameSetting.h>
#import <Delta/NSFetchedResultsController+Conveniences.h>

FOUNDATION_EXPORT double DeltaVersionNumber;
FOUNDATION_EXPORT const unsigned char DeltaVersionString[];
