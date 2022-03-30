//
//  MetalHeaders.h
//  yuvconvert
//
//  Created by Tan Thor Jen on 26/11/20.
//

#ifndef MetalHeaders_h
#define MetalHeaders_h

#include <simd/simd.h>

typedef struct
{
    // Positions in pixel space. A value of 100 indicates 100 pixels from the origin/center.
    vector_float2 position;

    // 2D texture coordinate
    vector_float2 textureCoordinate;
} MetalVertex;

typedef struct {
    float brightness;
} FragmentParms;

#endif
