#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
#include "ShaderUtils.h"
using namespace metal;

// Post-process pass: theme coloring + posterization + pixelation + grid lines.
// Applied as a layerEffect so it can sample at grid cell centers for pixelation.
// Input: grayscale auto-contrasted luminance from the shader (after optional blur).
// Pipeline: shader(grayscale) → blur → [this] theme + posterize + pixelate + grid

[[ stitchable ]]
half4 posterizePixelateEffect(
    float2 position, SwiftUI::Layer layer,
    float pixelSize, float gridThickness,
    float posterizeLevels,
    float themeR, float themeG, float themeB,
    float hueSpread, float complementMix
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

    // Step 3: Theme coloring + posterization
    float3 theme = float3(themeR, themeG, themeB);
    float3 color;

    if (posterizeLevels >= 2.0) {
        color = posterize(lum, theme, posterizeLevels, hueSpread, complementMix);
    } else {
        color = theme * lum;
    }

    // Step 4: Grid line darkening
    color *= (1.0 - gridDarken);
    alpha *= (1.0 - gridDarken);

    return half4(half3(color), half(alpha));
}
