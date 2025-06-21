//
//  grayscale.metal
//  Canva Demo
//
//  Created by Ben Liu on 21/6/2025.
//

#include <metal_stdlib>
using namespace metal;

// Compute kernel for applying a grayscale effect
kernel void grayscaleShader(
    texture2d<half, access::read> inTexture [[ texture(0) ]],
    texture2d<half, access::write> outTexture [[ texture(1) ]],
    uint2 gid [[ thread_position_in_grid ]])
{
    // Ensure we don't read/write outside the texture bounds
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    // Read the original pixel color
    half4 inColor = inTexture.read(gid);
    // Compute luminance using Rec. 709 coefficients
    half gray = dot(inColor.rgb, half3(0.299, 0.587, 0.114));
    // Write the grayscale color back to the output texture
    outTexture.write(half4(gray, gray, gray, inColor.a), gid);
}
