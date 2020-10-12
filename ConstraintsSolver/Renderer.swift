import Metal
import MetalKit
import simd

private let x = simd_float3(1, 0, 0)
private let y = simd_float3(0, 1, 0)
private let z = simd_float3(0, 0, 1)

struct Color {
    let rgb: SIMD3<Float>
    
    init(_ red: Float, _ green: Float, _ blue: Float) {
        rgb = .init(red, green, blue)
    }
    
    init(_ grey: Float) {
        rgb = .init(repeating: grey)
    }
    
    static let red = Color(1, 0, 0)
    static let green = Color(0, 1, 0)
    static let blue = Color(0, 0, 1)
    static let yellow = Color(1, 1, 0)
    static let cyan = Color(0, 1, 1)
    static let magenta = Color(1, 0, 1)
    static let white = Color(1)
    static let black = Color(0)
}

class Geometry {
    let name: String
    let vertices: UnsafeMutableBufferPointer<Vertex>
        
    var translation: simd_float3 = .zero
    var rotation: simd_float3 = .zero

    init(name: String, vertices: UnsafeMutableBufferPointer<Vertex>) {
        self.name = name
        self.vertices = vertices
    }
    
    subscript(index: Int) -> Vertex {
        get {
            vertices[index]
        }
        set {
            vertices[index] = newValue
        }
    }
    
    func transform() -> simd_float3x3 {
        let rotationX = simd_float3x3(columns: (
            simd_float3(1, 0, 0),
            simd_float3(0, cosf(rotation.x), -sinf(rotation.x)),
            simd_float3(0, sinf(rotation.x), cosf(rotation.x))
        ))
        
        let rotationY = simd_float3x3(columns: (
            simd_float3(cosf(rotation.y), 0, sinf(rotation.y)),
            simd_float3(0, 1, 0),
            simd_float3(-sinf(rotation.y), 0, cosf(rotation.y))
        ))
        
//        let rotationZ = simd_float3x3(columns: (
//            simd_float3(cosf(rotation.z), -sinf(rotation.z), 0),
//            simd_float3(sinf(rotation.z), cosf(rotation.z), 0),
//            simd_float3(0, 0, 1)
//        ))
        
        return rotationX * rotationY
    }
}

class Renderer: NSObject, MTKViewDelegate {
    
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState
    
    var uniformBuffer: MTLBuffer
    var uniforms: UnsafeMutablePointer<Uniforms>
    var aspectRatio: Float = 1
    
    var geometries: [Geometry] = []
    
    var vertexBuffer: MTLBuffer
    var vertices: UnsafeMutablePointer<Vertex>
    
    var currentVertexCount = 0
    static let maximalVertexCount = 1024
    
    func makeGeometry(name: String, vertexCount: Int) -> Geometry {
        if currentVertexCount + vertexCount >= Renderer.maximalVertexCount {
            fatalError("Vertex buffer is out of memory")
        }
        
        let pointer = UnsafeMutableBufferPointer(start: vertices.advanced(by: currentVertexCount), count: vertexCount)
        currentVertexCount += vertexCount

        let geometry = Geometry(name: name, vertices: pointer)
        geometries.append(geometry)
        return geometry
    }
    
    func makeTriangle(name: String, colors: (Color, Color, Color)) -> Geometry {
        let geometry = makeGeometry(name: name, vertexCount: 3)
        geometry[0] = .init(position: .init(-1, -1, 0), normal: .init(0, 0, -1), color: colors.0.rgb)
        geometry[1] = .init(position: .init(1, -1, 0), normal: .init(0, 0, -1), color: colors.1.rgb)
        geometry[2] = .init(position: .init(0, 1, 0), normal: .init(0, 0, -1), color: colors.2.rgb)
        return geometry
    }
    
    func makeCube(name: String, color: Color) -> Geometry {
        let geometry = makeGeometry(name: name, vertexCount: 36)
        
        geometry[0] = .init(position: .zero, normal: -z, color: color.rgb)
        geometry[1] = .init(position: x, normal: -z, color: color.rgb)
        geometry[2] = .init(position: x + y, normal: -z, color: color.rgb)
        geometry[3] = .init(position: .zero, normal: -z, color: color.rgb)
        geometry[4] = .init(position: x + y, normal: -z, color: color.rgb)
        geometry[5] = .init(position: y, normal: -z, color: color.rgb)
        
        geometry[6] = .init(position: x, normal: x, color: color.rgb)
        geometry[7] = .init(position: x + z, normal: x, color: color.rgb)
        geometry[8] = .init(position: x + y + z, normal: x, color: color.rgb)
        geometry[9] = .init(position: x, normal: x, color: color.rgb)
        geometry[10] = .init(position: x + y + z, normal: x, color: color.rgb)
        geometry[11] = .init(position: x + y, normal: x, color: color.rgb)
        
        geometry[12] = .init(position: y, normal: y, color: color.rgb)
        geometry[13] = .init(position: x + y, normal: y, color: color.rgb)
        geometry[14] = .init(position: x + y + z, normal: y, color: color.rgb)
        geometry[15] = .init(position: y, normal: y, color: color.rgb)
        geometry[16] = .init(position: x + y + z, normal: y, color: color.rgb)
        geometry[17] = .init(position: y + z, normal: y, color: color.rgb)
        
        geometry[18] = .init(position: z, normal: z, color: color.rgb)
        geometry[19] = .init(position: x + y + z, normal: z, color: color.rgb)
        geometry[20] = .init(position: x + z, normal: z, color: color.rgb)
        geometry[21] = .init(position: z, normal: z, color: color.rgb)
        geometry[22] = .init(position: y + z, normal: z, color: color.rgb)
        geometry[23] = .init(position: x + y + z, normal: z, color: color.rgb)
        
        geometry[24] = .init(position: .zero, normal: -x, color: color.rgb)
        geometry[25] = .init(position: y + z, normal: -x, color: color.rgb)
        geometry[26] = .init(position: z, normal: -x, color: color.rgb)
        geometry[27] = .init(position: .zero, normal: -x, color: color.rgb)
        geometry[28] = .init(position: y, normal: -x, color: color.rgb)
        geometry[29] = .init(position: y + z, normal: -x, color: color.rgb)
        
        geometry[30] = .init(position: .zero, normal: -y, color: color.rgb)
        geometry[31] = .init(position: x + z, normal: -y, color: color.rgb)
        geometry[32] = .init(position: x, normal: -y, color: color.rgb)
        geometry[33] = .init(position: .zero, normal: -y, color: color.rgb)
        geometry[34] = .init(position: z, normal: -y, color: color.rgb)
        geometry[35] = .init(position: x + z, normal: -y, color: color.rgb)
        
        return geometry
    }
    
    init(metalKitView: MTKView) {
        device = metalKitView.device!
        commandQueue = device.makeCommandQueue()!
        
        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1
        
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: MTLResourceOptions.storageModeShared)!
        uniforms = uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        
        let library = device.makeDefaultLibrary()!
        
        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Unable to compile render pipeline state: \(error)")
        }
        
        vertexBuffer = device.makeBuffer(length: Renderer.maximalVertexCount * MemoryLayout<Vertex>.stride, options: .cpuCacheModeWriteCombined)!
        vertices = vertexBuffer.contents().bindMemory(to: Vertex.self, capacity: Renderer.maximalVertexCount)
        
        super.init()
    }
    
    func draw(in view: MTKView) {
        uniforms.pointee.projection = perspectiveTransform(fovy: 1.0472, aspectRatio: aspectRatio)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        renderPassDescriptor.colorAttachments[0].clearColor = .init(red: 0.01, green: 0.01, blue: 0.01, alpha: 0.0)
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        renderEncoder.label = "Primary Render Encoder"
        
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)
        
        renderEncoder.setRenderPipelineState(pipelineState)
        
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: Int(BufferIndexUniforms))
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(BufferIndexVertices))
        
        renderEncoder.pushDebugGroup("Draw Geometries")
        
        for geometry in geometries {
            renderEncoder.pushDebugGroup("Draw Geometry '\(geometry.name)'")
            
            uniforms.pointee.transform = geometry.transform()
            uniforms.pointee.translation = geometry.translation
            renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: Int(BufferIndexUniforms))
            
            let vertexStart = geometry.vertices.baseAddress! - vertices
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: vertexStart, vertexCount: geometry.vertices.count)
            
            renderEncoder.popDebugGroup()
        }
        
        renderEncoder.popDebugGroup()
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        aspectRatio = Float(size.width / size.height)
    }
}

/// Left-handed perspective projection matrix.
/// The camera looks in the positive z-direction.
func perspectiveTransform(fovy: Float, aspectRatio: Float) -> simd_float4x4 {
    // Scale x and y according to the field of view and the given aspect ratio.
    // Then copy the z value to the w coordinate.
    // The resulting matrix is actually so sparse that it could be represented by a single vector.
    let y = 1 / tanf(fovy * 0.5)
    let x = y / aspectRatio
    return simd_float4x4(columns: (
                            simd_float4(x, 0, 0, 0),
                            simd_float4(0, y, 0, 0),
                            simd_float4(0, 0, 1, 1),
                            simd_float4(0, 0, 0, 0)))
}
