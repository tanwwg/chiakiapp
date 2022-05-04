//
//  ChiakiBridge.h
//  chiakiapp
//
//  Created by Tan Thor Jen on 29/3/22.
//

#ifndef ChiakiBridge_h
#define ChiakiBridge_h

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

#import "chiaki/discoveryservice.h"
#import "chiaki/regist.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChiakiRegisterBridge : NSObject

@property (copy) void (^callback)(ChiakiRegistEvent * event);

-(void)registWithPsn:(NSData*)psn host:(NSString*)host pin:(NSInteger)pin;
-(void)cancel;

@end

@interface ChiakiDiscoverBridge : NSObject

-(void)discover;
-(void)wakeup:(NSString*)host key:(uint64_t)key;

@property (copy) void (^callback)(size_t hosts_count, ChiakiDiscoveryHost* hosts);

@end

@interface ChiakiSessionBridge : NSObject

@property (copy) void (^callback)(NSData *data);
@property (copy) void (^rawVideoCallback)(uint8_t *buf, size_t buf_size);
@property (copy) void (^audioSettingsCallback)(uint32_t channels, uint32_t rate);
@property (copy) void (^audioFrameCallback)(int16_t *buf, size_t samples_count);
@property (copy) void (^onKeyboardOpen)(void);

@property (copy) NSString *host;
@property (copy) NSData *morning;
@property (copy) NSData *registKey;

-(void)start;
-(void)stop;
-(void)sleep;
-(void)setControllerState:(ChiakiControllerState)state;

-(void)setKeyboardText:(NSString*)s;
-(void)acceptKeyboard;

+(void)nalReplace:(void*)bytes length:(int)length;
+(void)setDisplayImmediately:(CMSampleBufferRef)buffer;

@end

NS_ASSUME_NONNULL_END

#endif /* ChiakiBridge_h */
