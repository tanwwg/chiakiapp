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
    
    func run() -> ChiakiControllerState {
        controllerState = ChiakiControllerState()        
        for step in steps {
            step.run(input: self)
        }
        return controllerState
    }
}

class MouseManager {
    
    var mouseDelta = NSPoint()
    
    func onMouseMoved(evt: NSEvent) -> NSEvent {
        mouseDelta = NSPoint(x: evt.deltaX, y: evt.deltaY)
        return evt
    }

}

protocol BinaryInputCheck {
    func IsToggled(input: InputState) -> Bool
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
    
    func run(value: CGFloat, input: InputState) -> Void {
        
        switch (stick) {
        case .R2: input.controllerState.r2_state = UInt8(CGFloat(UInt8.max) * value)
        case .L2: input.controllerState.l2_state = UInt8(CGFloat(UInt8.max) * value)
        case .leftX: input.controllerState.left_x = Int16(CGFloat(Int16.max) * value)
        case .leftY: input.controllerState.left_y = Int16(CGFloat(Int16.max) * value)
        case .rightX: input.controllerState.right_x = Int16(CGFloat(Int16.max) * value)
        case .rightY: input.controllerState.right_y = Int16(CGFloat(Int16.max) * value)
        }
    }
}

protocol InputStep {
    func run(input: InputState);
}

class KeyboardInputCheck: BinaryInputCheck {
    init(key: UInt16) {
        self.key = key
    }
    
    let key: UInt16
    
    
    func IsToggled(input: InputState) -> Bool {
        return input.keyboard.isKeyDown(key: key)
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
        case .x: return input.mouse.mouseDelta.x
        case .y: return input.mouse.mouseDelta.y
        }
    }
    
    func run(input: InputState) -> CGFloat {
        return max(-1.0, min(1.0, sensitivity * getInput(input: input)))
    }
}

class FloatInputStep: InputStep {
    init(inStep: GetFloatStep, outStep: FloatStep) {
        self.inStep = inStep
        self.outStep = outStep
    }
    
    let inStep: GetFloatStep
    let outStep: FloatStep
   
    func run(input: InputState) {
        outStep.run(value: inStep.run(input: input), input: input)
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
    
    func run(input: InputState) {
        let isminus = minus?.IsToggled(input: input) ?? false
        let isplus = plus.IsToggled(input: input)
        let v = run(isMinus: isminus, isPlus: isplus)
        output.run(value: v, input: input)
    }

    func run(isMinus: Bool, isPlus: Bool) -> CGFloat {
        if isMinus && !isPlus {
            curAcceleration -= fixAcceleration
        } else if isPlus && !isMinus {
            curAcceleration += fixAcceleration
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
}

struct ButtonInputStep: InputStep {
    let check: BinaryInputCheck
    let button: chiaki_controller_button_t
    
    func run(input: InputState) {
        if check.IsToggled(input: input) {
            input.controllerState.buttons |= button.rawValue
        }
    }
}

class KeyboardManager {
    
    var keyDowns = Set<UInt16>()
    
    func isKeyDown(key: UInt16) -> Bool {
        return keyDowns.contains(key)
    }
    
    func onKeyDown(evt: NSEvent) -> NSEvent? {
        keyDowns.insert(evt.keyCode)
        
        return nil
    }
    
    func onKeyUp(evt: NSEvent) -> NSEvent? {
        keyDowns.remove(evt.keyCode)
        
        return nil
    }

}
