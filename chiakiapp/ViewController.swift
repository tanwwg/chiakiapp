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
import UniformTypeIdentifiers

class ViewController: NSViewController {
    
    let ui = AppUiModel.global
    var sessionSub: AnyCancellable?
    
    @IBAction func openDocument(_ s: Any?) {
        let op = NSOpenPanel()
        op.allowedContentTypes = [UTType.json]
        if op.runModal() == .OK, let url = op.urls.first {
            do {
                _ = try ui.loadKeymap(url: url)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
            
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let v = NSHostingView(rootView: ConsoleListView(discover: ui.discover).environmentObject(ui))
        self.view.addSubview(v)
        v.frame = self.view.bounds
        v.autoresizingMask = [.width, .height]    
        
        self.sessionSub = ui.$session.sink { bridge in
            if let sess = bridge {
                self.startSession(sess)
            }
        }
        
    }
    
    func startSession(_ session: ChiakiSessionBridge) {
        guard let sb = NSStoryboard.main,
              let wc = sb.instantiateController(withIdentifier: "fastStream") as? NSWindowController,
              let vc = wc.contentViewController as? FastStreamWindow
            else { return }
        wc.window?.title = session.host
        vc.setup(session: session)
        wc.showWindow(self)
        wc.window?.toggleFullScreen(self)
        
        self.view.window?.setIsVisible(false)
        vc.onDone = {
            if let w = self.view.window {
                w.setIsVisible(true)
            }
            self.ui.discover.discover.startDiscover(seconds: 10.0)
        }
    }
    
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

