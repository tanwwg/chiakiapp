//
//  ViewController.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 29/3/22.
//

import Cocoa
import SwiftUI
import Combine
import MetalKit
import GameController

class ViewController: NSViewController {
    
    let ui = AppUiModel()
    var sessionSub: AnyCancellable?
    
    func frameCb(_ frame: UnsafeMutablePointer<AVFrame>) {
//        print("\(frame.pointee.width)x\(frame.pointee.height) linesize=\(frame.pointee.linesize.0),\(frame.pointee.linesize.1),\(frame.pointee.linesize.2)")
        
        autoreleasepool {
            let data = [
                Data(bytesNoCopy: frame.pointee.data.0!, count: 1920*1080, deallocator: .none),
                Data(bytesNoCopy: frame.pointee.data.1!, count: 1920*1080/4, deallocator: .none),
                Data(bytesNoCopy: frame.pointee.data.2!, count: 1920*1080/4, deallocator: .none)]
                
    //        let data = Data(bytes: frame.pointee.data.0!, count: 1920*1080)
            self.renderer?.loadYuv420Texture(data: data, width: 1920, height: 1080)

        }
//        try! data.write(to: URL(fileURLWithPath: "/Users/tjtan/downloads/test.raw"))
    }
    
    var audioPlayer = AudioPlayer()
    
    var uiView: NSView?
    var metalView: MTKView?
    var renderer: YuvRenderer?
    
    var inputState = InputState()
    
    var timer: Timer?
    
    @objc func timerCb() {
        ui.session?.setControllerState(inputState.run())
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
    
    func startMetal() {
        self.uiView?.removeFromSuperview()

        let v = MTKView(frame: self.view.bounds)
        v.autoresizingMask = [.width, .height]
        self.view.addSubview(v)
        
        v.device = MTLCreateSystemDefaultDevice()
        renderer = YuvRenderer(mtkView: v)
        v.delegate = renderer

        if !(self.view.window?.contentView?.isInFullScreenMode ?? false) {
//            self.view.window?.toggleFullScreen(nil)
        }

        self.toggleCursor()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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

        ]

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { evt in
            let nsevt: NSEvent = evt
            if nsevt.keyCode == KeyCode.q && nsevt.modifierFlags.contains(.command) {
                NSApplication.shared.terminate(self)
            }
            if nsevt.keyCode == KeyCode.f && nsevt.modifierFlags.contains(.command) {
                self.toggleFullScreen()
            }
            if nsevt.keyCode == KeyCode.c && nsevt.modifierFlags.contains(.command) {
                self.toggleCursor()
            }

            return self.inputState.keyboard.onKeyDown(evt: evt)
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

        self.sessionSub = ui.$session.sink { session in
            if let sess = session {
                print("Session started")
                sess.videoCallback = self.frameCb
                sess.audioSettingsCallback = { (ch, sr) in
                    assert(ch == 2)
                    self.audioPlayer.startup(sampleRate: Double(sr))
                }
                sess.audioFrameCallback = { (buf, count) in
                    self.audioPlayer.play16bit2ch(data: Data(bytesNoCopy: buf, count: count * 4, deallocator: .none))
                }
                
                sess.start()
                
                self.startMetal()
            }
        }
        
        let v = NSHostingView(rootView: ConsoleListView(discover: ui.discover).environmentObject(ui))
        self.view.addSubview(v)
        v.frame = self.view.bounds
        v.autoresizingMask = [.width, .height]
        uiView = v
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

