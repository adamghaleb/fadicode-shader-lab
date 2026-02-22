#include <metal_stdlib>
using namespace metal;

// ============================================================
// Shared noise utilities
// ============================================================

static float2 hash22(float2 p) {
    float3 p3 = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

static float hash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float simplex2d(float2 p) {
    const float K1 = 0.366025404;
    const float K2 = 0.211324865;
    float2 i = floor(p + (p.x + p.y) * K1);
    float2 a = p - i + (i.x + i.y) * K2;
    float2 o = (a.x > a.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float2 b = a - o + K2;
    float2 c = a - 1.0 + 2.0 * K2;
    float3 h = max(0.5 - float3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    h = h * h * h * h;
    float2 ga = hash22(i) * 2.0 - 1.0;
    float2 gb = hash22(i + o) * 2.0 - 1.0;
    float2 gc = hash22(i + 1.0) * 2.0 - 1.0;
    float3 n = h * float3(dot(ga, a), dot(gb, b), dot(gc, c));
    return dot(n, float3(70.0));
}

static float fbm(float2 p, float time) {
    float value = 0.0;
    float amplitude = 0.5;
    float2 shift = float2(100.0);
    float2 warp = float2(
        simplex2d(p + float2(0.0, time * 0.1)),
        simplex2d(p + float2(5.2, time * 0.12))
    );
    p += warp * 0.5;
    for (int i = 0; i < 5; i++) {
        value += amplitude * simplex2d(p);
        p = p * 2.0 + shift;
        amplitude *= 0.5;
    }
    return value;
}

// ============================================================
// HSV <-> RGB
// ============================================================

static float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

static float3 rgb2hsv(float3 c) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// ============================================================
// Grayscale shader modes — output luminance only (0..1)
// ============================================================

// Mode 0: Organic Flow
static float modeOrganicFlow(float2 centered, float dist, float time) {
    float slowTime = time * 0.15;
    float flow1 = fbm(centered * 1.2, slowTime);
    float flow2 = fbm(centered * 1.5 + float2(3.7, 1.3), slowTime * 1.3);
    float flow = flow1 * 0.6 + flow2 * 0.4;
    flow = flow * 0.5 + 0.5;
    float lum = flow * 0.8;
    lum *= smoothstep(1.6, 0.2, dist);
    return lum;
}

// Mode 1: Mandala
static float modeMandala(float2 centered, float dist, float time) {
    float angle = atan2(centered.y, centered.x);
    float m6 = sin(angle * 6.0 + time * 0.3) * 0.5 + 0.5;
    float m12 = sin(angle * 12.0 - time * 0.2) * 0.5 + 0.5;
    float radial1 = sin(dist * 8.0 - time * 0.5) * 0.5 + 0.5;
    float radial2 = sin(dist * 14.0 + time * 0.3) * 0.5 + 0.5;
    float pattern = m6 * radial1 * 0.6 + m12 * radial2 * 0.4;
    pattern *= smoothstep(1.8, 0.1, dist);
    float ring = smoothstep(0.02, 0.0, abs(dist - 0.5 - 0.1 * sin(time * 0.4)));
    ring += smoothstep(0.015, 0.0, abs(dist - 0.8 - 0.05 * sin(time * 0.3)));
    return clamp(pattern * 1.2 + ring * 0.6, 0.0, 1.0);
}

// Mode 2: Point Cloud
static float modePointCloud(float2 uv, float2 centered, float dist, float time) {
    float lum = 0.0;
    float2 grid1 = uv * 25.0;
    float2 cellId1 = floor(grid1);
    float2 cellUv1 = fract(grid1);
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            float2 neighbor = float2(float(dx), float(dy));
            float2 id = cellId1 + neighbor;
            float2 rnd = hash22(id);
            float2 pos = neighbor + rnd + 0.15 * sin(time * 0.4 + rnd * 6.28);
            float d = length(cellUv1 - pos);
            float bright = hash21(id + 0.5);
            float pulse = sin(time * (0.5 + bright * 1.5) + bright * 6.28) * 0.5 + 0.5;
            lum += smoothstep(0.12, 0.0, d) * bright * pulse * 0.8;
            lum += smoothstep(0.04, 0.0, d) * bright * pulse * 0.5;
        }
    }
    float2 grid2 = uv * 8.0;
    float2 cellId2 = floor(grid2);
    float2 cellUv2 = fract(grid2);
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            float2 neighbor = float2(float(dx), float(dy));
            float2 id = cellId2 + neighbor;
            float2 rnd = hash22(id + 100.0);
            float2 pos = neighbor + rnd + 0.2 * sin(time * 0.2 + rnd * 6.28);
            float d = length(cellUv2 - pos);
            float bright = hash21(id + 100.5);
            float pulse = sin(time * 0.3 + bright * 6.28) * 0.5 + 0.5;
            lum += smoothstep(0.25, 0.0, d) * bright * pulse * 0.4;
        }
    }
    lum *= smoothstep(1.5, 0.3, dist);
    return clamp(lum, 0.0, 1.0);
}

// Mode 3: Aurora
static float modeAurora(float2 centered, float2 uv, float dist, float time) {
    float lum = 0.0;
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float yOffset = -0.3 + fi * 0.2;
        float wave = simplex2d(float2(centered.x * 2.0 + fi * 0.7, time * 0.12 + fi * 1.3));
        float ribbon = smoothstep(0.15, 0.0, abs(centered.y - yOffset - wave * 0.4));
        ribbon *= smoothstep(1.5, 0.0, abs(centered.x));
        lum += ribbon * 0.5;
    }
    float shimmer = simplex2d(float2(uv.x * 30.0, time * 0.5));
    lum += max(shimmer, 0.0) * 0.08;
    lum += smoothstep(1.2, 0.0, dist) * 0.1;
    return clamp(lum, 0.0, 1.0);
}

// Mode 4: Pulse Grid
static float modePulseGrid(float2 centered, float2 uv, float dist, float time) {
    float2 gridUv = uv * 20.0;
    float2 gridFrac = fract(gridUv);
    float lineX = smoothstep(0.06, 0.0, abs(gridFrac.x - 0.5));
    float lineY = smoothstep(0.06, 0.0, abs(gridFrac.y - 0.5));
    float grid = max(lineX, lineY);
    float pulse1 = smoothstep(0.06, 0.0, abs(fract(dist * 2.0 - time * 0.3) - 0.5));
    float pulse2 = smoothstep(0.04, 0.0, abs(fract(dist * 2.0 - time * 0.3 + 0.5) - 0.5));
    float intersect = lineX * lineY;
    float lum = grid * 0.25 + pulse1 * 0.5 + pulse2 * 0.3 + intersect * 0.15;
    float scanline = smoothstep(0.02, 0.0, abs(fract(uv.y * 3.0 - time * 0.15) - 0.5));
    lum += scanline * 0.2;
    lum *= smoothstep(1.8, 0.3, dist);
    return clamp(lum, 0.0, 1.0);
}

// Mode 5: Combined
static float modeCombined(float2 centered, float2 uv, float dist, float time) {
    float slowTime = time * 0.15;
    float flow1 = fbm(centered * 1.2, slowTime);
    float flow2 = fbm(centered * 1.5 + float2(3.7, 1.3), slowTime * 1.3);
    float flow = flow1 * 0.6 + flow2 * 0.4;
    flow = flow * 0.5 + 0.5;

    float angle = atan2(centered.y, centered.x);
    float mandala = sin(angle * 6.0 + time * 0.3) * 0.5 + 0.5;
    float radialWave = sin(dist * 8.0 - time * 0.5) * 0.5 + 0.5;
    mandala *= radialWave * smoothstep(1.8, 0.2, dist);

    float2 pointGrid = uv * 20.0;
    float2 cellId = floor(pointGrid);
    float2 cellUv = fract(pointGrid);
    float points = 0.0;
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            float2 neighbor = float2(float(dx), float(dy));
            float2 id = cellId + neighbor;
            float2 rnd = hash22(id);
            float2 pos = neighbor + rnd + 0.1 * sin(time * 0.3 + rnd * 6.28);
            float d = length(cellUv - pos);
            float bright = hash21(id + 0.5);
            float pulse = sin(time * (0.5 + bright) + bright * 6.28) * 0.5 + 0.5;
            points += smoothstep(0.15, 0.0, d) * bright * pulse;
        }
    }
    points = min(points, 1.0);

    float lum = flow * 0.4 + mandala * 0.25 + points * 0.35;
    float vignette = smoothstep(1.5, 0.3, dist);
    float edgeGlow = smoothstep(0.6, 1.3, dist) * (1.0 - smoothstep(1.3, 1.8, dist));
    lum += edgeGlow * 0.3;
    lum *= vignette;
    return clamp(lum, 0.0, 1.0);
}


// ============================================================
// Posterize: map grayscale to analogous color palette
// ============================================================

// Builds an analogous palette from the theme color and maps luminance into it.
// - 5 analogous hues spread ±30 degrees around the theme hue
// - Luminance selects which hue AND which brightness band
// - Low lum = dark shadow with slight hue shift
// - High lum = bright highlight pulled toward white
static float3 posterize(float lum, float3 themeRGB, float levels) {
    float3 themeHSV = rgb2hsv(themeRGB);
    float baseHue = themeHSV.x;
    float baseSat = max(themeHSV.y, 0.6); // keep it rich

    // Quantize luminance to hard bands
    float q = floor(lum * levels) / levels;

    // Map luminance to hue offset: dark = cool shift, bright = warm shift
    // This gives natural-feeling analogous variation
    float hueOffset = mix(-0.08, 0.08, q); // ±~30 degrees
    float hue = fract(baseHue + hueOffset);

    // Saturation: rich in midtones, desaturated in darks and highlights
    float sat = baseSat * smoothstep(0.0, 0.3, q) * smoothstep(1.0, 0.7, q);
    // Boost midtones saturation
    sat = max(sat, baseSat * 0.4);

    // Value: quantized, with a minimum so darks aren't invisible
    float val = max(q * 1.3, 0.05);

    return hsv2rgb(float3(hue, sat, val));
}


// ============================================================
// Main entry point
// ============================================================

[[ stitchable ]]
half4 workingStateEffect(
    float2 position,
    half4 currentColor,
    float time,
    float intensity,
    float themeR,
    float themeG,
    float themeB,
    float viewWidth,
    float viewHeight,
    float mode,
    float pixelSize,
    float gridOpacity,
    float posterizeLevels
) {
    if (intensity < 0.001) {
        return half4(0.0h);
    }

    float2 uv = position / float2(viewWidth, viewHeight);

    // --- Pixelation: snap to grid for chunky retro look ---
    float gridDarken = 0.0;
    if (pixelSize > 1.0) {
        float2 gridCount = float2(viewWidth, viewHeight) / pixelSize;
        uv = (floor(uv * gridCount) + 0.5) / gridCount;

        float2 cellPos = fract(position / pixelSize);
        float lineThickness = 1.0 / pixelSize;
        float lineX = step(cellPos.x, lineThickness);
        float lineY = step(cellPos.y, lineThickness);
        gridDarken = max(lineX, lineY) * gridOpacity;
    }

    float2 centered = uv * 2.0 - 1.0;
    centered.x *= viewWidth / viewHeight;
    float dist = length(centered);

    // --- Compute grayscale luminance from shader mode ---
    int m = int(mode);
    float lum;
    switch (m) {
        case 0:  lum = modeOrganicFlow(centered, dist, time); break;
        case 1:  lum = modeMandala(centered, dist, time); break;
        case 2:  lum = modePointCloud(uv, centered, dist, time); break;
        case 3:  lum = modeAurora(centered, uv, dist, time); break;
        case 4:  lum = modePulseGrid(centered, uv, dist, time); break;
        default: lum = modeCombined(centered, uv, dist, time); break;
    }

    // --- Colorize: posterize to analogous palette or plain grayscale ---
    float3 theme = float3(themeR, themeG, themeB);
    float3 color;

    if (posterizeLevels >= 2.0) {
        color = posterize(lum, theme, posterizeLevels);
    } else {
        // No posterization: tint grayscale with theme color
        color = theme * lum;
    }

    // Grid line darkening
    color *= (1.0 - gridDarken);

    float alpha = intensity * lum * 1.5;
    alpha = clamp(alpha, 0.0, intensity * 0.85);
    alpha *= (1.0 - gridDarken * 0.5);

    return half4(half3(color), half(alpha));
}
