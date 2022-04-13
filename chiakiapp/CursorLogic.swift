//
//  CursorLogic.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 11/4/22.
//

import Foundation
import Cocoa

class CursorLogic {
    
    var wantsShowCursor = false
    var isCursorHidden = false
    var window: NSWindow? = nil
    
    var observers: [Any] = []
    
    init() {
        wantsShowCursor = UserDefaults.standard.bool(forKey: "wantsShowCursor")
    }
    
    func setup(window: NSWindow) {
        print("CursorLogic setupe")
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: nil) { [weak self] (n: Notification) in
            print("didBecomeKeyNotification")
            self?.synchronizeCursor()
        })

        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: nil) { [weak self] _ in
            self?.showCursor()
        })
    }
    
    func teardown() {
        for o in observers {
            NotificationCenter.default.removeObserver(o)
        }
        observers = []
        
        print("teardown")
        self.showCursor()
    }
    
    func showCursor() {
        print("Showing cursor")
        NSCursor.unhide()
        CGAssociateMouseAndMouseCursorPosition(1)
        isCursorHidden = false
    }
    func hideCursor() {
        print("Hiding cursor")
        NSCursor.hide()
        CGAssociateMouseAndMouseCursorPosition(0)
        isCursorHidden = true
    }
    
    /// make sure the cusor is synced with the wantsShowCursor state
    func synchronizeCursor() {
        if wantsShowCursor {
            showCursor()
        } else {
            hideCursor()
        }
    }
    
    func toggleShowCursor() {
        wantsShowCursor = !wantsShowCursor
        UserDefaults.standard.set(wantsShowCursor, forKey: "wantsShowCursor")
        UserDefaults.standard.synchronize()
        
        synchronizeCursor()
    }
    
}
