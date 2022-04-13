//
//  KeyCodeMap.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 13/4/22.
//

import Foundation

struct KeyCodeMap {
    var map: [String:UInt16] = [:]
    
    static let standard = KeyCodeMap()
    
    init() {
        map["a"] = KeyCode.a
        map["b"] = KeyCode.b
        map["c"] = KeyCode.c
        map["d"] = KeyCode.d
        map["e"] = KeyCode.e
        map["f"] = KeyCode.f
        map["g"] = KeyCode.g
        map["h"] = KeyCode.h
        map["i"] = KeyCode.i
        map["j"] = KeyCode.j
        map["k"] = KeyCode.k
        map["l"] = KeyCode.l
        map["m"] = KeyCode.m
        map["n"] = KeyCode.n
        map["o"] = KeyCode.o
        map["p"] = KeyCode.p
        map["q"] = KeyCode.q
        map["r"] = KeyCode.r
        map["s"] = KeyCode.s
        map["t"] = KeyCode.t
        map["u"] = KeyCode.u
        map["v"] = KeyCode.v
        map["w"] = KeyCode.w
        map["x"] = KeyCode.x
        map["y"] = KeyCode.y
        map["z"] = KeyCode.z
        
        map["number0"] = KeyCode.number0
        map["number1"] = KeyCode.number1
        map["number2"] = KeyCode.number2
        map["number3"] = KeyCode.number3
        map["number4"] = KeyCode.number4
        map["number5"] = KeyCode.number5
        map["number6"] = KeyCode.number6
        map["number7"] = KeyCode.number7
        map["number8"] = KeyCode.number8
        map["number9"] = KeyCode.number9
        
        map["keypad0"] = KeyCode.keypad0
        map["keypad1"] = KeyCode.keypad1
        map["keypad2"] = KeyCode.keypad2
        map["keypad3"] = KeyCode.keypad3
        map["keypad4"] = KeyCode.keypad4
        map["keypad5"] = KeyCode.keypad5
        map["keypad6"] = KeyCode.keypad6
        map["keypad7"] = KeyCode.keypad7
        map["keypad8"] = KeyCode.keypad8
        map["keypad9"] = KeyCode.keypad9
        map["keypadClear"] = KeyCode.keypadClear
        map["keypadDivide"] = KeyCode.keypadDivide
        map["keypadEnter"] = KeyCode.keypadEnter
        map["keypadEquals"] = KeyCode.keypadEquals
        map["keypadMinus"] = KeyCode.keypadMinus
        map["keypadPlus"] = KeyCode.keypadPlus
        map["pageDown"] = KeyCode.pageDown
        map["pageUp"] = KeyCode.pageUp
        map["end"] = KeyCode.end
        map["home"] = KeyCode.home

        map["f1"] = KeyCode.f1
        map["f2"] = KeyCode.f2
        map["f3"] = KeyCode.f3
        map["f4"] = KeyCode.f4
        map["f5"] = KeyCode.f5
        map["f6"] = KeyCode.f6
        map["f7"] = KeyCode.f7
        map["f8"] = KeyCode.f8
        map["f9"] = KeyCode.f9
        map["f10"] = KeyCode.f10
        map["f11"] = KeyCode.f11
        map["f12"] = KeyCode.f12
        map["f13"] = KeyCode.f13
        map["f14"] = KeyCode.f14
        map["f15"] = KeyCode.f15
        map["f16"] = KeyCode.f16
        map["f17"] = KeyCode.f17
        map["f18"] = KeyCode.f18
        map["f19"] = KeyCode.f19
        map["f20"] = KeyCode.f20

        map["apostrophe"] = KeyCode.apostrophe
        map["backApostrophe"] = KeyCode.backApostrophe
        map["backslash"] = KeyCode.backslash
        map["capsLock"] = KeyCode.capsLock
        map["comma"] = KeyCode.comma
        map["help"] = KeyCode.help
        map["forwardDelete"] = KeyCode.forwardDelete
        map["decimal"] = KeyCode.decimal
        map["delete"] = KeyCode.delete
        map["equals"] = KeyCode.equals
        map["escape"] = KeyCode.escape
        map["leftBracket"] = KeyCode.leftBracket
        map["minus"] = KeyCode.minus
        map["multiply"] = KeyCode.multiply
        map["period"] = KeyCode.period
        map["return"] = KeyCode.return
        map["rightBracket"] = KeyCode.rightBracket
        map["semicolon"] = KeyCode.semicolon
        map["slash"] = KeyCode.slash
        map["space"] = KeyCode.space
        map["tab"] = KeyCode.tab

        map["mute"] = KeyCode.mute
        map["volumeDown"] = KeyCode.volumeDown
        map["volumeUp"] = KeyCode.volumeUp

        map["command"] = KeyCode.command
        map["rightCommand"] = KeyCode.rightCommand
        map["control"] = KeyCode.control
        map["rightControl"] = KeyCode.rightControl
        map["function"] = KeyCode.function
        map["option"] = KeyCode.option
        map["rightOption"] = KeyCode.rightOption
        map["shift"] = KeyCode.shift
        map["rightShift"] = KeyCode.rightShift
        
        map["downArrow"] = KeyCode.downArrow
        map["leftArrow"] = KeyCode.leftArrow
        map["rightArrow"] = KeyCode.rightArrow
        map["upArrow"] = KeyCode.upArrow

    }
}
