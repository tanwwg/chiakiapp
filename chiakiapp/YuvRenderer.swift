import Foundation
import simd
import Metal
import MetalKit

class BufferManager {
    let _device: MTLDevice
    let _texQueue = DispatchQueue(label: "buffer", qos: .userInteractive)
    var _writeTextures: [MTLTexture] = []
    var _width: Int = 0
    var _height: Int = 0
    
    init(device: MTLDevice) {
        self._device = device
    }

    func makeTexture(width: Int, height: Int) -> MTLTexture {
        let texDesc = MTLTextureDescriptor()
        texDesc.storageMode = .managed
//        texDesc.pixelFormat = MTLPixelFormat.bgrg422
        texDesc.pixelFormat = MTLPixelFormat.r8Uint
        texDesc.width = width
        texDesc.height = height
        return _device.makeTexture(descriptor: texDesc)!
    }
    
    /**
     Not main-thread safe, as it'll block on dispatch queue
     */
    func getBuffer(width: Int, height: Int) -> MTLTexture? {
        var ret: MTLTexture?
        _texQueue.sync {
            if width != _width || height != _height {
                // rebuild textures
                _width = width
                _height = height
                _writeTextures = (1...6).map { _ in makeTexture(width: width, height: height)}
            }
            
            if _writeTextures.count > 0 {
                ret = _writeTextures.removeLast()
            } else {
                ret = nil
            }
        }
        return ret
    }

    func returnBuffer(_ tex: MTLTexture) {
        _texQueue.async {
            self._writeTextures.append(tex)
        }
    }
}

class YuvRenderer: NSObject, MTKViewDelegate {
    
    let _device: MTLDevice
    var _viewportSize: vector_float2 = vector_float2(0, 0)

    var _vertexBuffer: MTLBuffer!
    var _pipelineState: MTLRenderPipelineState!
    var _commandQueue: MTLCommandQueue!
    
    var _textures: BufferManager
    
    var _brightness: Int = 0
    var _renderParams: MTLBuffer!
    
    var noframe: Int = 0
    var lateframe: Int = 0
    
    let shader = "grayShader"
//    static let pixelFormat = MTLPixelFormat.bgrg422

//    let shader = "rgbShader"
//    static let pixelFormat = MTLPixelFormat.bgra8Unorm
    init(mtkView: MTKView) {
        _device = mtkView.device!
                
        let lib = _device.makeDefaultLibrary()!
        
        let pipeline = MTLRenderPipelineDescriptor()
        pipeline.label = "Texturing Pipeline"
        pipeline.vertexFunction = lib.makeFunction(name: "vertexShader")
        pipeline.fragmentFunction = lib.makeFunction(name: shader)
        pipeline.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        
        _pipelineState = try! _device.makeRenderPipelineState(descriptor: pipeline)
        _commandQueue = _device.makeCommandQueue()
            
        _textures = BufferManager(device: _device)
        
        _renderParams = YuvRenderer.makeRenderParams(device: _device, brightness: 0.0)

        let size = mtkView.drawableSize
        _viewportSize = vector_float2(Float(size.width), Float(size.height))
        _vertexBuffer = YuvRenderer.makeVertices(device: _device, w: _viewportSize.x, h: _viewportSize.y)

        super.init()
    }
    
    static func makeRenderParams(device: MTLDevice, brightness: Float) -> MTLBuffer {
        let length = MemoryLayout<FragmentParms>.stride
        let buf = device.makeBuffer(length: length, options: .storageModeManaged)!
        var p: FragmentParms = FragmentParms(brightness: brightness)
        buf.contents().copyMemory(from: &p, byteCount: length)
        return buf
    }
    
    
    
    var brightness: Int {
        get {
            return self._brightness
        }
        set {
            _brightness = newValue
            _renderParams = YuvRenderer.makeRenderParams(device: _device, brightness: Float(_brightness) / 10.0)
        }
    }
        
    /**
     Thread-safe call to load data into the next write texture
     */
    func loadTexture(data: Data, rowBytes: Int, width: Int, height: Int) {
        if let tex = _textures.getBuffer(width: width, height: height) {
            data.withUnsafeBytes { ptr in
                tex.replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: width, height: height, depth: 1)), mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: rowBytes)
            }
            DispatchQueue.main.async {
                self.showTexture(tex)
            }
        }
    }
    
    func loadYuv420Texture(data: [Data], width: Int, height: Int) {
        guard let tex = _textures.getBuffer(width: width, height: height) else { return }
        
        data[0].withUnsafeBytes { ptr in
            tex.replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: width, height: height, depth: 1)), mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: width)
        }
        
//        var temp = Data(count: width * height)
//        temp.withUnsafeMutableBytes { bytes in
//            data[0].withUnsafeBytes { p in
//                for x in 0...width-1 {
//                    for y in 0...height-1 {
//                        bytes[y*width+x] = p[y*width+x]
//                    }
//                }
//            }
//        }
//
//        temp.withUnsafeBytes { ptr in
//            tex.replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: width, height: height, depth: 1)), mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: width)
//        }
        DispatchQueue.main.async {
            self.showTexture(tex)
        }
    }
    
    static func makeVertices(device: MTLDevice, w: Float, h: Float) -> MTLBuffer {
        let targetAspect: Float = 16.0 / 9.0
        let aspect = w / h
        
        var w2: Float, h2: Float
        if aspect > targetAspect {
            // pillar box
            h2 = h/2
            w2 = h2 * targetAspect
        } else {
            // letter box
            w2 = w/2
            h2 = w2 / targetAspect
        }
        
        
        let vertices: [MetalVertex] = [
            MetalVertex(position: [w2, -h2], textureCoordinate: [1, 1]),
            MetalVertex(position: [-w2, -h2], textureCoordinate: [0, 1]),
            MetalVertex(position: [-w2, h2], textureCoordinate: [0, 0]),
            MetalVertex(position: [w2, -h2], textureCoordinate: [1, 1]),
            MetalVertex(position: [-w2, h2], textureCoordinate: [0, 0]),
            MetalVertex(position: [w2, h2], textureCoordinate: [1, 0]),
        ]
        
        let buf = device.makeBuffer(length: MemoryLayout<MetalVertex>.stride * 6, options: .storageModeManaged)!
        
        vertices.withUnsafeBytes { ptr in
            buf.contents().copyMemory(from: ptr.baseAddress!, byteCount: ptr.count)
        }
        
        return buf
    }
    
    func setupViewport(w: Float, h: Float) {
        _viewportSize = vector_float2(w, h)
        _vertexBuffer = YuvRenderer.makeVertices(device: _device, w: w, h: h)
    }
        
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        setupViewport(w: Float(size.width), h: Float(size.height))
    }
    
    var _showTexture: [MTLTexture] = []
    
    func resetStats() {
        noframe = 0
        lateframe = 0
    }

    func showTexture(_ tex: MTLTexture) {
        if _showTexture.count < 3 {
            _showTexture.append(tex)
        } else {
            lateframe += 1
            // return buffers
            for t in _showTexture {
                _textures.returnBuffer(t)
            }
            _showTexture = [tex]
        }
    }
        
    func render(view: MTKView) {
        guard _showTexture.count > 0 else {
            noframe += 1
            return
        }
        let tex = _showTexture[0]
        
        guard let drawable = view.currentDrawable,
              let renderDesc = view.currentRenderPassDescriptor
              else { return }

        guard let cmdBuf = _commandQueue.makeCommandBuffer(),
              let renderEnc = cmdBuf.makeRenderCommandEncoder(descriptor: renderDesc)
              else { return }
        
        _showTexture.removeFirst()
        
        renderEnc.setViewport(MTLViewport(originX: 0, originY: 0,
                                          width: Double(_viewportSize.x), height: Double(_viewportSize.y),
                                          znear: -1.0, zfar: 1.0))
        renderEnc.setRenderPipelineState(_pipelineState)
        renderEnc.setVertexBuffer(_vertexBuffer, offset: 0, index: 0)
        renderEnc.setVertexBytes(&_viewportSize, length: MemoryLayout<vector_float2>.stride, index: 1)
        renderEnc.setFragmentTexture(tex, index: 0)
        renderEnc.setFragmentBuffer(_renderParams, offset: 0, index: 1)
        renderEnc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEnc.endEncoding()

        cmdBuf.addCompletedHandler {_ in
            self._textures.returnBuffer(tex)
        }

        cmdBuf.present(drawable)
        cmdBuf.commit()
        
    }

    
    func draw(in view: MTKView) {
        autoreleasepool {
            self.render(view: view)
        }
    }
}

