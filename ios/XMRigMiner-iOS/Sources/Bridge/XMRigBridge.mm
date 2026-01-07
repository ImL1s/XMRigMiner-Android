#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <atomic>

// Static storage for stats (since we can't directly access XMRig internals)
static std::atomic<double> s_hashrate_10s{0.0};
static std::atomic<double> s_hashrate_60s{0.0};
static std::atomic<double> s_hashrate_15m{0.0};
static std::atomic<uint64_t> s_accepted_shares{0};
static std::atomic<uint64_t> s_rejected_shares{0};
static std::atomic<int> s_threads{0};
static std::atomic<bool> s_is_mining{false};

// C API stub implementations (until full XMRig integration)
extern "C" {
    int xmrig_init(const char* config_json) {
        // Store config for later use
        return 0;
    }
    
    int xmrig_start(void) {
        s_is_mining = true;
        // TODO: Actually start XMRig mining
        return 0;
    }
    
    void xmrig_stop(void) {
        s_is_mining = false;
    }
    
    bool xmrig_is_running(void) {
        return s_is_mining.load();
    }
    
    typedef struct {
        double hashrate_10s;
        double hashrate_60s;
        double hashrate_15m;
        uint64_t total_hashes;
        uint64_t accepted_shares;
        uint64_t rejected_shares;
        bool is_mining;
        int threads;
    } XMRigStats;
    
    void xmrig_get_stats(XMRigStats* stats) {
        if (!stats) return;
        stats->hashrate_10s = s_hashrate_10s.load();
        stats->hashrate_60s = s_hashrate_60s.load();
        stats->hashrate_15m = s_hashrate_15m.load();
        stats->total_hashes = 0;
        stats->accepted_shares = s_accepted_shares.load();
        stats->rejected_shares = s_rejected_shares.load();
        stats->is_mining = s_is_mining.load();
        stats->threads = s_threads.load();
    }
    
    double xmrig_get_hashrate(void) {
        return s_hashrate_10s.load();
    }
    
    void xmrig_set_threads(int threads) {
        s_threads = threads;
    }
    
    void xmrig_cleanup(void) {
        s_is_mining = false;
        s_hashrate_10s = 0.0;
        s_hashrate_60s = 0.0;
        s_hashrate_15m = 0.0;
        s_accepted_shares = 0;
        s_rejected_shares = 0;
        s_threads = 0;
    }
    
    const char* xmrig_version(void) {
        return "6.25.0";
    }
    
    void xmrig_update_stats(double hr10s, double hr60s, double hr15m,
                            uint64_t accepted, uint64_t rejected, int threads) {
        s_hashrate_10s = hr10s;
        s_hashrate_60s = hr60s;
        s_hashrate_15m = hr15m;
        s_accepted_shares = accepted;
        s_rejected_shares = rejected;
        s_threads = threads;
    }
}

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
- (void)updateStatsFromLogLine:(NSString *)line {
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
        
        xmrig_update_stats(hr10s, hr60s, hr15m, 
                          s_accepted_shares.load(), 
                          s_rejected_shares.load(), 
                          s_threads.load());
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
        
        xmrig_update_stats(s_hashrate_10s.load(), 
                          s_hashrate_60s.load(), 
                          s_hashrate_15m.load(),
                          accepted, rejected, 
                          s_threads.load());
        return;
    }
    
    // Forward to callback if set
    if (self.logCallback) {
        self.logCallback(line);
    }
}

@end
