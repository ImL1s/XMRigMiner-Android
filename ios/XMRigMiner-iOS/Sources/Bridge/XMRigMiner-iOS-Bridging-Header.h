//
//  XMRigMiner-iOS-Bridging-Header.h
//  XMRigMiner-iOS
//
//  Bridging header to expose Objective-C code to Swift
//

#ifndef XMRigMiner_iOS_Bridging_Header_h
#define XMRigMiner_iOS_Bridging_Header_h

#import <Foundation/Foundation.h>
#include "xmrig_bridge.h"

// Forward declare the XMRigBridge Objective-C class
@interface XMRigBridge : NSObject

@property (nonatomic, copy, nullable) void (^logCallback)(NSString * _Nonnull);

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

#endif /* XMRigMiner_iOS_Bridging_Header_h */
