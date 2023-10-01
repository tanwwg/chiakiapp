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
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.identifier == NSUserInterfaceItemIdentifier(rawValue: "showCursor") {
            menuItem.title = cursorLogic.wantsShowCursor ? "Hide Cursor" : "Show Cursor"
            return true
        }
        return true
    }
        

    var display: AVSampleBufferDisplayLayer?
    @IBOutlet var statusText: NSTextField!
    
    var audioPlayer = AudioQueuePlayer()
    
    var inputState = InputState()
        
    var session: ChiakiSessionBridge?
    
    var lastTimerRun: UInt64?
    var timerQueue = DispatchQueue(label: "timer")
    var timer: DispatchSourceTimer?
        
    func initTimer() {
        let t = DispatchSource.makeTimerSource(flags: [.strict], queue: timerQueue)
        t.schedule(deadline: .now(), repeating: .milliseconds(8), leeway: .milliseconds(4))
        t.setEventHandler(handler: timerCb)
        t.activate()
        self.timer = t
    }
    
    var statsTimeStart: UInt64 = 0
    var statsCounter = 0

    func timerCb() {
        let now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        guard let last = lastTimerRun else {
            lastTimerRun = now
            return
        }
        
        /// print timer cb stats
//        if statsCounter == 0 {
//            statsTimeStart = now
//        }
//        statsCounter += 1
//        if statsCounter == 100 {
//            statsCounter = 0
//            let deltaMs: Int = Int((now - statsTimeStart) / 100_000_000)
//            self.statusText.stringValue = "\(deltaMs)"
//
//        }

        
        let delta = Double(now - last) / Double(1_000_000_000)
        
        
        session?.setControllerState(inputState.run(delta))
        
        lastTimerRun = now
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
        let s = keyboardInput.stringValue
        if s.isEmpty { return }
        
        print("keyboardEnter \(keyboardInput.stringValue)")
        session?.setKeyboardText(keyboardInput.stringValue)
        keyboardInput.stringValue = ""
        keyboardView.isHidden = true
        isKeyboardInput = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.session?.acceptKeyboard()
        }
    }
    
    var cursorLogic = CursorLogic()
    
    let videoController = VideoController()
    
    var onDone: () -> Void = {}
    
    func setup(session: ChiakiSessionBridge) {
        print("Session started")
        self.session = session
        session.rawVideoCallback = self.videoController.handleVideoFrame(_:size:)
        session.audioSettingsCallback = { (ch, sr) in
            self.audioPlayer.startup(channels: Int(ch), sampleRate: Double(sr))
        }
        session.audioFrameCallback = { (buf, count) in
            let data = Data(bytesNoCopy: buf, count: count * 4, deallocator: .none)
            self.audioPlayer.play(data: data)
        }
        session.onKeyboardOpen = { DispatchQueue.main.async { self.setKeyboardInput(true) } }
        
        session.isLoggingEnabled = false
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
        
        powerManager.enableSleep()
        
        self.timer?.cancel()
        
        self.onDone()
    }
    
    var watchKeys = Set<UInt16>()

    func disposeOnClose(_ s: Any?) {
        if let o = s {
            toDispose.append(o)
        }
    }
    
    @IBAction func saveDocument(_ s: Any?) {
        session?.sleep()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.view.window?.close()
        }
        
    }
        
    override func viewWillAppear() {
        super.viewWillAppear()
        
        if let w = self.view.window {
            cursorLogic.setup(window: w)
        }
    }
    
    let powerManager = PowerManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        powerManager.disableSleep(reason: "Chiaki streaming")
        
        if let cmd = AppUiModel.global.startStreamCommandProp {
            do {
                try shell(cmd)
            } catch {
                NSAlert(error: error).runModal()                
            }
        }
        
        self.inputState.steps = AppUiModel.global.keymap
        
        disposeOnClose(NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { evt in
            self.inputState.mouse.onMouseEvent(button: .left, isDown: true)
            return evt
        })
        disposeOnClose(NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { evt in
            self.inputState.mouse.onMouseEvent(button: .left, isDown: false)
            return evt
        })
        disposeOnClose(NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { evt in
            self.inputState.mouse.onMouseEvent(button: .right, isDown: true)
            return evt
        })
        disposeOnClose(NSEvent.addLocalMonitorForEvents(matching: .rightMouseUp) { evt in
            self.inputState.mouse.onMouseEvent(button: .right, isDown: false)
            return evt
        })

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
            
            self.inputState.keyboard.onKeyDown(evt: evt)
            
            return nil
        })
        
        disposeOnClose(NSEvent.addLocalMonitorForEvents(matching: .keyUp) { evt in
            self.inputState.keyboard.onKeyUp(evt: evt)
            return evt
        })
        
        disposeOnClose(NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { evt in
            return self.inputState.mouse.onMouseMoved(evt: evt)
        })
        disposeOnClose(NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { evt in
            return self.inputState.mouse.onMouseMoved(evt: evt)
        })
        disposeOnClose(NSEvent.addLocalMonitorForEvents(matching: .rightMouseDragged) { evt in
            return self.inputState.mouse.onMouseMoved(evt: evt)
        })

        self.initTimer()
                
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
        
        self.videoController.display = self.display

    }
}
