//
//  XMRigMiner-Bridging-Header.h
//  XMRigMiner-iOS
//
//  Bridging header for Swift to access Objective-C/C++ code
//

#ifndef XMRigMiner_Bridging_Header_h
#define XMRigMiner_Bridging_Header_h

#import <Foundation/Foundation.h>

// Include the XMRig Bridge C API
#include "xmrig_bridge.h"

// Forward declare the Objective-C bridge class
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

#endif /* XMRigMiner_Bridging_Header_h */
