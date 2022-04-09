//
//  ChiakiBridge.m
//  chiakiapp
//
//  Created by Tan Thor Jen on 29/3/22.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#import "chiaki/discoveryservice.h"
#import "chiaki/regist.h"
#import "chiaki/session.h"
#import "chiaki/log.h"
#import "chiaki/ffmpegdecoder.h"
#import "chiaki/opusdecoder.h"

#import "ChiakiBridge.h"

@implementation ChiakiDiscoverBridge {
    ChiakiDiscoveryService discoveryService;
    ChiakiLog chiakiLog;
}

static void DiscoveryServiceHostsCallback(ChiakiDiscoveryHost* hosts, size_t hosts_count, void *user)
{
    ChiakiDiscoverBridge *bridge = (__bridge ChiakiDiscoverBridge *)(user);
    bridge.callback(hosts_count, hosts);
}

static void NoLogCb(ChiakiLogLevel level, const char *msg, void *user) {
//    NSLog(@"log %s", msg);
}

static void LogCb(ChiakiLogLevel level, const char *msg, void *user) {
    NSLog(@"log %s", msg);
}

-(void) discover {
    ChiakiDiscoveryServiceOptions options;
    options.ping_ms = 500;
    options.hosts_max = 16;
    options.host_drop_pings = 3;
    options.cb = DiscoveryServiceHostsCallback;
    options.cb_user = (__bridge void *)(self);
    
    struct sockaddr_in addr = {};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = 0xffffffff; // 255.255.255.255
    options.send_addr = (struct sockaddr *)(&addr);
    options.send_addr_size = sizeof(addr);
        
    chiaki_log_init(&chiakiLog, CHIAKI_LOG_ALL, NoLogCb, NULL);

    ChiakiErrorCode err = chiaki_discovery_service_init(&discoveryService, &options, &chiakiLog);
    NSLog(@"discover err=%d", err);
    
}

-(void)wakeup:(NSString*)host key:(uint64_t)key {
    ChiakiErrorCode err = chiaki_discovery_wakeup(&chiakiLog, &discoveryService.discovery, host.UTF8String, key, true);
    NSLog(@"chiaki_discovery_wakeup err=%d", err);
}


@end

@implementation ChiakiRegisterBridge {
    ChiakiRegist regist;
    ChiakiLog chiakiLog;
}

static void RegisterCb(ChiakiRegistEvent *event, void *user) {
    NSLog(@"registercb %d", event->type);

    ChiakiRegisterBridge *bridge = (__bridge ChiakiRegisterBridge *)(user);
    bridge.callback(event);
}


-(void)registWithPsn:(NSData*)psn host:(NSString*)host pin:(NSInteger)pin
{
    chiaki_log_init(&chiakiLog, CHIAKI_LOG_ALL, LogCb, NULL);
 
    ChiakiRegistInfo info;

    info.psn_online_id = NULL;
    info.pin = (uint32_t)pin;
    
    if (psn.length != 8) {
        ChiakiRegistEvent evt;
        evt.type = CHIAKI_REGIST_EVENT_TYPE_FINISHED_FAILED;
        evt.registered_host = NULL;
        self.callback(&evt);
        return;
    }

    const uint8_t *b = psn.bytes;
    for(int i = 0; i < 8; i++) {
        info.psn_account_id[i] = b[i];
    }
    
    info.broadcast = false;
    info.target = CHIAKI_TARGET_PS5_1;
    info.host = host.UTF8String;
    
    ChiakiErrorCode err = chiaki_regist_start(&regist, &chiakiLog, &info, &RegisterCb, (__bridge void *)(self));
    NSLog(@"chiaki_regist_start err=%d", err);
    
    if (err != CHIAKI_ERR_SUCCESS) {
        ChiakiRegistEvent evt;
        evt.type = CHIAKI_REGIST_EVENT_TYPE_FINISHED_FAILED;
        evt.registered_host = NULL;
        self.callback(&evt);
    }
}

-(void)cancel {
    chiaki_regist_stop(&regist);
}

@end


@implementation ChiakiSessionBridge {
    ChiakiSession session;
    ChiakiLog chiakiLog;
    ChiakiFfmpegDecoder decoder;
    ChiakiOpusDecoder opusDecoder;
}

//static int packetCount = 1;

static bool VideoCb(uint8_t *buf, size_t buf_size, void *user) {
//    NSData *data = [[NSData alloc] initWithBytesNoCopy:buf length:buf_size];
//    NSLog(@"VideoCb %ld", buf_size);
    
//    NSData *data = [[NSData alloc] initWithBytesNoCopy:buf length:buf_size freeWhenDone:NO];
//    NSString *filename = [NSString stringWithFormat:@"/Users/tjtan/Downloads/vid/raw_%d", packetCount++];
//    [data writeToFile:filename atomically:true];
    
    ChiakiSessionBridge *bridge = (__bridge ChiakiSessionBridge *)(user);
    
    if (bridge.rawVideoCallback != NULL) {
        bridge.rawVideoCallback(buf, buf_size);
    } else {
        chiaki_ffmpeg_decoder_video_sample_cb(buf, buf_size, &bridge->decoder);
    }
    
    
//    bridge.callback(data);
    
    return true;
}

static void AudioSettingsCb(uint32_t channels, uint32_t rate, void *user)
{
    ChiakiSessionBridge *bridge = (__bridge ChiakiSessionBridge *)(user);
    bridge.audioSettingsCallback(channels, rate);
}

static void AudioFrameCb(int16_t *buf, size_t samples_count, void *user)
{
    ChiakiSessionBridge *bridge = (__bridge ChiakiSessionBridge *)(user);
    bridge.audioFrameCallback(buf, samples_count);
}


static void FrameCb(ChiakiFfmpegDecoder *decoder, void *user) {
    AVFrame *frame = chiaki_ffmpeg_decoder_pull_frame(decoder);
    if (frame == NULL) {
        NSLog(@"Error pulling frame");
        return;
    }
    
//    @autoreleasepool {
//        NSData * data = [[NSData alloc] initWithBytesNoCopy:frame->data[0] length:1920*1080];
//        [data writeToFile:@"/Users/tjtan/downloads/test.raw" atomically:true];
//    }
    
    ChiakiSessionBridge *bridge = (__bridge ChiakiSessionBridge *)(user);
    if (bridge.videoCallback != nil) {
        bridge.videoCallback(frame);
    }
    
    av_frame_free(&frame);
}

-(void)start {
    chiaki_log_init(&chiakiLog, 3, NoLogCb, NULL);
    
    ChiakiErrorCode err;
    
    err = chiaki_ffmpeg_decoder_init(&decoder, &chiakiLog, CHIAKI_CODEC_H264, NULL, FrameCb, (__bridge void*)self);
    NSLog(@"chiaki_ffmpeg_decoder_init err=%d", err);

    ChiakiConnectInfo info = {};
    info.ps5 = true;
    info.host = [self.host cStringUsingEncoding:NSUTF8StringEncoding];
    info.enable_keyboard = false;
    
    if (self.morning.length != 16) {
        NSLog(@"ERROR Morning is not 16 bytes");
        return;
    }
    memcpy(info.morning, self.morning.bytes, 16);
    memcpy(info.regist_key, self.registKey.bytes, 16);
    
    chiaki_connect_video_profile_preset(&info.video_profile, CHIAKI_VIDEO_RESOLUTION_PRESET_1080p, CHIAKI_VIDEO_FPS_PRESET_60);
    info.video_profile.codec = CHIAKI_CODEC_H264;
    info.video_profile_auto_downgrade = false;

    
    err = chiaki_session_init(&session, &info, &chiakiLog);
    NSLog(@"chiaki_session_init err=%d", err);
    
    chiaki_session_set_video_sample_cb(&session, VideoCb, (__bridge void*)self);
    chiaki_session_start(&session);
    
    chiaki_opus_decoder_init(&opusDecoder, &chiakiLog);
    chiaki_opus_decoder_set_cb(&opusDecoder, AudioSettingsCb, AudioFrameCb, (__bridge void*)self);
    ChiakiAudioSink audio_sink;
    chiaki_opus_decoder_get_sink(&opusDecoder, &audio_sink);
    chiaki_session_set_audio_sink(&session, &audio_sink);

}

-(void)setControllerState:(ChiakiControllerState)state {
    chiaki_session_set_controller_state(&session, &state);
}

-(void)stop {
    chiaki_session_stop(&session);
    chiaki_session_join(&session);
    chiaki_session_fini(&session);
    chiaki_opus_decoder_fini(&opusDecoder);
    chiaki_ffmpeg_decoder_fini(&decoder);

}

@end
