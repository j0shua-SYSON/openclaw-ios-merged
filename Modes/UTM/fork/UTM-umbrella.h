//
//  UTM.h — umbrella header for UTM.framework (OpenClaw fork)
//
//  Frameworks can't use a SWIFT_OBJC_BRIDGING_HEADER, so this umbrella replaces
//  Services/Swift-Bridging-Header.h: it makes UTM's own ObjC classes visible to UTM's
//  Swift *through the framework module*. These are the same iOS headers the bridging
//  header exposed. Several pull non-modular C/QEMU headers, so the framework build sets
//  CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES = YES.
//
//  apply_fork.sh copies this to UTM/UTM.h and convert_to_framework.rb marks it + the
//  headers below as Public in the framework's Headers phase.
//

#import <Foundation/Foundation.h>

#import <UTM/UTMLegacyQemuConfiguration.h>
#import <UTM/UTMLegacyQemuConfiguration+Constants.h>
#import <UTM/UTMLegacyQemuConfiguration+Display.h>
#import <UTM/UTMLegacyQemuConfiguration+Drives.h>
#import <UTM/UTMLegacyQemuConfiguration+Miscellaneous.h>
#import <UTM/UTMLegacyQemuConfiguration+Networking.h>
#import <UTM/UTMLegacyQemuConfiguration+Sharing.h>
#import <UTM/UTMLegacyQemuConfiguration+System.h>
#import <UTM/UTMLegacyQemuConfigurationPortForward.h>
#import <UTM/UTMLogging.h>
#import <UTM/UTMASIFImage.h>
#import <UTM/VMKeyboardMap.h>
#import <UTM/UTMProcess.h>
#import <UTM/UTMQemuSystem.h>
#import <UTM/UTMJailbreak.h>
#import <UTM/UTMLegacyViewState.h>
#import <UTM/UTMSpiceIO.h>
#import <UTM/GenerateKey.h>
#import <UTM/VMDisplayViewController.h>
#import <UTM/VMDisplayMetalViewController.h>
#import <UTM/VMDisplayMetalViewController+Keyboard.h>
#import <UTM/VMKeyboardButton.h>
#import <UTM/VMKeyboardView.h>
