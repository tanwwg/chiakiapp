//
//  shaders.metal
//  yuvconvert
//
//  Created by Tan Thor Jen on 26/11/20.
//

#include <metal_stdlib>
using namespace metal;

#import "MetalHeaders.h"

typedef struct
{
    float4 position [[position]];
    float2 textureCoordinate;

} RasterizerData;

// Vertex Function
vertex RasterizerData
vertexShader(uint vertexID [[ vertex_id ]],
             constant MetalVertex *vertexArray [[ buffer(0) ]],
             constant vector_float2 *viewportSizePointer  [[ buffer(1) ]])
{
    RasterizerData out;

    float2 pixelSpacePosition = vertexArray[vertexID].position.xy;

    float2 viewportSize = float2(*viewportSizePointer);

    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
    out.position.xy = pixelSpacePosition / (viewportSize / 2.0);

    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
    return out;
}

fragment float4 grayShader(RasterizerData in [[stage_in]],
                         texture2d<uint> colorTexture [[ texture(0) ]],
                         constant FragmentParms &parms [[buffer(1)]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    const uint4 c = colorTexture.sample(textureSampler, in.textureCoordinate);
    
    return float4(c.r / 256.0,
                  c.r / 256.0,
                  c.r / 256.0,
                  1.0);
}

// Fragment function
fragment float4
yuvShader(RasterizerData in [[stage_in]],
               texture2d<half> colorTexture [[ texture(0) ]],
               constant FragmentParms &parms [[buffer(1)]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    const half4 c = colorTexture.sample(textureSampler, in.textureCoordinate);
    
//    half y = (c.g * 1.164 - 16.0/256.0);
    half y = c.g;
    half u = c.b - 0.5;
    half v = c.r - 0.5;
    
    half ee = 1 + parms.brightness * 2;
    y = pow(y, 1/ee);
    
    return float4(y + 0.00000 * u + 1.13983 * v,
                  y - 0.39465 * u - 0.58060 * v,
                  y + 2.03211 * u,
                  1.0);
}

fragment float4
rgbShader(RasterizerData in [[stage_in]],
               texture2d<half> colorTexture [[ texture(0) ]],
               constant FragmentParms &parms [[buffer(1)]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    const half4 c = colorTexture.sample(textureSampler, in.textureCoordinate);
    
    return float4(c.r, c.g, c.b, 1.0);
}
