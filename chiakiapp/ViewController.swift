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
    
    func startMetal() {
        self.uiView?.removeFromSuperview()

        let v = MTKView(frame: self.view.bounds)
        v.autoresizingMask = [.width, .height]
        self.view.addSubview(v)
        
        v.device = MTLCreateSystemDefaultDevice()
        renderer = YuvRenderer(mtkView: v)
        v.delegate = renderer
        
    }
    
    func onKeyDown(evt: NSEvent)
    {
        var state = ChiakiControllerState()

        if evt.keyCode == KeyCode.leftArrow {
            state.buttons = CHIAKI_CONTROLLER_BUTTON_DPAD_LEFT.rawValue
        }
        if evt.keyCode == KeyCode.rightArrow {
            state.buttons = CHIAKI_CONTROLLER_BUTTON_DPAD_RIGHT.rawValue
        }
        if evt.keyCode == KeyCode.upArrow {
            state.buttons = CHIAKI_CONTROLLER_BUTTON_DPAD_UP.rawValue
        }
        if evt.keyCode == KeyCode.downArrow {
            state.buttons = CHIAKI_CONTROLLER_BUTTON_DPAD_DOWN.rawValue
        }
        if evt.keyCode == KeyCode.return {
            state.buttons = CHIAKI_CONTROLLER_BUTTON_CROSS.rawValue
        }
        if evt.keyCode == KeyCode.escape {
            state.buttons = CHIAKI_CONTROLLER_BUTTON_MOON.rawValue
        }
        if evt.keyCode == KeyCode.p {
            state.buttons = CHIAKI_CONTROLLER_BUTTON_PS.rawValue
        }

        ui.session?.setControllerState(state)
    }

    func onKeyUp(evt: NSEvent) {
        var state = ChiakiControllerState()
        ui.session?.setControllerState(state)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { evt in
            self.onKeyDown(evt: evt)
            return nil
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyUp) { evt in
            self.onKeyUp(evt: evt)
            return nil
        }
        
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

