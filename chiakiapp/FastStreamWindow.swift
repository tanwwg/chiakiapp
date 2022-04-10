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
            menuItem.title = isCursorHidden ? "Show Cursor" : "Hide Cursor"
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
    
    var timer: Timer?
    
    var session: ChiakiSessionBridge?

    @objc func timerCb() {
        session?.setControllerState(inputState.run())
        
//        if !self.statusText.isHidden {
//            self.statusText.stringValue = "Audio enq:\(audioPlayer.enqueued) started:\(audioPlayer.isStarted)"
//        }
    }

    func toggleFullScreen() {
        self.view.window?.toggleFullScreen(nil)
    }
    
    var isCursorHidden = false
    func showCursor() {
        NSCursor.unhide()
        CGAssociateMouseAndMouseCursorPosition(1)
        isCursorHidden = false
    }
    func hideCursor() {
        NSCursor.hide()
        CGAssociateMouseAndMouseCursorPosition(0)
        isCursorHidden = true
    }
    
    @IBAction func toggleShowCursor(_ sender: Any?) {
        if isCursorHidden {
            showCursor()
        } else {
            hideCursor()
        }
    }
    
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
        
        session.start()
    }
    
    func stopSession() {
        session?.stop()
    }
    
    override func viewWillDisappear() {
        stopSession()
        self.showCursor()
        
        NotificationCenter.default.removeObserver(self, name: NSWindow.didEnterFullScreenNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didExitFullScreenNotification, object: nil)
    }
    
    var watchKeys = Set<UInt16>()


    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(forName: NSWindow.didEnterFullScreenNotification, object: nil, queue: nil) { [weak self] _ in
            self?.hideCursor()
        }

        NotificationCenter.default.addObserver(forName: NSWindow.didExitFullScreenNotification, object: nil, queue: nil) { [weak self] _ in
            self?.showCursor()
        }

        self.inputState.steps = [
            ButtonInputStep(check: KeyboardInputCheck(key: KeyCode.e), button: CHIAKI_CONTROLLER_BUTTON_CROSS),
            ButtonInputStep(check: KeyboardInputCheck(key: KeyCode.q), button: CHIAKI_CONTROLLER_BUTTON_MOON),
            ButtonInputStep(check: KeyboardInputCheck(key: KeyCode.f), button: CHIAKI_CONTROLLER_BUTTON_BOX),
            ButtonInputStep(check: KeyboardInputCheck(key: KeyCode.r), button: CHIAKI_CONTROLLER_BUTTON_PYRAMID),
            ButtonInputStep(check: KeyboardInputCheck(key: KeyCode.p), button: CHIAKI_CONTROLLER_BUTTON_PS),
            ButtonInputStep(check: KeyboardInputCheck(key: KeyCode.comma), button: CHIAKI_CONTROLLER_BUTTON_L1),
            ButtonInputStep(check: KeyboardInputCheck(key: KeyCode.period), button: CHIAKI_CONTROLLER_BUTTON_R1),
            ButtonInputStep(check: KeyboardInputCheck(key: KeyCode.shift), button: CHIAKI_CONTROLLER_BUTTON_L3),
            ButtonInputStep(check: KeyboardInputCheck(key: KeyCode.rightShift), button: CHIAKI_CONTROLLER_BUTTON_R3),
            ButtonInputStep(check: KeyboardInputCheck(key: KeyCode.upArrow), button: CHIAKI_CONTROLLER_BUTTON_DPAD_UP),
            ButtonInputStep(check: KeyboardInputCheck(key: KeyCode.downArrow), button: CHIAKI_CONTROLLER_BUTTON_DPAD_DOWN),
            ButtonInputStep(check: KeyboardInputCheck(key: KeyCode.leftArrow), button: CHIAKI_CONTROLLER_BUTTON_DPAD_LEFT),
            ButtonInputStep(check: KeyboardInputCheck(key: KeyCode.rightArrow), button: CHIAKI_CONTROLLER_BUTTON_DPAD_RIGHT),
            ButtonInputStep(check: KeyboardInputCheck(key: KeyCode.escape), button: CHIAKI_CONTROLLER_BUTTON_OPTIONS),
            ButtonInputStep(check: KeyboardInputCheck(key: KeyCode.t), button: CHIAKI_CONTROLLER_BUTTON_TOUCHPAD),
            KeyToStickInputStep(fixAcceleration: 1,
                                minus: nil,
                                plus: KeyboardInputCheck(key: KeyCode.rightBracket),
                                output: FloatToStickStep(stick: .R2)),
            KeyToStickInputStep(fixAcceleration: 1,
                                minus: nil,
                                plus: KeyboardInputCheck(key: KeyCode.leftBracket),
                                output: FloatToStickStep(stick: .L2)),
            KeyToStickInputStep(fixAcceleration: 0.01,
                                minus: KeyboardInputCheck(key: KeyCode.w),
                                plus: KeyboardInputCheck(key: KeyCode.s),
                                output: FloatToStickStep(stick: .leftY)),
            KeyToStickInputStep(fixAcceleration: 0.01,
                                minus: KeyboardInputCheck(key: KeyCode.a),
                                plus: KeyboardInputCheck(key: KeyCode.d),
                                output: FloatToStickStep(stick: .leftX)),
            FloatInputStep(inStep: MouseInput(dir: .x, sensitivity: 0.2), outStep: FloatToStickStep(stick: .rightX)),
            FloatInputStep(inStep: MouseInput(dir: .y, sensitivity: 0.2), outStep: FloatToStickStep(stick: .rightY)),
            KeyToStickInputStep(fixAcceleration: 0.01,
                                minus: KeyboardInputCheck(key: KeyCode.j),
                                plus: KeyboardInputCheck(key: KeyCode.l),
                                output: FloatToStickStep(stick: .rightX)),
            KeyToStickInputStep(fixAcceleration: 0.01,
                                minus: KeyboardInputCheck(key: KeyCode.i),
                                plus: KeyboardInputCheck(key: KeyCode.k),
                                output: FloatToStickStep(stick: .rightY)),
        ]
        
        
        for step in self.inputState.steps {
            if let bis = step as? ButtonInputStep {
                if let kb = bis.check as? KeyboardInputCheck {
                    watchKeys.insert(kb.key)
                }
            }
            
            if let ksi = step as? KeyToStickInputStep {
                if let kb = ksi.minus as? KeyboardInputCheck { watchKeys.insert(kb.key) }
                if let kb = ksi.plus as? KeyboardInputCheck { watchKeys.insert(kb.key) }
            }

        }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { evt in
            let nsevt: NSEvent = evt
            
            if nsevt.modifierFlags.contains(.command) {
                return evt
            }
            
            if self.watchKeys.contains(nsevt.keyCode) {
                _ = self.inputState.keyboard.onKeyDown(evt: evt)
                return nil
            } else {
                return nsevt
            }
//            if nsevt.keyCode == KeyCode.w && nsevt.modifierFlags.contains(.command) {
//                self.stopSession()
//                self.view.window?.close()
//            }
//            if nsevt.keyCode == KeyCode.f && nsevt.modifierFlags.contains(.command) {
//                self.toggleFullScreen()
//            }
//            if nsevt.keyCode == KeyCode.c && nsevt.modifierFlags.contains(.command) {
//                self.toggleCursor()
//            }

            
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyUp) { evt in
            return self.inputState.keyboard.onKeyUp(evt: evt)
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { evt in
            return self.inputState.mouse.onMouseMoved(evt: evt)
        }

        
        let tim = Timer(timeInterval: 1.0 / 120, target: self, selector: #selector(timerCb), userInfo: nil, repeats: true)
        RunLoop.current.add(tim, forMode: .common)
        self.timer = tim
        
//        self.toggleShowCursor(self)
        
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
