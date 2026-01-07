#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>

// Include the bridge header
#include "xmrig_bridge.h"

// Objective-C Bridge Class
@interface XMRigBridge : NSObject
+ (instancetype)shared;
- (BOOL)initializeWithConfig:(NSString *)jsonConfig;
- (BOOL)startMining;
- (void)stopMining;
- (BOOL)isRunning;
- (NSDictionary *)getStats;
- (double)getCurrentHashrate;
- (void)setThreads:(int)count;
- (NSString *)getVersion;
@end

@implementation XMRigBridge

+ (instancetype)shared {
    static XMRigBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XMRigBridge alloc] init];
    });
    return instance;
}

- (BOOL)initializeWithConfig:(NSString *)jsonConfig {
    const char *config = [jsonConfig UTF8String];
    int result = xmrig_init(config);
    return result == 0;
}

- (BOOL)startMining {
    int result = xmrig_start();
    return result == 0;
}

- (void)stopMining {
    xmrig_stop();
}

- (BOOL)isRunning {
    return xmrig_is_running();
}

- (NSDictionary *)getStats {
    XMRigStats stats;
    xmrig_get_stats(&stats);
    
    return @{
        @"hashrate_10s": @(stats.hashrate_10s),
        @"hashrate_60s": @(stats.hashrate_60s),
        @"hashrate_15m": @(stats.hashrate_15m),
        @"total_hashes": @(stats.total_hashes),
        @"accepted_shares": @(stats.accepted_shares),
        @"rejected_shares": @(stats.rejected_shares),
        @"is_mining": @(stats.is_mining),
        @"threads": @(stats.threads)
    };
}

- (double)getCurrentHashrate {
    return xmrig_get_hashrate();
}

- (void)setThreads:(int)count {
    xmrig_set_threads(count);
}

- (NSString *)getVersion {
    const char *version = xmrig_version();
    return [NSString stringWithUTF8String:version];
}

@end
