//
//  StreamView.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 1/10/23.
//

import SwiftUI
import AVFoundation

class InputTimer {
    var lastTimerRun: UInt64?
    
    var timerQueue = DispatchQueue(label: "timer")
    var timer: DispatchSourceTimer
    
    var callback: ((Double) -> ())?
    
    init() {
        self.timer = DispatchSource.makeTimerSource(flags: [.strict], queue: timerQueue)
        self.timer.schedule(deadline: .now(), repeating: .milliseconds(8), leeway: .milliseconds(4))
        self.timer.setEventHandler(handler: timerCb)
        self.timer.activate()
    }
    
    func cancel() {
        timer.cancel()
    }
    
    deinit {
        timer.cancel()
    }
        
    var statsTimeStart: UInt64 = 0
    var statsCounter = 0

    func timerCb() {
        let now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        guard let last = lastTimerRun else {
            lastTimerRun = now
            return
        }
        
        /// print timer cb stats
//        if statsCounter == 0 {
//            statsTimeStart = now
//        }
//        statsCounter += 1
//        if statsCounter == 100 {
//            statsCounter = 0
//            let deltaMs: Int = Int((now - statsTimeStart) / 100_000_000)
//            self.statusText.stringValue = "\(deltaMs)"
//
//        }

        
        let delta = Double(now - last) / Double(1_000_000_000)
        
        
        callback?(delta)
//        session?.setControllerState(inputState.run(delta))
        
        lastTimerRun = now
    }
}

class EventsManager {
    var events: [Any] = []
    
    func monitor(matching: NSEvent.EventTypeMask, handler block: @escaping (NSEvent) -> NSEvent?) {
        if let o = NSEvent.addLocalMonitorForEvents(matching: matching, handler: block) {
            events.append(o)
        }
    }
    
    deinit {
        for e in events {
            NSEvent.removeMonitor(e)
        }
    }
}

@Observable class StreamController {
    
    var audioPlayer = AudioQueuePlayer()
    
    var inputState: InputState
        
    var session: ChiakiSessionBridge
    
    let videoController = VideoController()
    
    let timer: InputTimer
    
    let powerManager = PowerManager()
    
    var isKeyboardOpen = false
    
    var isWaitingToStart = true
    
    init(app: AppUiModel, session: ChiakiSessionBridge) {
        self.session = session
        
        self.timer = InputTimer()
        
        self.inputState = InputState()
        self.inputState.steps = app.keymap
        
        withObservationTracking({ _ = app.keymap }) { [weak self] in
            print("keymap changed!")
            self?.inputState.steps = app.keymap
        }
        
        timer.callback = { [weak self] delta in
            guard let ss = self else { return }
            ss.session.setControllerState(ss.inputState.run(delta))
        }
        
        session.rawVideoCallback = { [weak self] (buf, bufsize) in
            self?.videoController.handleVideoFrame(buf, size: bufsize)
        }
        session.audioSettingsCallback = { [weak self] (ch, sr) in
            self?.audioPlayer.startup(channels: Int(ch), sampleRate: Double(sr))
        }
        session.audioFrameCallback = { [weak self] (buf, count) in
            let data = Data(bytesNoCopy: buf, count: count * 4, deallocator: .none)
            self?.audioPlayer.play(data: data)
        }
        session.onKeyboardOpen = { [weak self] in
            print("ON KEYBOARD OPEN")
            guard let ss = self else { return }
            ss.isKeyboardOpen = true
        }
        
        session.isLoggingEnabled = false
        print("Session started")
        session.start()
        powerManager.disableSleep(reason: "Chiaki streaming")
    }
    
    func sendKeys(_ s: String) {
        session.setKeyboardText(s)
    }
    
    func closeKeyboard() {
        session.acceptKeyboard()
        isKeyboardOpen = false
    }
    
    deinit {
        print("Stopping session")
        timer.cancel()
        session.stop()
        powerManager.enableSleep()
    }
}

class AppKitStreamView: NSView {
    
    var displayLayer: AVSampleBufferDisplayLayer?
    
    weak var stream: StreamController?
    var keyboard: KeyboardManager?
    var mouse: MouseManager?
    
    var isReceived = false
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        self.wantsLayer = true
        let disp = AVSampleBufferDisplayLayer()
        disp.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        disp.backgroundColor = CGColor.black
        self.layer!.addSublayer(disp)
        
        displayLayer = disp
                
        let track = NSTrackingArea(rect: .zero, options: [.activeWhenFirstResponder, .mouseMoved, .enabledDuringMouseDrag, .mouseEnteredAndExited, .inVisibleRect] ,owner: self)
        self.addTrackingArea(track)
    }
    
    func setup(controller: StreamController) {
        self.stream = controller
        self.keyboard = controller.inputState.keyboard
        self.mouse = controller.inputState.mouse
        
        controller.videoController.onBuffer = { [weak self] buf in
            guard let ss = self else { return }
            ss.displayLayer?.sampleBufferRenderer.enqueue(buf)
            if !ss.isReceived {
                ss.isReceived = true
                DispatchQueue.main.async {
                    ss.stream?.isWaitingToStart = false
                }
            }
        }
    }
    
    override func keyDown(with event: NSEvent) {
//        print("keydown=\(event.keyCode)")
        if event.modifierFlags.contains(.command) { return }
        keyboard?.onKeyDown(evt: event)
    }
    
    override func keyUp(with event: NSEvent) {
        keyboard?.onKeyUp(evt: event)
    }
    
    override func flagsChanged(with event: NSEvent) {
        keyboard?.onFlagsChanged(evt: event)
    }
    
    // ========== mouse tracking =================================
    
    override func mouseEntered(with event: NSEvent) {
        NSCursor.hide()
//        CGAssociateMouseAndMouseCursorPosition(0)
    }
    
    override func mouseExited(with event: NSEvent) {
        NSCursor.unhide()
//        CGAssociateMouseAndMouseCursorPosition(1)
    }
    
    override func mouseMoved(with event: NSEvent) {
        mouse?.onMouseMoved(evt: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        mouse?.onMouseMoved(evt: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        mouse?.onMouseEvent(button: .left, isDown: true)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        mouse?.onMouseEvent(button: .right, isDown: true)
    }
    
    override func mouseUp(with event: NSEvent) {
        mouse?.onMouseEvent(button: .left, isDown: false)
    }

    override func rightMouseUp(with event: NSEvent) {
        mouse?.onMouseEvent(button: .right, isDown: false)
    }

    // ========= needs to become first responder to handle keyboard events =============
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    override func viewDidMoveToSuperview() {
        print("viewDidMoveToSuperview \(self.superview)")
        DispatchQueue.main.async {
            self.window?.makeFirstResponder(self)
        }
    }

}

struct NsStreamView: NSViewRepresentable {
    
    var streamController: StreamController
    
    func makeNSView(context: Context) -> AppKitStreamView {
        let view = AppKitStreamView(frame: NSRect.zero)
        return view
    }
    
    func updateNSView(_ nsView: AppKitStreamView, context: Context) {
        nsView.setup(controller: streamController)
//        nsView.keyboard = streamController.inputState.keyboard
//        streamController.videoController.display = nsView.displayLayer
    }
}

struct StreamKeyboardView: View {
    
    @Bindable var stream: StreamController
    
    @State var text = ""
    
    var body: some View {
        Form {
            TextField("Keyboard", text: $text)
            Button(action: { stream.closeKeyboard() }) {
                Text("OK")
            }
            .keyboardShortcut(.defaultAction)
        }
        .onChange(of: text, initial: false) {
            stream.sendKeys(text)
        }
        .padding()
    }
}

struct StreamView: View {
    
    @Environment(AppUiModel.self) var app
    @Bindable var stream: StreamController
        
    var body: some View {
        NsStreamView(streamController: stream)
            .sheet(isPresented: $stream.isWaitingToStart) {
                VStack {
                    Spacer()
                    ProgressView()
                    Text("Connecting, Cmd+D to disconnect")
                    Spacer()
                }
                .frame(width: 400, height: 300)
            }
            .sheet(isPresented: $stream.isKeyboardOpen) {
                StreamKeyboardView(stream: stream)
                    .frame(width: 400, height: 300)
            }
            .onAppear {
                DispatchQueue.main.async {
                    if let window = NSApp.mainWindow, !window.styleMask.contains(.fullScreen) {
                        window.toggleFullScreen(self)
                    }
                }
            }
    }
}
