//
//  DeltaLauncher.m
//
//  Bridges the pure-ObjC DeltaLauncher boundary to the @objc Swift DeltaHost.
//  Compiled inside Delta.framework, where the generated <Delta/Delta-Swift.h>
//  (which projects @objc DeltaHost) is available. OpenClaw never sees this file
//  or the Swift header — only DeltaLauncher.h.
//

#import "DeltaLauncher.h"
#import <Delta/Delta-Swift.h>

@implementation DeltaLauncher

+ (UIViewController *)makeRootViewController
{
    return [DeltaHost makeRootViewController];
}

@end
