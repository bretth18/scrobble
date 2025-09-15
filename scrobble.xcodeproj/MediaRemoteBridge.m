// MediaRemoteBridge.m
// Thin dynamic shim for MediaRemote private framework
// WARNING: Uses private symbols and may break on OS updates. Not App Store safe.

#import "MediaRemoteBridge.h"
#include <dlfcn.h>

// Function pointer typedefs. Symbol names vary by OS; these are commonly seen.
typedef CFDictionaryRef (*MRMediaRemoteCopyNowPlayingInfoFunc)(void);
typedef void (*MRMediaRemoteRegisterForNowPlayingNotificationsFunc)(dispatch_queue_t queue, void (^callback)(CFNotificationCenterRef, void *, CFStringRef, const void *, CFDictionaryRef));
typedef void (*MRMediaRemoteUnregisterForNowPlayingNotificationsFunc)(void);

static void *gMRHandle = NULL;
static MRMediaRemoteCopyNowPlayingInfoFunc gCopyNowPlayingInfo = NULL;
static MRMediaRemoteRegisterForNowPlayingNotificationsFunc gRegister = NULL;
static MRMediaRemoteUnregisterForNowPlayingNotificationsFunc gUnregister = NULL;

@implementation MediaRemoteBridge

+ (BOOL)loadMediaRemote {
    if (gMRHandle) { return YES; }
    gMRHandle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    if (!gMRHandle) { return NO; }

    // Resolve symbols. If a symbol is missing on this OS, some features won't be available.
    gCopyNowPlayingInfo = (MRMediaRemoteCopyNowPlayingInfoFunc)dlsym(gMRHandle, "MRMediaRemoteCopyNowPlayingInfo");
    gRegister = (MRMediaRemoteRegisterForNowPlayingNotificationsFunc)dlsym(gMRHandle, "MRMediaRemoteRegisterForNowPlayingNotifications");
    gUnregister = (MRMediaRemoteUnregisterForNowPlayingNotificationsFunc)dlsym(gMRHandle, "MRMediaRemoteUnregisterForNowPlayingNotifications");

    return (gCopyNowPlayingInfo != NULL);
}

+ (NSDictionary *)copyNowPlayingInfo {
    if (!gCopyNowPlayingInfo) { return nil; }
    CFDictionaryRef info = gCopyNowPlayingInfo();
    if (!info) { return nil; }
    NSDictionary *result = [(__bridge NSDictionary *)info copy];
    CFRelease(info);
    return result;
}

+ (BOOL)registerForNowPlayingNotificationsWithQueue:(dispatch_queue_t)queue
                                           callback:(void (^)(void))callback
{
    if (!gRegister) { return NO; }
    gRegister(queue, ^(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
        if (callback) { callback(); }
    });
    return YES;
}

+ (void)unregisterForNowPlayingNotifications {
    if (gUnregister) { gUnregister(); }
}

@end
