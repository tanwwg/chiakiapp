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
            let data = Data(bytesNoCopy: frame.pointee.data.0!, count: 1920*1080, deallocator: .none)
    //        let data = Data(bytes: frame.pointee.data.0!, count: 1920*1080)
            self.renderer?.loadYuv420Texture(data: [data], width: 1920, height: 1080)

        }
//        try! data.write(to: URL(fileURLWithPath: "/Users/tjtan/downloads/test.raw"))
    }
    
    var uiView: NSView?
    var metalView: MTKView?
    var renderer: YuvRenderer?
    
    var inputState = InputState()
    
    var timer: Timer?
    
    @objc func timerCb() {
        ui.session?.setControllerState(inputState.run())
    }
    
    func startMetal() {
        self.uiView?.removeFromSuperview()

        let v = MTKView(frame: self.view.bounds)
        v.autoresizingMask = [.width, .height]
        self.view.addSubview(v)
        
        v.device = MTLCreateSystemDefaultDevice()
        renderer = YuvRenderer(mtkView: v)
        v.delegate = renderer
        
        NSCursor.hide()
        self.view.window?.toggleFullScreen(nil)
        CGAssociateMouseAndMouseCursorPosition(0)
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

