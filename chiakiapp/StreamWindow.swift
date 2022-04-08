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

class StreamWindow: NSViewController {
    
    required init?(coder:   NSCoder) {
            super.init(coder: coder)
        }
    
    func frameCb(_ frame: UnsafeMutablePointer<AVFrame>) {
        
        let data = [
            Data(bytesNoCopy: frame.pointee.data.0!, count: 1920*1080, deallocator: .none),
            Data(bytesNoCopy: frame.pointee.data.1!, count: 1920*1080/4, deallocator: .none),
            Data(bytesNoCopy: frame.pointee.data.2!, count: 1920*1080/4, deallocator: .none)]
            
        self.renderer?.loadYuv420Texture(data: data, width: 1920, height: 1080)
    }
    
    
    @IBOutlet var statusText: NSTextField!
    @IBOutlet var metalView: MTKView!
    
    var audioPlayer = AudioQueuePlayer()
    var renderer: YuvRenderer?
    
    var inputState = InputState()
    
    var timer: Timer?
    
    var session: ChiakiSessionBridge?

    @objc func timerCb() {
        session?.setControllerState(inputState.run())
        
        if !self.statusText.isHidden {
            self.statusText.stringValue = "Audio enq:\(audioPlayer.enqueued) started:\(audioPlayer.isStarted)"
        }
    }

    func toggleFullScreen() {
        self.view.window?.toggleFullScreen(nil)
    }
    
    var isCursorHidden = false
    func toggleCursor() {
        if isCursorHidden {
            NSCursor.unhide()
            CGAssociateMouseAndMouseCursorPosition(1)
            isCursorHidden = false
        } else {
            NSCursor.hide()
            CGAssociateMouseAndMouseCursorPosition(0)
            isCursorHidden = true
        }
    }
    
    func setup(session: ChiakiSessionBridge) {
        print("Session started")
        self.session = session
        session.videoCallback = self.frameCb
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
    }
    
    var watchKeys = Set<UInt16>()


    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("loaded")
        
//        self.audioPlayer.startup(sampleRate: 48000)

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
        
        self.metalView.device = MTLCreateSystemDefaultDevice()
        renderer = YuvRenderer(mtkView: self.metalView)
        self.metalView.delegate = renderer

        if !(self.view.window?.contentView?.isInFullScreenMode ?? false) {
//            self.view.window?.toggleFullScreen(nil)
        }

//        self.toggleCursor()
    }
}
