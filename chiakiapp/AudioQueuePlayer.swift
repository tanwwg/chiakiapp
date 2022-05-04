//
//  AudioQueuePlayer.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 31/3/22.
//

import Foundation
import AudioToolbox

class AudioQueuePlayer {
    
    var aqRef: AudioQueueRef?
    var sampleRate: Double = 0
    let dispatchQueue = DispatchQueue(label: "audioQueue")
    
    var bufferList: [AudioQueueBufferRef] = []
    
    var preallocateSize = 5
    
    var isStarted = false
    
    static let minBuffer = 2
    static let maxBuffer = 4
    
    var enqueued = 0
    
    func checkStatus(_ status: OSStatus, msg: String) {
        if status != 0 {
            print("\(msg) err=\(status)")
        }
    }
    
    func startup(channels: Int, sampleRate: Double) {
        print("startup channels:\(channels) rate:\(sampleRate)")
        
        var desc = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: UInt32(channels),
            mBitsPerChannel: 16,
            mReserved: 0)
        
        let status = AudioQueueNewOutputWithDispatchQueue(&aqRef, &desc, 0, dispatchQueue) { (q, buf) in
            self.queueCallback(buffer: buf)
        }
        checkStatus(status, msg: "AudioQueueNewOutputWithDispatchQueue")
        
        self.sampleRate = sampleRate
        
        for _ in 1...preallocateSize {
            if let buf = createBuffer() {
                self.bufferList.append(buf)
            }
        }
    }
    
    func createBuffer() -> AudioQueueBufferRef? {
        guard let aq = self.aqRef else { return nil }
        
        let bufSize: UInt32 = UInt32(4 * self.sampleRate / 10);
        var buf: AudioQueueBufferRef? = nil
        checkStatus(AudioQueueAllocateBuffer(aq, bufSize, &buf), msg: "AudioQueueAllocateBuffer")
        return buf
    }
    
    func takeBuffer() -> AudioQueueBufferRef? {
        if !bufferList.isEmpty {
            return bufferList.removeLast()
        }
        print("audioqueue createbuffer")
        return createBuffer()
    }
    
    func play(data: Data) {
        guard let aq = self.aqRef else { return }
        
        dispatchQueue.sync { [self] in
            
            // if we have too many items enqueued, just drop the incoming packet
            if enqueued > AudioQueuePlayer.maxBuffer {
                return
            }

            guard let b = takeBuffer() else { return }
            let capacity = Int(b.pointee.mAudioDataBytesCapacity)
            if data.count > capacity { print("overflow buffer!") }
            let sz = min(data.count, capacity)
            
            data.withUnsafeBytes { src in
                guard let p = src.baseAddress else { return }
                b.pointee.mAudioData.copyMemory(from: p, byteCount: sz)
            }
            
            b.pointee.mAudioDataByteSize = UInt32(sz)
            AudioQueueEnqueueBuffer(aq, b, 0, nil)

            enqueued += 1
            if !isStarted && enqueued >= AudioQueuePlayer.minBuffer {
                isStarted = true
                checkStatus(AudioQueueStart(aq, nil), msg: "AudioQueueStart")
            }
        }
    }
    
    func queueCallback(buffer: AudioQueueBufferRef) -> Void {
        dispatchQueue.async { [self] in
            self.bufferList.append(buffer)
            enqueued -= 1
            if enqueued == 0 {
                isStarted = false
                if let aq = aqRef {
                    AudioQueueStop(aq, true)
                }
            }
        }
    }
}
