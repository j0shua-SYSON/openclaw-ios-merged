//
//  OpenClaw-Bridging-Header.h
//
//  Objective-C symbols exposed to OpenClaw's Swift. Delta mode is reached through
//  the pure-ObjC DeltaLauncher boundary (NOT `import Delta`) so OpenClaw's Swift
//  compiler never loads Delta's Swift module and its ~12 statically-linked
//  transitive dependencies. See Modes/Delta/fork/DeltaLauncher.h.
//

#import <Delta/DeltaLauncher.h>
