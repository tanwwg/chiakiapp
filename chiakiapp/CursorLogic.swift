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
    
    init() {
        wantsShowCursor = UserDefaults.standard.bool(forKey: "wantsShowCursor")
    }
    
    func setup() {
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: nil) { [weak self] _ in
            self?.synchronizeCursor()
        }

        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: nil) { [weak self] _ in
            self?.showCursor()
        }
    }
    
    func teardown() {
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)

    }
    
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
