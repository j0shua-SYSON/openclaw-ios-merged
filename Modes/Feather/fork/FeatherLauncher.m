//
//  FeatherLauncher.m
//
//  Bridges the pure-ObjC FeatherLauncher boundary to the @objc Swift FeatherHost.
//  Compiled inside Feather.framework, where the generated <Feather/Feather-Swift.h>
//  (which projects @objc FeatherHost) is available. OpenClaw never sees this file
//  or the Swift header — it forward-declares FeatherLauncher and links the framework.
//

#import "FeatherLauncher.h"
#import <Feather/Feather-Swift.h>

@implementation FeatherLauncher

+ (UIViewController *)makeRootViewController
{
    return [FeatherHost makeRootViewController];
}

@end
