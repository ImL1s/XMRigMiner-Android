#import <Foundation/Foundation.h>
#include "xmrig_bridge.h"

// Define the XMRigStats struct to match the header
typedef struct {
    double hashrate_10s;
    double hashrate_60s;
    double hashrate_15m;
    uint64_t total_hashes;
    uint64_t accepted_shares;
    uint64_t rejected_shares;
    bool is_mining;
    int threads;
} XMRigStatsData;

// Objective-C Bridge Class
@interface XMRigBridge : NSObject

@property (nonatomic, copy, nullable) void (^logCallback)(NSString * _Nonnull);

+ (instancetype _Nonnull)shared;
- (void)setStoragePath:(NSString * _Nonnull)path;
- (BOOL)initializeWithConfig:(NSString * _Nonnull)jsonConfig;
- (BOOL)startMining;
- (void)stopMining;
- (BOOL)isRunning;
- (NSDictionary * _Nonnull)getStats;
- (double)getCurrentHashrate;
- (void)setThreads:(int)count;
- (NSString * _Nonnull)getVersion;
- (void)cleanup;
- (void)updateStatsFromLogLine:(NSString * _Nonnull)line;

@end

// C callback for logs
static void on_xmrig_log(const char* line) {
    if (line == NULL) return;
    
    NSString *logLine = [NSString stringWithUTF8String:line];
    if (logLine) {
        // Dispatch to main thread for UI/stat updates
        dispatch_async(dispatch_get_main_queue(), ^{
            [[XMRigBridge shared] updateStatsFromLogLine:logLine];
        });
    }
}

@implementation XMRigBridge

+ (instancetype)shared {
    static XMRigBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[XMRigBridge alloc] init];
        
        // Register the log callback as soon as shared instance is created
        xmrig_set_log_callback_v8(on_xmrig_log);
    });
    return instance;
}

- (void)setStoragePath:(NSString *)path {
    const char *cPath = [path UTF8String];
    xmrig_set_storage_path_v8(cPath);
}

- (BOOL)initializeWithConfig:(NSString *)jsonConfig {
    fprintf(stderr, "[XMRigBridge] initializeWithConfig called\n");
    NSLog(@"[XMRigBridge] initializeWithConfig called");
    const char *config = [jsonConfig UTF8String];
    
    // Use v8 for definitive linking proof
    int result = xmrig_init_v8(config);
    
    fprintf(stderr, "[XMRigBridge] xmrig_init_v8 returned %d\n", result);
    NSLog(@"[XMRigBridge] xmrig_init_v8 returned %d", result);
    return result == 0;
}

- (BOOL)startMining {
    fprintf(stderr, "[XMRigBridge] startMining called\n");
    NSLog(@"[XMRigBridge] startMining called");
    
    // Use v8 for definitive linking proof
    int result = xmrig_start_v8();
    
    fprintf(stderr, "[XMRigBridge] xmrig_start_v8 returned %d\n", result);
    NSLog(@"[XMRigBridge] xmrig_start_v8 returned %d", result);
    return result == 0;
}

- (void)stopMining {
    xmrig_stop_v8();
}

- (BOOL)isRunning {
    return xmrig_is_running_v8();
}

- (NSDictionary *)getStats {
    XMRigStatsData stats;
    xmrig_get_stats_v8((XMRigStats*)&stats);
    
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
    return xmrig_get_hashrate_v8();
}

- (void)setThreads:(int)count {
    xmrig_set_threads_v8(count);
}

- (NSString *)getVersion {
    const char *version = xmrig_version_v8();
    return [NSString stringWithUTF8String:version];
}

- (void)cleanup {
    xmrig_cleanup_v8();
}

// Parse XMRig log line and update stats
- (void)updateStatsFromLogLine:(NSString *)line {
    // Forward to callback first to show in UI
    if (self.logCallback) {
        self.logCallback(line);
    }

    // Parse hashrate line: "speed 10s/60s/15m 150.0 140.0 130.0 H/s"
    NSRegularExpression *hashrateRegex = [NSRegularExpression 
        regularExpressionWithPattern:@"speed\\s+\\S+\\s+([\\d.]+)\\s+([\\d.]+)\\s+([\\d.]+)"
        options:0 
        error:nil];
    
    NSTextCheckingResult *hashrateMatch = [hashrateRegex 
        firstMatchInString:line 
        options:0 
        range:NSMakeRange(0, line.length)];
    
    if (hashrateMatch && hashrateMatch.numberOfRanges >= 4) {
        double hr10s = [[line substringWithRange:[hashrateMatch rangeAtIndex:1]] doubleValue];
        double hr60s = [[line substringWithRange:[hashrateMatch rangeAtIndex:2]] doubleValue];
        double hr15m = [[line substringWithRange:[hashrateMatch rangeAtIndex:3]] doubleValue];
        
        NSDictionary *currentStats = [self getStats];
        uint64_t accepted = [currentStats[@"accepted_shares"] unsignedLongLongValue];
        uint64_t rejected = [currentStats[@"rejected_shares"] unsignedLongLongValue];
        int threads = [currentStats[@"threads"] intValue];
        
        xmrig_update_stats_v8(hr10s, hr60s, hr15m, accepted, rejected, threads);
        return;
    }
    
    // Parse accepted share line: "accepted (1/0)"
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
        
        NSDictionary *currentStats = [self getStats];
        double hr10s = [currentStats[@"hashrate_10s"] doubleValue];
        double hr60s = [currentStats[@"hashrate_60s"] doubleValue];
        double hr15m = [currentStats[@"hashrate_15m"] doubleValue];
        int threads = [currentStats[@"threads"] intValue];
        
        xmrig_update_stats_v8(hr10s, hr60s, hr15m, accepted, rejected, threads);
    }
}

@end
