//
//  InputManager.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 31/3/22.
//

import Foundation
import AppKit
import GameController




class InputState {
    var keyboard = KeyboardManager()
    var mouse = MouseManager()
    var controller: GCExtendedGamepad? = nil
    var keyDowns = Set<UInt16>()
    
    var controllerState = ChiakiControllerState()
    var steps: [InputStep] = []
    
    var deltaTime: CGFloat = 0.0
    
    var events = EventsManager()
    
    init() {
//        setupKeyboard()
//        setupMouse()
    }
    
    func setupMouse() {
        events.monitor(matching: .leftMouseDown) { evt in
            self.mouse.onMouseEvent(button: .left, isDown: true)
            return evt
        }
        events.monitor(matching: .leftMouseUp) { evt in
            self.mouse.onMouseEvent(button: .left, isDown: false)
            return evt
        }
        events.monitor(matching: .rightMouseDown) { evt in
            self.mouse.onMouseEvent(button: .right, isDown: true)
            return evt
        }
        events.monitor(matching: .rightMouseUp) { evt in
            self.mouse.onMouseEvent(button: .right, isDown: false)
            return evt
        }
        events.monitor(matching: .mouseMoved) { evt in
            self.mouse.onMouseMoved(evt: evt)
            return evt
        }
        events.monitor(matching: .leftMouseDragged) { evt in
            self.mouse.onMouseMoved(evt: evt)
            return evt
        }
        events.monitor(matching: .rightMouseDragged) { evt in
            self.mouse.onMouseMoved(evt: evt)
            return evt
        }
    }
    
    func setupKeyboard() {
        events.monitor(matching: .flagsChanged) { evt in
            let evt: NSEvent = evt
            self.keyboard.onFlagsChanged(evt: evt)
            return evt
        }
        
        events.monitor(matching: .keyDown) { evt in
            let nsevt: NSEvent = evt
            if nsevt.modifierFlags.contains(.command) {
                return evt
            }
            self.keyboard.onKeyDown(evt: evt)
            return nil
        }
        
        events.monitor(matching: .keyUp) { evt in
            self.keyboard.onKeyUp(evt: evt)
            return evt
        }

    }
    
    func run(_ inDeltaTime: CGFloat) -> ChiakiControllerState {
        controllerState = ChiakiControllerState()
        
        self.deltaTime = inDeltaTime
        self.controller = GCController.current?.extendedGamepad?.capture()
        keyDowns = self.keyboard.getKeyDowns()
        
        for step in steps {
            step.run(input: self)
        }

        // after reading mouse deltas, clear them
        // otherwise, if theres no more mouse move, it'll continue to return the last entry
        self.mouse.clear()

        return controllerState
    }
}

/// Theoretically need to make this threadsafe, but its all primitives
class MouseManager {
    
    var mouseDeltaX: CGFloat = 0.0
    var mouseDeltaY: CGFloat = 0.0

    var isLeftDown = false
    var isRightDown = false
    
    func onMouseMoved(evt: NSEvent) {
        mouseDeltaX = evt.deltaX
        mouseDeltaY = evt.deltaY
    }
    
    func clear() {
        mouseDeltaX = 0
        mouseDeltaY = 0
    }

    func onMouseEvent(button: MouseButton, isDown: Bool) {
        switch(button) {
        case .left: isLeftDown = isDown
        case .right: isRightDown = isDown
        }
    }
    
    func isDown(button: MouseButton) -> Bool {
        switch(button) {
        case .left: return isLeftDown
        case .right: return isRightDown
        }
    }
}

protocol BinaryInputCheck {
    func IsToggled(input: InputState) -> Bool
    func describe() -> String
}

protocol FloatStep {
    func run(value: CGFloat, input: InputState) -> Void
    func describe() -> String
}

protocol GetFloatStep {
    func run(input: InputState) -> CGFloat
    func describe() -> String
}

enum ControllerStick {
    case leftX, leftY, rightX, rightY, L2, R2
}

class FloatToStickStep: FloatStep {
    init(stick: ControllerStick) {
        self.stick = stick
    }
    
    let stick: ControllerStick
    
    func norm(_ a: UInt8) -> CGFloat {
        return CGFloat(a) / CGFloat(UInt8.max)
    }

    func norm(_ a: Int16) -> CGFloat {
        return CGFloat(a) / CGFloat(Int16.max)
    }

    func clamp(_ a: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        return min(max(a, lower), upper)
    }
    
    func unnormUInt8(_ a: CGFloat) -> UInt8 {
        return UInt8(clamp(a, lower: 0, upper: 1.0) * CGFloat(UInt8.max))
    }

    func unnormInt16(_ a: CGFloat) -> Int16 {
        return Int16(clamp(a, lower: -1.0, upper: 1.0) * CGFloat(Int16.max))
    }

    func run(value: CGFloat, input: InputState) -> Void {
        
        switch (stick) {
        case .R2: input.controllerState.r2_state = unnormUInt8(value)
        case .L2: input.controllerState.l2_state = unnormUInt8(value)
        case .leftX: input.controllerState.left_x = unnormInt16(value)
        case .leftY: input.controllerState.left_y = unnormInt16(value)
        case .rightX: input.controllerState.right_x = unnormInt16(value)
        case .rightY: input.controllerState.right_y = unnormInt16(value)
        }
    }
    
    func describe() -> String {
        return "\(stick)"
    }
}

class InputStep {
    func run(input: InputState) {
        preconditionFailure("This method must be overridden")
    }
    
    func describe() -> String {
        preconditionFailure("This method must be overridden")
    }
}

enum MouseButton: String, Codable {
    case left, right
}

class MouseInputCheck: BinaryInputCheck {
    internal init(button: MouseButton) {
        self.button = button
    }
    
    let button: MouseButton
    
    func IsToggled(input: InputState) -> Bool {
        return input.mouse.isDown(button: self.button)
    }
    
    func describe() -> String {
        return "\(button)"
    }
}

class GameControllerInputCheck: BinaryInputCheck {
    
    let button: KMButtonOutput
    internal init(button: KMButtonOutput) {
        self.button = button
    }
    
    func isTouchpad(gc: GCExtendedGamepad) -> GCControllerButtonInput? {
        if let ds = gc as? GCDualShockGamepad {
            return ds.touchpadButton
        }
        if let dss = gc as? GCDualSenseGamepad {
            return dss.touchpadButton
        }
        return gc.allTouchpads.first?.button
    }
    
    func getInput(gc: GCExtendedGamepad) -> GCControllerButtonInput? {
        
        switch (button) {
        case .circle: return gc.buttonB
        case .cross: return gc.buttonA
        case .square: return gc.buttonX
        case .triangle: return gc.buttonY
        case .dpad_up: return gc.dpad.up
        case .dpad_down: return gc.dpad.down
        case .dpad_right: return gc.dpad.right
        case .dpad_left: return gc.dpad.left
        case .l1: return gc.leftShoulder
        case .r1: return gc.rightShoulder
        case .l3: return gc.leftThumbstickButton
        case .r3: return gc.rightThumbstickButton
        case .option: return gc.buttonMenu
        case .share: return gc.buttonOptions
        case .ps: return gc.buttonHome
        case .touchpad: return isTouchpad(gc: gc)
        }
    }
        
    func IsToggled(input: InputState) -> Bool {
        guard let gc = input.controller else { return false }
        
        guard let inp = getInput(gc: gc) else { return false }
        
        return inp.isPressed
    }
    
    func describe() -> String {
        return "Controller \(button)"
    }
}

class KeyboardInputCheck: BinaryInputCheck {
    init(desc: String, key: UInt16) {
        self.desc = desc
        self.key = key
    }
    
    let key: UInt16
    let desc: String
    
    func IsToggled(input: InputState) -> Bool {
        return input.keyDowns.contains(key)
    }
    
    func describe() -> String {
        return "Key \(desc)"
    }
}

enum GameControllerDir: String, Codable {
    case leftx, lefty, rightx, righty
}

class GameControllerFloatInput: GetFloatStep {
    internal init(dir: KMStickOutput, reverse: Bool) {
        self.dir = dir
        self.isReverse = reverse
    }
        
    let dir: KMStickOutput
    let isReverse: Bool
    
    func getInput(gc: GCExtendedGamepad) -> Float {
        switch (dir) {
        case .leftx: return gc.leftThumbstick.xAxis.value
        case .rightx: return gc.rightThumbstick.xAxis.value
        case .lefty: return gc.leftThumbstick.yAxis.value
        case .righty: return gc.rightThumbstick.yAxis.value
        case .l2: return gc.leftTrigger.value
        case .r2: return gc.rightTrigger.value
        }
    }
    
    func run(input: InputState) -> CGFloat {
        guard let gc = input.controller else { return 0.0 }
        
        let v = CGFloat(getInput(gc: gc))
        
        return isReverse ? -v : v
    }
    
    func describe() -> String {
        return "Controller \(dir)"
    }
}


enum MouseDir {
    case x, y
}

class MouseInput: GetFloatStep {
    init(dir: MouseDir, sensitivity: CGFloat) {
        self.dir = dir
        self.sensitivity = sensitivity
    }
    
    let dir: MouseDir
    let sensitivity: CGFloat
    
    var minOut: CGFloat = 0.0
    
    func getInput(input: InputState) -> CGFloat {
        switch (dir) {
        case .x: return input.mouse.mouseDeltaX
        case .y: return input.mouse.mouseDeltaY
        }
    }
    
    func run(input: InputState) -> CGFloat {
        var v = sensitivity * getInput(input: input) * input.deltaTime
        if v > 0 { v = max(minOut, v) }
        if v < 0 { v = min(-minOut, v) }        
        let f = max(-1.0, min(1.0, v))
        return f
    }
    
    func describe() -> String {
        return "Mouse \(dir) sensitivity:\(sensitivity) min:\(minOut)"
    }
}

class FloatInputStep: InputStep {
    init(inStep: GetFloatStep, outStep: FloatStep) {
        self.inStep = inStep
        self.outStep = outStep
    }
    
    let inStep: GetFloatStep
    let outStep: FloatStep
   
    override func run(input: InputState) {
        outStep.run(value: inStep.run(input: input), input: input)
    }
    
    override func describe() -> String {
        return "\(inStep.describe()) -> \(outStep.describe())"
    }
}

class KeyToStickInputStep: InputStep {
    
    init(fixAcceleration: CGFloat, minus: BinaryInputCheck?, plus: BinaryInputCheck, output: FloatStep) {
        self.fixAcceleration = fixAcceleration
        self.minus = minus
        self.plus = plus
        self.output = output
    }
    
    
    let fixAcceleration: CGFloat
    
    let minus: BinaryInputCheck?
    let plus: BinaryInputCheck
    var output: FloatStep
            
    var curAcceleration: CGFloat = 0
    var curVelocity: CGFloat = 0
    var curPos: CGFloat = 0
    
    override func run(input: InputState) {
        let isminus = minus?.IsToggled(input: input) ?? false
        let isplus = plus.IsToggled(input: input)
        let v = run(isMinus: isminus, isPlus: isplus, dt: input.deltaTime)
        output.run(value: v, input: input)
    }

    func run(isMinus: Bool, isPlus: Bool, dt: CGFloat) -> CGFloat {
        if isMinus && !isPlus {
            curAcceleration -= fixAcceleration * dt
        } else if isPlus && !isMinus {
            curAcceleration += fixAcceleration * dt
        } else {
            curAcceleration = 0
            curVelocity = 0
            curPos = 0
            return curPos
        }
        
        curVelocity += curAcceleration
        curPos += curVelocity
        curPos = min(1.0, max(-1.0, curPos))
        return curPos
    }
    
    override func describe() -> String {
        return "\(minus?.describe() ?? "") \(plus.describe()) -> \(output.describe())"
    }
}

func describeButton(_ button: chiaki_controller_button_t) -> String {
    switch (button) {
    case CHIAKI_CONTROLLER_BUTTON_CROSS: return "cross"
        
    case CHIAKI_CONTROLLER_BUTTON_BOX: return "square"
        
    case CHIAKI_CONTROLLER_BUTTON_PYRAMID: return "triangle"
        
    case CHIAKI_CONTROLLER_BUTTON_MOON: return "circle"
        
    case CHIAKI_CONTROLLER_BUTTON_R1: return "R1"

    case CHIAKI_CONTROLLER_BUTTON_L1: return "L1"

    case CHIAKI_CONTROLLER_BUTTON_R3: return "R3"

    case CHIAKI_CONTROLLER_BUTTON_L3: return "L3"

    case CHIAKI_CONTROLLER_BUTTON_PS: return "PS"

    case CHIAKI_CONTROLLER_BUTTON_TOUCHPAD: return "Touchpad"
        
    case CHIAKI_CONTROLLER_BUTTON_DPAD_UP: return "Dpad Up"
        
    case CHIAKI_CONTROLLER_BUTTON_DPAD_LEFT: return "Dpad Left"

    case CHIAKI_CONTROLLER_BUTTON_DPAD_RIGHT: return "Dpad Right"

    case CHIAKI_CONTROLLER_BUTTON_DPAD_DOWN: return "Dpad Down"
        
    case CHIAKI_CONTROLLER_BUTTON_OPTIONS: return "Options"

    case CHIAKI_CONTROLLER_BUTTON_SHARE: return "Share"
        
    default: return "\(button)"
    }
}

class ButtonInputStep: InputStep {
    internal init(check: BinaryInputCheck, button: chiaki_controller_button_t) {
        self.check = check
        self.button = button
    }
    
    let check: BinaryInputCheck
    let button: chiaki_controller_button_t
    
    override func run(input: InputState) {
        if check.IsToggled(input: input) {
            input.controllerState.buttons |= button.rawValue
        }
    }
    
    override func describe() -> String {
        return "\(check.describe()) -> \(describeButton(button))"
    }
}

class KeyboardManager {
    
    var lock = os_unfair_lock_s()
    private var keyDowns = Set<UInt16>()
    
//    func isKeyDown(key: UInt16) -> Bool {
//        return keyDowns.contains(key)
//    }
    
    
    func withLock(_ action: () -> (Void)) {
        os_unfair_lock_lock(&lock)
        action()
        os_unfair_lock_unlock(&lock)
    }
    
    func getKeyDowns() -> Set<UInt16> {
        var kd: Set<UInt16>? = nil
        withLock {
            kd = self.keyDowns
        }
        
        guard let kdd = kd else { return Set<UInt16>() }
        return kdd
    }
    
    func onKeyDown(evt: NSEvent) {
        withLock {
            keyDowns.insert(evt.keyCode)
        }
    }
    
    func onFlagsChanged(evt: NSEvent) {
        if evt.modifierFlags.contains(.shift) {
            withLock {
                keyDowns.insert(KeyCode.shift)
            }
        } else {
            withLock {
                keyDowns.remove(KeyCode.shift)
            }
        }
    }
    
    
    func onKeyUp(evt: NSEvent) {
        withLock {
            keyDowns.remove(evt.keyCode)
        }
    }

}
