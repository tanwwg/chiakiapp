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
    
    init(steps: [InputStep], session: ChiakiSessionBridge) {
        self.session = session
        
        self.timer = InputTimer()
        
        self.inputState = InputState()
        
        timer.callback = { [weak self] delta in
            guard let ss = self else { return }
            ss.session.setControllerState(ss.inputState.run(delta))
        }
        
        session.rawVideoCallback = self.videoController.handleVideoFrame(_:size:)
        session.audioSettingsCallback = { (ch, sr) in
            self.audioPlayer.startup(channels: Int(ch), sampleRate: Double(sr))
        }
        session.audioFrameCallback = { (buf, count) in
            let data = Data(bytesNoCopy: buf, count: count * 4, deallocator: .none)
            self.audioPlayer.play(data: data)
        }
//        session.onKeyboardOpen = { DispatchQueue.main.async { self.setKeyboardInput(true) } }
        
        session.isLoggingEnabled = false
        print("Session started")
        session.start()
        powerManager.disableSleep(reason: "Chiaki streaming")
    }
    
    deinit {
        print("Stopping session")
        session.stop()
        powerManager.enableSleep()
    }
}

class NSAVSampleBufferView: NSView {
    
    var displayLayer: AVSampleBufferDisplayLayer!
    
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
    }
}

struct AVSampleBufferView: NSViewRepresentable {
    
    var videoController: VideoController
    
    func makeNSView(context: Context) -> NSAVSampleBufferView {
        let view = NSAVSampleBufferView(frame: NSRect.zero)
        return view
    }
    
    func updateNSView(_ nsView: NSAVSampleBufferView, context: Context) {
        videoController.display = nsView.displayLayer
    }
    
}

struct StreamView: View {
    
    @EnvironmentObject var app: AppUiModel
    
    @State var stream: SetupValue<StreamController> = .uninitialized
    
    func setup() {
        if let session = app.session, case .uninitialized = stream {
            stream = .value(StreamController(steps: app.keymap, session: session))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = NSApplication.shared.windows.last {
                    window.toggleFullScreen(nil)
                }
            }
        }
    }
    
    var body: some View {
        Group {
            switch(stream) {
            case .value(let c):
                AVSampleBufferView(videoController: c.videoController)
            default:
                EmptyView()
            }
        }
        .onAppear {
            setup()
        }
        .onDisappear {
            stream = .uninitialized
        }
    }
}
