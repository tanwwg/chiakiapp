//
//  KeyMapFile.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 13/4/22.
//

import Foundation

enum KMMouseDir: String, Codable {
    case x, y
}

enum KMButtonInput: Codable {
    case key(code: String)
    case mouse(button: MouseButton)
    case controller(button: KMButtonOutput)
}

enum KMButtonOutput: String, Codable {
    case cross, square, triangle, circle, r1, l1, r3, l3, ps, touchpad, dpad_left, dpad_up, dpad_right, dpad_down, option, share
}

enum KMStickOutput: String, Codable {
    case leftx, lefty, rightx, righty, l2, r2
}


enum KMStickInput: Codable {
    case mouse(sensitivity: CGFloat, dir: KMMouseDir, min: CGFloat?)
    case controller(dir: KMStickOutput, reverse: Bool?)
}

enum KMStep: Codable {
    case button(input: KMButtonInput, output: KMButtonOutput)
    case keyToStick(sensitivity: CGFloat, minus: KMButtonInput?, plus: KMButtonInput, output: KMStickOutput)
    case stick(input: KMStickInput, output: KMStickOutput)
}

enum KMError: Error {
    case InvalidKeyCode
    case InvalidString
}

func generateBinaryInputCheck(input: KMButtonInput) throws -> BinaryInputCheck {
    switch (input) {
        
    case .key(code: let key):
        if let u16 = KeyCodeMap.standard.map[key] {
            return KeyboardInputCheck(desc: key, key: u16)
        } else {
            print("Unable to map keycode \(key)")
            throw KMError.InvalidKeyCode
        }
        
    case .mouse(button: let button):
        return MouseInputCheck(button: button)
        
    case .controller(button: let button):
        return GameControllerInputCheck(button: button)
    }
}

func generateBinaryInputCheckOptional(input: KMButtonInput?) throws -> BinaryInputCheck? {
    guard let inp = input else { return nil }
    return try generateBinaryInputCheck(input: inp)
}


func toChiakiButton(output: KMButtonOutput) -> chiaki_controller_button_t {
    switch(output) {
        
    case .cross:
        return CHIAKI_CONTROLLER_BUTTON_CROSS
        
    case .square:
        return CHIAKI_CONTROLLER_BUTTON_BOX
        
    case .triangle:
        return CHIAKI_CONTROLLER_BUTTON_PYRAMID
        
    case .circle:
        return CHIAKI_CONTROLLER_BUTTON_MOON
        
    case .r1:
        return CHIAKI_CONTROLLER_BUTTON_R1

    case .l1:
        return CHIAKI_CONTROLLER_BUTTON_L1

    case .r3:
        return CHIAKI_CONTROLLER_BUTTON_R3

    case .l3:
        return CHIAKI_CONTROLLER_BUTTON_L3

    case .ps:
        return CHIAKI_CONTROLLER_BUTTON_PS

    case .touchpad:
        return CHIAKI_CONTROLLER_BUTTON_TOUCHPAD
        
    case .dpad_up:
        return CHIAKI_CONTROLLER_BUTTON_DPAD_UP
        
    case .dpad_left:
        return CHIAKI_CONTROLLER_BUTTON_DPAD_LEFT

    case .dpad_right:
        return CHIAKI_CONTROLLER_BUTTON_DPAD_RIGHT

    case .dpad_down:
        return CHIAKI_CONTROLLER_BUTTON_DPAD_DOWN
        
    case .option:
        return CHIAKI_CONTROLLER_BUTTON_OPTIONS

    case .share:
        return CHIAKI_CONTROLLER_BUTTON_SHARE

    }
}

func toFloatStep(output: KMStickOutput) -> FloatStep {
    switch (output) {
        
    case .leftx:
        return FloatToStickStep(stick: .leftX)
    case .lefty:
        return FloatToStickStep(stick: .leftY)
    case .rightx:
        return FloatToStickStep(stick: .rightX)
    case .righty:
        return FloatToStickStep(stick: .rightY)
    case .l2:
        return FloatToStickStep(stick: .L2)
    case .r2:
        return FloatToStickStep(stick: .R2)
    }
}

func toFloatInputStep(input: KMStickInput) -> GetFloatStep {
    switch (input) {
        
    case .mouse(sensitivity: let sensitivity, dir: let dir, let min):
        let m = MouseInput(dir: dir == .x ? MouseDir.x : MouseDir.y, sensitivity: sensitivity)
        if let minn = min {
            m.minOut = minn
        }
        return m
    case .controller(dir: let dir, reverse: let reverse):
        return GameControllerFloatInput(dir: dir, reverse: reverse ?? false)
    }
}

func generateInputStep(step: KMStep) throws -> InputStep {
    switch (step) {
    case .button(input: let input, output: let output):
        return ButtonInputStep(check: try generateBinaryInputCheck(input: input), button: toChiakiButton(output: output))
        
        
    case .stick(input: let input, output: let output):
        return FloatInputStep(inStep: toFloatInputStep(input: input), outStep: toFloatStep(output: output))
        
    case .keyToStick(sensitivity: let sensitivity, minus: let minus, plus: let plus, output: let output):
        return KeyToStickInputStep(
            fixAcceleration: sensitivity,
            minus: try generateBinaryInputCheckOptional(input: minus),
            plus: try generateBinaryInputCheck(input: plus),
            output: toFloatStep(output: output))
    }
}

func generateInputSteps(steps: [KMStep]) throws -> [InputStep] {
    return try steps.map { try generateInputStep(step:$0) }
}

func loadKeymapFile(file: URL) throws -> [InputStep] {
    let jd = try Data(contentsOf: file)
    return try loadKeymapFile(data: jd)
}

func loadKeymapFile(data: Data) throws -> [InputStep] {
    let inp = try JSONDecoder().decode([KMStep].self, from: data)     
    let steps = try generateInputSteps(steps: inp)
    return steps
}

func loadKeymapFile(string: String) throws -> [InputStep] {
    guard let d = string.data(using: .utf8) else {
        throw KMError.InvalidString
    }
    return try loadKeymapFile(data: d)
}
