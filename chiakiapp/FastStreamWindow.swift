//
//  StreamWindow.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 9/4/22.
//

import Foundation
import Cocoa
import SwiftUI
import Combine
import MetalKit
import GameController
import AVFoundation

class FastStreamWindow: NSViewController, NSMenuItemValidation {
    
    var toDispose: [Any] = []
    
    required init?(coder:   NSCoder) {
        super.init(coder: coder)
    }
    
    func check(_ status: OSStatus, msg: String) -> Bool {
        if status != 0 {
            print("\(msg) err=\(status)")
            return false
        }
        return true
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.identifier == NSUserInterfaceItemIdentifier(rawValue: "showCursor") {
            menuItem.title = cursorLogic.wantsShowCursor ? "Hide Cursor" : "Show Cursor"
            return true
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
    
    func isFormatFrame(_ p: UnsafeRawBufferPointer) -> Bool {
        guard p.count > 5 else { return false }
        return p[0] == 0 && p[1] == 0 && p[2] == 0 && p[3] == 1 && p[4] == 103
    }
    
    var videoFormatDesc: CMVideoFormatDescription?
    
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
    
    
    func frameCb(_ frame: UnsafeMutablePointer<UInt8>, size: Int) {
        let srcp = UnsafeRawBufferPointer(start: frame, count: size)
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
    
    var display: AVSampleBufferDisplayLayer?
    @IBOutlet var statusText: NSTextField!
    
    var audioPlayer = AudioQueuePlayer()
    
    var inputState = InputState()
        
    var session: ChiakiSessionBridge?
    
    var timer: Timer?
    var lastTimerRun: UInt64?

    @objc func timerCb() {
        let now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        guard let last = lastTimerRun else {
            lastTimerRun = now
            return
        }
        
        let delta = Double(now - last) / Double(1_000_000_000)
        
        session?.setControllerState(inputState.run(delta))
        
        lastTimerRun = now
        
//        if !self.statusText.isHidden {
//            self.statusText.stringValue = "Audio enq:\(audioPlayer.enqueued) started:\(audioPlayer.isStarted)"
//        }
    }
    
    @IBAction func toggleShowCursor(_ sender: Any?) {
        cursorLogic.toggleShowCursor()
    }

    func toggleFullScreen() {
        self.view.window?.toggleFullScreen(nil)
    }
    
    @IBOutlet var keyboardView: NSView!
    @IBOutlet var keyboardInput: NSTextField!
    
    var isKeyboardInput = false
    
    func setKeyboardInput(_ inp: Bool) {
        isKeyboardInput = inp
        print("isKeyboardInput=\(isKeyboardInput)")
        keyboardView.isHidden = !inp
        if inp {
            keyboardInput.becomeFirstResponder()
            keyboardInput.stringValue = ""
        }
    }
    
    @IBAction func toggleInputKeyboard(_ sender: Any?) {
        self.setKeyboardInput(!isKeyboardInput)
    }
    
    @IBAction func keyboardEnter(_ sender: Any?) {
        session?.setKeyboardText(keyboardInput.stringValue)
        keyboardInput.stringValue = ""
        keyboardView.isHidden = true
        isKeyboardInput = false
    }
    
    var cursorLogic = CursorLogic()
    
    var onDone: () -> Void = {}
    
    func setup(session: ChiakiSessionBridge) {
        print("Session started")
        self.session = session
        session.rawVideoCallback = self.frameCb(_:size:)
        session.audioSettingsCallback = { (ch, sr) in
            self.audioPlayer.startup(channels: Int(ch), sampleRate: Double(sr))
        }
        session.audioFrameCallback = { (buf, count) in
            let data = Data(bytesNoCopy: buf, count: count * 4, deallocator: .none)
            self.audioPlayer.play(data: data)
        }
        session.onKeyboardOpen = { self.setKeyboardInput(true) }
        
        session.start()
    }
    
    func stopSession() {
        session?.stop()
    }
    
    override func viewWillDisappear() {
        stopSession()
        
        cursorLogic.teardown()
                
        for o in toDispose {
            NSEvent.removeMonitor(o)
        }
        toDispose = []
        
        self.onDone()
    }
    
    var watchKeys = Set<UInt16>()

    func disposeOnClose(_ s: Any?) {
        if let o = s {
            toDispose.append(o)
        }
    }
    
    @IBAction func openDocument(_ s: Any?) {
        let op = NSOpenPanel()
        op.allowedContentTypes = [UTType.json]
        if op.runModal() == .OK, let url = op.urls.first {
            if let keymap = loadKeymapFile(file: url) {
                AppUiModel.global.keymap = keymap
                self.inputState.steps = keymap
            } else {
                let alert = NSAlert()
                alert.messageText = "Error loading keymap"
                alert.runModal()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        cursorLogic.setup()
        
        self.inputState.steps = AppUiModel.global.keymap
        
        disposeOnClose(NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { evt in
            let evt: NSEvent = evt
            
            self.inputState.keyboard.onFlagsChanged(evt: evt)
            
            return evt
        })
        
        disposeOnClose(NSEvent.addLocalMonitorForEvents(matching: .keyDown) { evt in
            let nsevt: NSEvent = evt
            
            if nsevt.modifierFlags.contains(.command) {
                return evt
            }
            
            if self.isKeyboardInput {
                return evt
            }
            
            _ = self.inputState.keyboard.onKeyDown(evt: evt)
            return nil
        })
        
        disposeOnClose(NSEvent.addLocalMonitorForEvents(matching: .keyUp) { evt in
            return self.inputState.keyboard.onKeyUp(evt: evt)
        })
        
        disposeOnClose(NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { evt in
            return self.inputState.mouse.onMouseMoved(evt: evt)
        })

        
        let tim = Timer(timeInterval: 1.0 / 120, target: self, selector: #selector(timerCb), userInfo: nil, repeats: true)
        RunLoop.current.add(tim, forMode: .common)
        self.timer = tim
                
        self.view.wantsLayer = true
        
        let disp = AVSampleBufferDisplayLayer()
        disp.bounds = self.view.bounds
        disp.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        disp.backgroundColor = CGColor.black
        disp.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        if let l = self.view.layer {
            l.addSublayer(disp)
            self.display = disp
        }

    }
}
