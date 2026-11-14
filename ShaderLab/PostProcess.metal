#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
#include "ShaderUtils.h"
using namespace metal;

// Post-process pass: palette-based coloring + posterization + pixelation + grid lines.
// Applied as a layerEffect so it can sample at grid cell centers for pixelation.
// Input: grayscale auto-contrasted luminance from the shader (after optional blur).
// Pipeline: shader(grayscale) -> blur -> [this] palette map + posterize + pixelate + grid

[[ stitchable ]]
half4 posterizePixelateEffect(
    float2 position, SwiftUI::Layer layer,
    float pixelSize, float gridThickness,
    float posterizeLevels,
    float paletteCount,
    // 8 palette stops x 3 RGB channels = 24 floats
    float p0r, float p0g, float p0b,
    float p1r, float p1g, float p1b,
    float p2r, float p2g, float p2b,
    float p3r, float p3g, float p3b,
    float p4r, float p4g, float p4b,
    float p5r, float p5g, float p5b,
    float p6r, float p6g, float p6b,
    float p7r, float p7g, float p7b
) {
    // Step 1: Pixelate — snap sample position to grid cell center
    float2 samplePos = position;
    float gridDarken = 0.0;

    if (pixelSize > 1.0) {
        float2 cell = floor(position / pixelSize);
        samplePos = (cell + 0.5) * pixelSize;

        // Grid lines (thickness driven by gridThickness param)
        float2 cellPos = fract(position / pixelSize);
        float lineThick = gridThickness / pixelSize;
        gridDarken = max(step(cellPos.x, lineThick), step(cellPos.y, lineThick));
    }

    // Step 2: Sample the blurred grayscale shader output
    half4 src = layer.sample(samplePos);

    // Luminance is in the grayscale channels (R=G=B=lum)
    float lum = float(src.r);
    float alpha = float(src.a);

    // Step 3: Build palette array from individual floats
    int count = int(paletteCount);
    count = clamp(count, 2, 8);
    float3 palette[8] = {
        float3(p0r, p0g, p0b),
        float3(p1r, p1g, p1b),
        float3(p2r, p2g, p2b),
        float3(p3r, p3g, p3b),
        float3(p4r, p4g, p4b),
        float3(p5r, p5g, p5b),
        float3(p6r, p6g, p6b),
        float3(p7r, p7g, p7b),
    };

    // Step 4: Map luminance through palette
    float3 color;
    if (posterizeLevels >= 2.0) {
        color = gradientMapPosterize(lum, palette, count, posterizeLevels);
    } else {
        color = gradientMapSmooth(lum, palette, count);
    }

    // Step 5: Grid line darkening
    color *= (1.0 - gridDarken);
    alpha *= (1.0 - gridDarken);

    return half4(half3(color), half(alpha));
}
