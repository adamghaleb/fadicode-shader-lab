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

    if (pixelSize > 1.0) {
        float2 gridCount = float2(viewWidth, viewHeight) / pixelSize;
        s.uv = (floor(s.uv * gridCount) + 0.5) / gridCount;

        float2 cellPos = fract(position / pixelSize);
        float lineThickness = 1.0 / pixelSize;
        float lineX = step(cellPos.x, lineThickness);
        float lineY = step(cellPos.y, lineThickness);
        s.gridDarken = max(lineX, lineY) * gridOpacity;
    }

    s.centered = s.uv * 2.0 - 1.0;
    s.centered.x *= viewWidth / viewHeight;
    s.dist = length(s.centered);

    return s;
}

static inline half4 pipelineFinalize(
    float lum, float intensity, float3 theme,
    float posterizeLevels, float gridDarken
) {
    // Contrast boost: aggressive S-curve
    lum = smoothstep(0.0, 0.55, lum);
    lum = lum * lum * (3.0 - 2.0 * lum);

    // Colorize
    float3 color;
    if (posterizeLevels >= 2.0) {
        color = posterize(lum, theme, posterizeLevels);
    } else {
        color = theme * lum;
    }

    // Grid line darkening
    color *= (1.0 - gridDarken);

    float alpha = intensity * lum * 1.5;
    alpha = clamp(alpha, 0.0, intensity * 0.85);
    alpha *= (1.0 - gridDarken);

    return half4(half3(color), half(alpha));
}

#endif
