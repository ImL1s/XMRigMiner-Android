#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>

// Include the bridge header
#include "xmrig_bridge.h"

// Callback type for log messages
typedef void (^XMRigLogCallback)(NSString * _Nonnull);

// Objective-C Bridge Class
@interface XMRigBridge : NSObject

@property (nonatomic, copy, nullable) XMRigLogCallback logCallback;

+ (instancetype _Nonnull)shared;
- (BOOL)initializeWithConfig:(NSString * _Nonnull)jsonConfig;
- (BOOL)startMining;
- (void)stopMining;
- (BOOL)isRunning;
- (NSDictionary * _Nonnull)getStats;
- (double)getCurrentHashrate;
- (void)setThreads:(int)count;
- (NSString * _Nonnull)getVersion;
- (void)cleanup;

// Stats update from parsed logs
- (void)updateStatsFromLogLine:(NSString * _Nonnull)line;

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

- (void)cleanup {
    xmrig_cleanup();
}

// Parse XMRig log line and update stats
// Example log formats:
// [2024-01-01 12:00:00.000]  speed 10s/60s/15m 150.0 140.0 130.0 H/s max 160.0 H/s
// [2024-01-01 12:00:00.000]  accepted (1/0) diff 10000 (123 ms)
- (void)updateStatsFromLogLine:(NSString *)line {
    // Parse hashrate line
    NSRegularExpression *hashrateRegex = [NSRegularExpression 
        regularExpressionWithPattern:@"speed\\s+(\\d+)s/(\\d+)s/(\\d+)m\\s+([\\d.]+)\\s+([\\d.]+)\\s+([\\d.]+)"
        options:0 
        error:nil];
    
    NSTextCheckingResult *hashrateMatch = [hashrateRegex 
        firstMatchInString:line 
        options:0 
        range:NSMakeRange(0, line.length)];
    
    if (hashrateMatch && hashrateMatch.numberOfRanges >= 7) {
        double hr10s = [[line substringWithRange:[hashrateMatch rangeAtIndex:4]] doubleValue];
        double hr60s = [[line substringWithRange:[hashrateMatch rangeAtIndex:5]] doubleValue];
        double hr15m = [[line substringWithRange:[hashrateMatch rangeAtIndex:6]] doubleValue];
        
        // Get current stats to preserve shares
        XMRigStats currentStats;
        xmrig_get_stats(&currentStats);
        
        // Update with new hashrate values
        xmrig_update_stats(hr10s, hr60s, hr15m, 
                          currentStats.accepted_shares, 
                          currentStats.rejected_shares, 
                          currentStats.threads);
        return;
    }
    
    // Parse accepted share line
    NSRegularExpression *acceptedRegex = [NSRegularExpression 
        regularExpressionWithPattern:@"accepted\\s+\\((\\d+)/(\\d+)\\)"
        options:0 
        error:nil];
    
    NSTextCheckingResult *acceptedMatch = [acceptedRegex 
        firstMatchInString:line 
        options:0 
        range:NSMakeRange(0, line.length)];
    
    if (acceptedMatch && acceptedMatch.numberOfRanges >= 3) {
        uint64_t accepted = [[line substringWithRange:[acceptedMatch rangeAtIndex:1]] longLongValue];
        uint64_t rejected = [[line substringWithRange:[acceptedMatch rangeAtIndex:2]] longLongValue];
        
        // Get current stats to preserve hashrate
        XMRigStats currentStats;
        xmrig_get_stats(&currentStats);
        
        // Update with new share values
        xmrig_update_stats(currentStats.hashrate_10s, 
                          currentStats.hashrate_60s, 
                          currentStats.hashrate_15m,
                          accepted, rejected, 
                          currentStats.threads);
        return;
    }
    
    // Parse thread count line (e.g., "THREADS     4")
    if ([line containsString:@"THREADS"]) {
        NSRegularExpression *threadRegex = [NSRegularExpression 
            regularExpressionWithPattern:@"THREADS\\s+(\\d+)"
            options:0 
            error:nil];
        
        NSTextCheckingResult *threadMatch = [threadRegex 
            firstMatchInString:line 
            options:0 
            range:NSMakeRange(0, line.length)];
        
        if (threadMatch && threadMatch.numberOfRanges >= 2) {
            int threads = [[line substringWithRange:[threadMatch rangeAtIndex:1]] intValue];
            
            XMRigStats currentStats;
            xmrig_get_stats(&currentStats);
            
            xmrig_update_stats(currentStats.hashrate_10s, 
                              currentStats.hashrate_60s, 
                              currentStats.hashrate_15m,
                              currentStats.accepted_shares, 
                              currentStats.rejected_shares, 
                              threads);
        }
    }
    
    // Forward to callback if set
    if (self.logCallback) {
        self.logCallback(line);
    }
}

@end
