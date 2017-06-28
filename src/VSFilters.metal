//
//  VSFilters.metal
//  vs-metal
//
//  Created by SATOSHI NAKAJIMA on 6/22/17.
//  Copyright © 2017 SATOSHI NAKAJIMA. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void
color(texture2d<half, access::write> outTexture [[texture(0)]],
      const device float4& color [[ buffer(1) ]],
     uint2                          gid         [[thread_position_in_grid]])
{
    outTexture.write(half4(color), gid);
}

kernel void
colors(texture2d<half, access::write> outTexture [[texture(0)]],
      const device float4& color1 [[ buffer(1) ]],
      const device float4& color2 [[ buffer(2) ]],
      const device float& ratio [[ buffer(3) ]],
      uint2                          gid         [[thread_position_in_grid]])
{
    outTexture.write(half4(mix(color1, color2, ratio)), gid);
}

// Rec 709 LUMA values for grayscale image conversion
//constant half3 kRec709Luma = half3(0.2126, 0.7152, 0.0722);

// Grayscale compute kernel
kernel void
mono(texture2d<half, access::read>  inTexture  [[texture(0)]],
                texture2d<half, access::write> outTexture [[texture(1)]],
                const device float3& weight [[ buffer(2) ]],
                const device float4& color [[ buffer(3) ]],
                uint2                          gid         [[thread_position_in_grid]])
{
    // Check if the pixel is within the bounds of the output texture
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
        // Return early if the pixel is out of bounds
        return;
    }
    
    half4 inColor  = inTexture.read(gid);
    half  gray     = dot(inColor.rgb, half3(weight));
    outTexture.write(half4(gray, gray, gray, inColor.a) * half4(color), gid);
}

kernel void
toone(texture2d<half, access::read>  inTexture  [[texture(0)]],
                texture2d<half, access::write> outTexture [[texture(1)]],
                const device float& levels [[ buffer(2) ]],
                const device float3& weight [[ buffer(3) ]],
                uint2                          gid         [[thread_position_in_grid]])
{
    // Check if the pixel is within the bounds of the output texture
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
        // Return early if the pixel is out of bounds
        return;
    }

    half3 w = half3(weight / (weight.r + weight.g + weight.b));
    half4 inColor  = inTexture.read(gid);
    half y = dot(inColor.rgb, w);
    half z = floor(y * levels + 0.5) / levels;
    outTexture.write(half4(inColor.rgb * (z / y), inColor.a), gid);
}

kernel void
invert(texture2d<half, access::read>  inTexture  [[texture(0)]],
                texture2d<half, access::write> outTexture [[texture(1)]],
                uint2                          gid         [[thread_position_in_grid]])
{
    // Check if the pixel is within the bounds of the output texture
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
        // Return early if the pixel is out of bounds
        return;
    }

    half4 inColor  = inTexture.read(gid);
    outTexture.write(half4(1.0 - inColor.rgb, inColor.a), gid);
}

kernel void
boolean(texture2d<half, access::read>  inTexture  [[texture(0)]],
      texture2d<half, access::write> outTexture [[texture(1)]],
      const device float2& range [[ buffer(2) ]],
      const device float3& weight [[ buffer(3) ]],
      const device float4& color1 [[ buffer(4) ]],
      const device float4& color2 [[ buffer(5) ]],
      uint2                          gid         [[thread_position_in_grid]])
{
    // Check if the pixel is within the bounds of the output texture
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
        // Return early if the pixel is out of bounds
        return;
    }
    
    half3 w = half3(weight / (weight.r + weight.g + weight.b));
    half4 inColor  = inTexture.read(gid);
    half d = dot(inColor.rgb, w);
    half4 outColor = (range.x < d && d < range.y) ? half4(color2) : half4(color1);
    outTexture.write(outColor, gid);
}

kernel void
gradientmap(texture2d<half, access::read>  inTexture  [[texture(0)]],
     texture2d<half, access::write> outTexture [[texture(1)]],
     const device float3& weight [[ buffer(2) ]],
     const device float4& color1 [[ buffer(3) ]],
     const device float4& color2 [[ buffer(4) ]],
     uint2                          gid         [[thread_position_in_grid]])
{
    // Check if the pixel is within the bounds of the output texture
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
        // Return early if the pixel is out of bounds
        return;
    }
    
    half3 w = half3(weight / (weight.r + weight.g + weight.b));
    half4 inColor  = inTexture.read(gid);
    half d = dot(inColor.rgb, w);
    outTexture.write(mix(half4(color1), half4(color2), d), gid);
}

kernel void
halftone(texture2d<half, access::read>  inTexture  [[texture(0)]],
            texture2d<half, access::write> outTexture [[texture(1)]],
            const device float3& weight [[ buffer(2) ]],
            const device float4& color1 [[ buffer(3) ]],
            const device float4& color2 [[ buffer(4) ]],
            const device float& radius [[ buffer(5) ]],
            const device float& scale [[ buffer(6) ]],
            uint2                          gid         [[thread_position_in_grid]])
{
    // Check if the pixel is within the bounds of the output texture
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
        // Return early if the pixel is out of bounds
        return;
    }
    
    half3 w = half3(weight / (weight.r + weight.g + weight.b));
    half4 inColor  = inTexture.read(gid);
    half v = (1.0 - dot(inColor.rgb, w)) * scale;
    half2 rem = (half2(gid % uint(radius * 2)) - radius) / radius;
    half d = sqrt(dot(rem, rem));
    outTexture.write((v > d) ? half4(color1) : half4(color2), gid);
}

kernel void
sobel(texture2d<half, access::read>  inTexture  [[texture(0)]],
                texture2d<half, access::write> outTexture [[texture(1)]],
                const device float& weight [[ buffer(2) ]],
                uint2                          gid         [[thread_position_in_grid]])
{
    // Check if the pixel is within the bounds of the output texture
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
        // Return early if the pixel is out of bounds
        return;
    }
    
    half n = inTexture.read(uint2(gid.x, gid.y-1)).r;
    half s = inTexture.read(uint2(gid.x, gid.y+1)).r;
    half e = inTexture.read(uint2(gid.x+1, gid.y)).r;
    half w = inTexture.read(uint2(gid.x-1, gid.y)).r;
    half nw = inTexture.read(uint2(gid.x-1, gid.y-1)).r;
    half ne = inTexture.read(uint2(gid.x+1, gid.y-1)).r;
    half sw = inTexture.read(uint2(gid.x-1, gid.y+1)).r;
    half se = inTexture.read(uint2(gid.x+1, gid.y+1)).r;
    half dx = weight * (n - s) + (nw + ne - se - sw);
    half dy = weight * (w - e) + (nw + sw - se - ne);
    outTexture.write(half4((dx + 1.0)/2.0, (dy + 1.0)/2.0, sqrt(dx*dy + dy*dy), 1.0), gid);
}

kernel void
canny_edge(texture2d<half, access::read>  inTexture  [[texture(0)]],
                texture2d<half, access::write> outTexture [[texture(1)]],
                const device float& threshold [[ buffer(2) ]],
                const device float& thin [[ buffer(3) ]],
                const device float4& color [[ buffer(4) ]],
                uint2                          gid         [[thread_position_in_grid]])
{
    // Check if the pixel is within the bounds of the output texture
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
        // Return early if the pixel is out of bounds
        return;
    }

    half3 sobel = inTexture.read(gid).rgb;
    half d = sobel.z;
    half dx2 = sobel.x * sobel.x;
    half dy2 = sobel.y * sobel.y;
    half n = inTexture.read(uint2(gid.x, gid.y-1)).z;
    half s = inTexture.read(uint2(gid.x, gid.y+1)).z;
    half e = inTexture.read(uint2(gid.x+1, gid.y)).z;
    half w = inTexture.read(uint2(gid.x-1, gid.y)).z;
    d = (dx2 < dy2 && d < max(e,w) * thin) ? 0.0 : d;
    d = (dx2 > dy2 && d < max(n,s) * thin) ? 0.0 : d;
    d = (d < threshold) ? 0.0 : color.a;
    outTexture.write(half4(half3(color.rgb), d), gid);
}

kernel void
tint(texture2d<half, access::read>  inTexture  [[texture(0)]],
     texture2d<half, access::write> outTexture [[texture(1)]],
     const device float& ratio [[ buffer(2) ]],
     const device float4& color [[ buffer(3) ]],
     uint2                          gid         [[thread_position_in_grid]])
{
    // Check if the pixel is within the bounds of the output texture
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
        // Return early if the pixel is out of bounds
        return;
    }
    
    half4 inColor  = inTexture.read(gid);
    outTexture.write(mix(inColor, half4(color), half4(ratio)), gid);
}

kernel void
enhancer(texture2d<half, access::read>  inTexture  [[texture(0)]],
     texture2d<half, access::write> outTexture [[texture(1)]],
     const device float2& red [[ buffer(2) ]],
     const device float2& green [[ buffer(3) ]],
     const device float2& blue [[ buffer(4) ]],
     uint2                          gid         [[thread_position_in_grid]])
{
    // Check if the pixel is within the bounds of the output texture
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
        // Return early if the pixel is out of bounds
        return;
    }
    
    half4 inColor  = inTexture.read(gid);
    half3 outColor = inColor.rgb - half3(red.x, green.x, blue.x);
    outColor /= half3(red.y-red.x, green.y-green.x, blue.y-blue.x);
    outTexture.write(half4(outColor, inColor.a), gid);
}

kernel void
hue_filter(texture2d<half, access::read>  inTexture  [[texture(0)]],
         texture2d<half, access::write> outTexture [[texture(1)]],
         const device float2& hue [[ buffer(2) ]],
         const device float2& chroma [[ buffer(3) ]],
         uint2                          gid         [[thread_position_in_grid]])
{
    // Check if the pixel is within the bounds of the output texture
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
        // Return early if the pixel is out of bounds
        return;
    }
    
    half4 inColor  = inTexture.read(gid);
    float R = inColor.r;
    float G = inColor.g;
    float B = inColor.b;
    float M = max(inColor.r, max(inColor.g, inColor.b));
    float m = min(inColor.r, min(inColor.g, inColor.b));
    float C = M - m;
    float hue0 = (M == m) ? 0.0 :
    (M == R) ? (G - B) / C :
    (M == G) ? (B - R) / C + 2.0 : (R - G) / C + 4.0;
    hue0 = (hue0 < 0.0) ? hue0 + 6.0 : hue0;
    hue0 = hue0 * 60.0;
    hue0 = (hue.x < hue0) ? hue0 : hue0 + 360.0;
    float high = (hue.x < hue.y) ? hue.y : hue.y + 360.0;
    half a = (hue0 < high && chroma.x <= C && C <= chroma.y) ? 1.0 : 0.0;
    //outTexture.write(half4(C, C, C, 1.0), gid);
    outTexture.write(half4(inColor.rgb, a), gid);
}

#define M_PI 3.14159265

kernel void
lighter(texture2d<half, access::read>  inTexture  [[texture(0)]],
                texture2d<half, access::write> outTexture [[texture(1)]],
                const device float& ratio [[ buffer(2) ]],
                uint2                          gid         [[thread_position_in_grid]])
{
    // Check if the pixel is within the bounds of the output texture
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
        // Return early if the pixel is out of bounds
        return;
    }
    
    half4 inColor  = inTexture.read(gid);
    inColor.rgb = sin(clamp(inColor.rgb * half(ratio), half(0.0), half(1.0)) * M_PI/2.0);
    outTexture.write(half4(inColor), gid);
}

kernel void
hueshift(texture2d<half, access::read>  inTexture  [[texture(0)]],
                texture2d<half, access::write> outTexture [[texture(1)]],
                const device float& shift [[ buffer(2) ]],
                uint2                          gid         [[thread_position_in_grid]])
{
    // Check if the pixel is within the bounds of the output texture
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
        // Return early if the pixel is out of bounds
        return;
    }
    
    half4 RGBA0  = inTexture.read(gid);
    float R0 = RGBA0.r;
    float G0 = RGBA0.g;
    float B0 = RGBA0.b;
    float M0 = max(R0, max(G0, B0));
    float m0 = min(R0, min(G0, B0));
    float C0 = M0 - m0;
    float H0 = (M0 == m0) ? 0.0 :
                        (M0 == R0) ? (G0 - B0) / C0 :
                        (M0 == G0) ? (B0 - R0) / C0 + 2.0 : (R0 - G0) / C0 + 4.0;
    H0 = (H0 < 0.0) ? H0 + 6.0 : H0;
    float L0 = (M0 + m0) / 2.0;
    float S0 = M0 - m0;
    S0 = (L0 == 0.0 || S0 == 0.0) ? 0.0 :
         S0 / ((L0 < 0.5) ? (M0 + m0) : (2.0 - M0 - m0));

    float L = L0;
    float H = H0 + shift / 60.0;
    float S = S0;
    H = (H < 6.0) ? H : H - 6.0;

    float R = L;
    float G = L;
    float B = L;
    float v = (L < 0.5) ? L * (1.0 + S) : (L + S - L * S);
    float m = L + L - v;
    float sv = (v - m) / v;
    float sex = floor(H);
    float fract = H - sex;
    float vsf = v * sv * fract;
    float mid1 = m + vsf;
    float mid2 = v - vsf;
    
    R = (sex == 4.0) ? mid1 : (sex == 0.0 || sex == 5.0) ? v : (sex == 1.0) ? mid2 : m;
    G = (sex == 0.0) ? mid1 : (sex == 1.0 || sex == 2.0) ? v : (sex == 3.0) ? mid2 : m;
    B = (sex == 2.0) ? mid1 : (sex == 3.0 || sex == 4.0) ? v : (sex == 5.0) ? mid2 : m;

    outTexture.write(half4(R, G, B, RGBA0.a), gid);
}


