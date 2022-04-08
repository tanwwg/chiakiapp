import Foundation
import AVFoundation

class AudioBuffer {
    var buffer: AVAudioPCMBuffer
    var inUse: Bool = false
    
    init(_ buf: AVAudioPCMBuffer) {
        buffer = buf
    }
}

class AudioPlayer: NSObject {
    let _engine = AVAudioEngine()
    let _player = AVAudioPlayerNode()
    // note: 2 channels is fixed
    var _format: AVAudioFormat?
        
    var _buffers: [AudioBuffer] = []
    
    static let BUFFER_FRAMES = 810

    override init() {
        super.init()
                
        // https://developer.apple.com/documentation/foundation/nsnotification/name/1389078-avaudioengineconfigurationchange
        NotificationCenter.default.addObserver(self, selector: #selector(self.engineChanged(notification:)), name: NSNotification.Name.AVAudioEngineConfigurationChange, object: nil);
    }
    
    @objc func engineChanged(notification: NSNotification) {
        print("audio engine changed")
        self.startEngine()
    }
    
    func startup(sampleRate: Double) {
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 2, interleaved: false)!
        
        _buffers = []
        for _ in 1...3 {
            // 48khz / 60fps = 800 frames, but decklink sometimes sends 801
            let b = AudioBuffer(AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(AudioPlayer.BUFFER_FRAMES))!)
            _buffers.append(b)
        }
        
        self._format = fmt

        startEngine()
    }
    
    func startEngine() {
        guard let fmt = _format else { return }
        
        _engine.attach(_player)
        _engine.connect(_player, to: _engine.mainMixerNode, format: fmt)
        _engine.prepare()
        
        try! _engine.start()
        _player.play()
    }
    
    func lockBuffer(frames: Int) -> AudioBuffer? {
        if let b = _buffers.first(where: { b in !b.inUse && b.buffer.frameCapacity >= frames}) {
            b.inUse = true
            return b
        } else {
            return nil
        }
    }

    func play(data: Data) {
        // called outside main thread
        if data.count == 0 { return }
        if _format == nil { return }
        
        let frames = min(data.count / 4, AudioPlayer.BUFFER_FRAMES)
        
        guard let audiobuf = lockBuffer(frames: frames) else { return }
        let buffer = audiobuf.buffer
        buffer.frameLength = AVAudioFrameCount(frames)
        let p1: UnsafeMutablePointer<Float> = buffer.floatChannelData![0]
        let p2: UnsafeMutablePointer<Float> = buffer.floatChannelData![1]

        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            let v: UnsafeBufferPointer<simd_short2> = ptr.bindMemory(to: simd_short2.self)
            for i in 0...frames-1 {
                p1[i] = Float(v[i].x) / 32767.0
                p2[i] = Float(v[i].y) / 32767.0
            }
        }
        _player.scheduleBuffer(buffer) {
            audiobuf.inUse = false
        }

    }
}
