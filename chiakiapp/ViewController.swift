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
            
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let v = NSHostingView(rootView: ConsoleListView(discover: ui.discover).environmentObject(ui))
        self.view.addSubview(v)
        v.frame = self.view.bounds
        v.autoresizingMask = [.width, .height]    
        
        self.sessionSub = ui.$session.sink { bridge in
            if let sess = bridge {
                guard let sb = NSStoryboard.main,
                      let wc = sb.instantiateController(withIdentifier: "metalWindow") as? NSWindowController,
                      let vc = wc.contentViewController as? StreamWindow
                    else { return }
                wc.window?.title = sess.host
                vc.setup(session: sess)
                wc.showWindow(self)
            }
        }
        
    }
    
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

