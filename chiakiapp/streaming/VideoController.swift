//
//  VideoController.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 16/4/22.
//

import Foundation
import VideoToolbox
import AVKit

class VideoController {
    
    var videoFormatDesc: CMVideoFormatDescription?
    var display: AVSampleBufferDisplayLayer?
    
    func check(_ status: OSStatus, msg: String) -> Bool {
        if status != 0 {
            print("\(msg) err=\(status)")
            return false
        }
        return true
    }



    func findNalStart(_ p: UnsafeRawBufferPointer, start: Int) -> Int? {
        for i in start...p.count-4 {
            if p[i] == 0 && p[i+1] == 0 && p[i+2] == 0 && p[i+3] == 1 {
                return i
            }
        }
        return nil
    }

    func isValidFrame(_ p: UnsafeRawBufferPointer) -> Bool {
        guard p.count > 5 else { return false }
        return p[0] == 0 && p[1] == 0 && p[2] == 0 && p[3] == 1
    }

    /// assumption that its already a valid frame
    func isFormatFrame(_ p: UnsafeRawBufferPointer) -> Bool {
        return p[4] == 103
    }

    func createFormatDesc(_ frame: UnsafeRawBufferPointer) {
        guard let start = findNalStart(frame, start: 0) else { return }
        guard start == 0 else { return }
        guard let next = findNalStart(frame, start: start+4) else { return }
        
        let bytes = frame.bindMemory(to: UInt8.self).baseAddress!
        
        var ptrs: [UnsafePointer<UInt8>] = []
        ptrs.append(bytes + 4)
        ptrs.append(bytes + next + 4)

        var sizes: [Int] = []
        sizes.append(next-start)
        sizes.append(frame.count-next)

        guard check(CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: nil, parameterSetCount: 2, parameterSetPointers: &ptrs, parameterSetSizes: &sizes, nalUnitHeaderLength: 4, formatDescriptionOut: &videoFormatDesc), msg: "CMVideoFormatDescriptionCreateFromH264ParameterSets") else { return }
    }


    func handleVideoFrame(_ frame: UnsafeMutablePointer<UInt8>, size: Int) {
        let srcp = UnsafeRawBufferPointer(start: frame, count: size)
        if (!isValidFrame(srcp)) { return }
        if isFormatFrame(srcp) {
            createFormatDesc(srcp)
            return
        }
        
        guard let formatDesc = self.videoFormatDesc else { return }
        
        let ptr = UnsafeMutableRawBufferPointer.allocate(byteCount: size, alignment: MemoryLayout<Data>.alignment)
        ptr.copyBytes(from: UnsafeRawBufferPointer(start: frame, count: size))
        
        guard let pp = ptr.baseAddress else { return }
        
        ChiakiSessionBridge.nalReplace(pp, length: Int32(size))

        var blockBuffer: CMBlockBuffer? = nil
       
        guard check(CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: ptr.baseAddress, blockLength: size, blockAllocator: nil, customBlockSource:nil, offsetToData: 0, dataLength: size, flags: 0, blockBufferOut: &blockBuffer), msg: "CMBlockBufferCreateWithMemoryBlock") else {
            ptr.deallocate()
            return
        }
        
        var sampleBuffer: CMSampleBuffer? = nil
        var sampleSize = size
        guard check(CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: blockBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: formatDesc, sampleCount: 1, sampleTimingEntryCount: 0, sampleTimingArray: nil, sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize, sampleBufferOut: &sampleBuffer), msg: "CMSampleBufferCreate") else {
            return
        }
        
        if let buf = sampleBuffer {
            ChiakiSessionBridge.setDisplayImmediately(buf)
            self.display?.enqueue(buf)
        }

    }
}


