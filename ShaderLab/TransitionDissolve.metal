#include <metal_stdlib>
using namespace metal;

// ============================================================
// Luminance-staggered crossfade transition.
// Bright areas of the new shader fade in first while bright areas
// of the old shader fade out first — sweeping from white to black.
//
// These effects run AFTER the post-process (theme + posterize + pixelate),
// so they extract perceived luminance from the themed color.
// ============================================================

static inline float perceivedLum(half4 c) {
    return float(c.r) * 0.299 + float(c.g) * 0.587 + float(c.b) * 0.114;
}

// Old shader: bright parts fade out first as progress increases.
[[ stitchable ]]
half4 lumaFadeOutEffect(
    float2 position, half4 currentColor,
    float progress
) {
    if (progress <= 0.0) return currentColor;
    if (progress >= 1.0) return half4(0.0h);

    float lum = perceivedLum(currentColor);

    // Threshold sweeps from 1→0: brightest parts disappear first
    float threshold = 1.0 - progress;
    float softness = 0.15;
    float keep = 1.0 - smoothstep(threshold - softness, threshold + softness, lum);

    half4 result = currentColor;
    result.a *= half(keep);
    return result;
}

// New shader: bright parts fade in first as progress increases.
[[ stitchable ]]
half4 lumaFadeInEffect(
    float2 position, half4 currentColor,
    float progress
) {
    if (progress >= 1.0) return currentColor;
    if (progress <= 0.0) return half4(0.0h);

    float lum = perceivedLum(currentColor);

    // Threshold sweeps from 1→0: brightest parts appear first
    float threshold = 1.0 - progress;
    float softness = 0.15;
    float reveal = smoothstep(threshold + softness, threshold - softness, lum);

    half4 result = currentColor;
    result.a *= half(reveal);
    return result;
}
