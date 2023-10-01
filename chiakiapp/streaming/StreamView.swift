//
//  StreamView.swift
//  chiakiapp
//
//  Created by Tan Thor Jen on 1/10/23.
//

import SwiftUI
import AVFoundation

@Observable class StreamController {
    
    var audioPlayer = AudioQueuePlayer()
    
    var inputState = InputState()
        
    var session: ChiakiSessionBridge!
    
    let videoController = VideoController()
    
    func setup(session: ChiakiSessionBridge) {
        self.session = session
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
//        disp.bounds = self.view.bounds
        disp.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        disp.backgroundColor = CGColor.black
//        disp.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        self.layer!.addSublayer(disp)
        
        displayLayer = disp
//        self.display = disp
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
    @State var controller = StreamController()
    
    var body: some View {
        AVSampleBufferView(videoController: controller.videoController)
            .onAppear {
                controller.setup(session: app.session!)
            }
    }
}
