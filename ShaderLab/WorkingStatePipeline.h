#ifndef WorkingStatePipeline_h
#define WorkingStatePipeline_h

#include "ShaderUtils.h"

// ============================================================
// Shared pipeline: pixelation setup + contrast + colorize + grid
// Each shader mode file includes this and calls setup/finalize.
// ============================================================

struct PipelineSetup {
    float2 uv;
    float2 centered;
    float dist;
    float gridDarken;
};

static inline PipelineSetup pipelineSetup(
    float2 position, float viewWidth, float viewHeight,
    float pixelSize, float gridOpacity
) {
    PipelineSetup s;
    s.uv = position / float2(viewWidth, viewHeight);
    s.gridDarken = 0.0;
    // Pixelation now handled in post-process layerEffect —
    // shaders always compute at full resolution for blur quality.

    s.centered = s.uv * 2.0 - 1.0;
    s.centered.x *= viewWidth / viewHeight;
    s.dist = length(s.centered);

    return s;
}

static inline half4 pipelineFinalize(
    float lum, float intensity, float3 theme,
    float posterizeLevels, float gridDarken,
    float hueSpread = 0.10, float complementMix = 0.0
) {
    // Auto-contrast: single S-curve with good midtone spread.
    // 0.55 upper bound = strong contrast, but the smoothstep shape
    // distributes midtones smoothly (no double-curve crushing).
    lum = smoothstep(0.0, 0.55, lum);

    // Output grayscale luminance — theme coloring, posterization,
    // pixelation, and grid lines are applied in the post-process pass.
    float3 color = float3(lum);

    float alpha = intensity * lum * 1.5;
    alpha = clamp(alpha, 0.0, intensity * 0.85);

    return half4(half3(color), half(alpha));
}

#endif
