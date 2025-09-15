// MediaRemoteBridge.h
// Created to provide a thin dynamic shim over the private MediaRemote framework.
// NOTE: This uses private API and is not App Store safe. Expect breakage on OS updates.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MediaRemoteBridge : NSObject

// Loads the private framework and resolves required symbols. Returns YES on success.
+ (BOOL)loadMediaRemote;

// Returns the current now playing info dictionary (keys are typically kMRMediaRemoteNowPlayingInfo*).
// May return nil if unavailable or denied by the system.
+ (nullable NSDictionary *)copyNowPlayingInfo;

// Registers for now playing notifications (if available on this OS). The callback will be invoked
// when MediaRemote posts changes. Many shims simply re-poll in the callback.
+ (BOOL)registerForNowPlayingNotificationsWithQueue:(dispatch_queue_t)queue
                                           callback:(void (^)(void))callback;

+ (void)unregisterForNowPlayingNotifications;

@end

NS_ASSUME_NONNULL_END
