//
//  AppDelegate.m
//  SonyHeadphonesClient
//
//  Created by Sem Visscher on 01/12/2020.
//

#import "AppDelegate.h"
#import "ViewController.h"

@interface AppDelegate ()


@end

@implementation AppDelegate

- (ViewController*)mainViewController {
    NSWindow* window = _window ?: NSApp.mainWindow ?: NSApp.windows.firstObject;
    if (window == nil) {
        return nil;
    }
    id controller = window.contentViewController;
    if ([controller isKindOfClass:[ViewController class]]) {
        return (ViewController*)controller;
    }
    return nil;
}

- (void)installStatusBarWhenReady {
    ViewController* controller = [self mainViewController];
    if (controller != nil) {
        [controller ensureStatusBarPresent];
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self installStatusBarWhenReady];
    });
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    _window = [[[NSApplication sharedApplication] windows] firstObject];
    [self installStatusBarWhenReady];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    if (flag) {
        return NO;
    }
    else {
        [_window makeKeyAndOrderFront:self];
        return YES;
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    if (statusItem != nil) {
        [NSStatusBar.systemStatusBar removeStatusItem:statusItem];
        statusItem = nil;
    }
    if (bt.isConnected()) {
        bt.disconnect();
    }
    if (headphones != nullptr) {
        delete headphones;
        headphones = nullptr;
    }
}

@end
