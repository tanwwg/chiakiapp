//
//  ChiakiBridge.h
//  chiakiapp
//
//  Created by Tan Thor Jen on 29/3/22.
//

#ifndef ChiakiBridge_h
#define ChiakiBridge_h

#import <Foundation/Foundation.h>

#import "chiaki/discoveryservice.h"
#import "chiaki/regist.h"
#import "chiaki/ffmpegdecoder.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChiakiRegisterBridge : NSObject

@property (copy) void (^callback)(ChiakiRegistEvent * event);

-(void)registWithPsn:(NSData*)psn host:(NSString*)host pin:(NSInteger)pin;
-(void)cancel;

@end

@interface ChiakiDiscoverBridge : NSObject

-(void)discover;
-(void)wakeup:(NSString*)host key:(NSData*)key;

@property (copy) void (^callback)(size_t hosts_count, ChiakiDiscoveryHost* hosts);

@end

@interface ChiakiSessionBridge : NSObject

@property (copy) void (^callback)(NSData *data);
@property (copy) void (^videoCallback)(AVFrame *frame);

@property (copy) NSString *host;
@property (copy) NSData *morning;
@property (copy) NSData *registKey;

-(void)start;
-(void)setControllerState:(ChiakiControllerState)state;

@end

NS_ASSUME_NONNULL_END

#endif /* ChiakiBridge_h */
