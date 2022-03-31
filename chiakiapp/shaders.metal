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

constexpr sampler mySampler (mag_filter::linear,
                                  min_filter::linear);

fragment float4 grayShader(RasterizerData in [[stage_in]],
                           texture2d<half> yTex [[ texture(0) ]],
                           texture2d<half> uTex [[ texture(1) ]],
                           texture2d<half> vTex [[ texture(2) ]],
                           constant FragmentParms &parms [[buffer(1)]])
{
    const float2 coord2 = float2(in.textureCoordinate.x, in.textureCoordinate.y / 2.0);
    const half4 y = yTex.sample(mySampler, in.textureCoordinate);
    const half4 u = uTex.sample(mySampler, coord2) - 0.5;
    const half4 v = vTex.sample(mySampler, coord2) - 0.5;

    return float4(1.164 * y.r               + 1.596 * v.r,
                  1.164 * y.r - 0.392 * u.r - 0.813 * v.r,
                  1.164 * y.r + 2.017 * u.r              ,
                  1.0);
}

