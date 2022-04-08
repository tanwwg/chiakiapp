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
    
    func startup(sampleRate: Double) {
        // kLinearPCMFormatFlagIsSignedInteger
        
        var desc = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 16,
            mReserved: 0)
        
        let status = AudioQueueNewOutputWithDispatchQueue(&aqRef, &desc, 0, dispatchQueue) { (q, buf) in
            self.queueCallback(buffer: buf)
        }
        if status != 0 {
            print("audio queue init err=\(status)")
        }
        
        self.sampleRate = sampleRate
        
        if let aq = aqRef {
            for _ in 1...3 {
                if let buf = createBuffer() {
                    self.bufferList.append(buf)
                }
            }
            
            AudioQueueStart(aq, nil)
        }
    }
    
    func createBuffer() -> AudioQueueBufferRef? {
        guard let aq = self.aqRef else { return nil }
        
        let bufSize: UInt32 = UInt32(2 * self.sampleRate * 2);
        var buf: AudioQueueBufferRef? = nil
        AudioQueueAllocateBuffer(aq, bufSize, &buf)
        return buf
    }
    
    func takeBuffer() -> AudioQueueBufferRef? {
        dispatchQueue.sync {
            if let lastbuf = bufferList.last {
                bufferList.removeLast()
                return lastbuf
            }
            return createBuffer()
        }
    }
    
    func play(data: Data) {
        guard let aq = self.aqRef else { return }
        let buf = takeBuffer()
        
        if let b = buf {
            var aqbuf = b.pointee
            
            let len = data.withUnsafeBytes { (src:UnsafeRawBufferPointer) in
                src.copyBytes(to: UnsafeMutableRawBufferPointer(start: aqbuf.mAudioData, count: Int(aqbuf.mAudioDataBytesCapacity)))
            }
            aqbuf.mAudioDataByteSize = UInt32(len)
//            aqbuf.mPacketDescriptionCount = 1
            var desc = AudioStreamPacketDescription(mStartOffset: 0, mVariableFramesInPacket: 0, mDataByteSize: UInt32(len))
            let status = AudioQueueEnqueueBuffer(aq, b, 0, nil)
            if status != 0 {
                print("AudioQueueEnqueueBuffer err=\(status)")
            }

        }
        
    }
    
    func queueCallback(buffer: AudioQueueBufferRef) -> Void {
        dispatchQueue.async {
            self.bufferList.append(buffer)
        }
    }
}
