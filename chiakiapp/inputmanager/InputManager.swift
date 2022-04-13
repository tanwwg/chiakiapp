//
//  InputManager.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 31/3/22.
//

import Foundation
import AppKit




class InputState {
    var keyboard = KeyboardManager()
    var mouse = MouseManager()
    
    var controllerState = ChiakiControllerState()
    var steps: [InputStep] = []
    
    var deltaTime: CGFloat = 0.0
    
    func run(_ inDeltaTime: CGFloat) -> ChiakiControllerState {
        controllerState = ChiakiControllerState()
        self.deltaTime = inDeltaTime
        for step in steps {
            step.run(input: self)
        }

        // after reading mouse deltas, clear them
        // otherwise, if theres no more mouse move, it'll continue to return the last entry
        self.mouse.clear()

        return controllerState
    }
}

class MouseManager {
    
    var mouseDeltaX: CGFloat = 0.0
    var mouseDeltaY: CGFloat = 0.0

    var isLeftDown = false
    var isRightDown = false
    
    func onMouseMoved(evt: NSEvent) -> NSEvent {
        mouseDeltaX = evt.deltaX
        mouseDeltaY = evt.deltaY

        return evt
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
}

protocol GetFloatStep {
    func run(input: InputState) -> CGFloat
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

class KeyboardInputCheck: BinaryInputCheck {
    init(desc: String, key: UInt16) {
        self.desc = desc
        self.key = key
    }
    
    let key: UInt16
    let desc: String
    
    func IsToggled(input: InputState) -> Bool {
        return input.keyboard.isKeyDown(key: key)
    }
    
    func describe() -> String {
        return desc
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
    
    func getInput(input: InputState) -> CGFloat {
        switch (dir) {
        case .x: return input.mouse.mouseDeltaX
        case .y: return input.mouse.mouseDeltaY
        }
    }
    
    func run(input: InputState) -> CGFloat {
        let f = max(-1.0, min(1.0, sensitivity * getInput(input: input) * input.deltaTime))
        return f
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
        return "\(inStep) -> \(outStep)"
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
        return "\(minus?.describe() ?? "") \(plus.describe()) -> \(output)"
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
        return "Button \(check.describe()) -> \(button)"
    }
}

class KeyboardManager {
    
    var keyDowns = Set<UInt16>()
    
    func isKeyDown(key: UInt16) -> Bool {
        return keyDowns.contains(key)
    }
    
    func onKeyDown(evt: NSEvent) -> NSEvent? {
        keyDowns.insert(evt.keyCode)
        
        return evt
    }
    
    func onFlagsChanged(evt: NSEvent) -> NSEvent? {
        if evt.modifierFlags.contains(.shift) {
            keyDowns.insert(KeyCode.shift)
        } else {
            keyDowns.remove(KeyCode.shift)
        }
        
        return evt
    }
    
    
    func onKeyUp(evt: NSEvent) -> NSEvent? {
        keyDowns.remove(evt.keyCode)
        
        return evt
    }

}
