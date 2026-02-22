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
// Mode 0: Organic Flow — domain-warped FBM
// ============================================================
static float3 modeOrganicFlow(float2 centered, float dist, float time, float3 theme, float3 comp) {
    float slowTime = time * 0.15;
    float flow1 = fbm(centered * 1.2, slowTime);
    float flow2 = fbm(centered * 1.5 + float2(3.7, 1.3), slowTime * 1.3);
    float flow = flow1 * 0.6 + flow2 * 0.4;
    flow = flow * 0.5 + 0.5;

    float3 color = mix(theme, comp, flow * 0.5);
    color *= flow * 0.8;

    float vignette = smoothstep(1.6, 0.2, dist);
    color *= vignette;
    return color;
}

// ============================================================
// Mode 1: Mandala — radial sacred geometry
// ============================================================
static float3 modeMandala(float2 centered, float dist, float time, float3 theme, float3 comp) {
    float angle = atan2(centered.y, centered.x);

    // Multi-frequency mandala
    float m6 = sin(angle * 6.0 + time * 0.3) * 0.5 + 0.5;
    float m12 = sin(angle * 12.0 - time * 0.2) * 0.5 + 0.5;
    float radial1 = sin(dist * 8.0 - time * 0.5) * 0.5 + 0.5;
    float radial2 = sin(dist * 14.0 + time * 0.3) * 0.5 + 0.5;

    float pattern = m6 * radial1 * 0.6 + m12 * radial2 * 0.4;
    pattern *= smoothstep(1.8, 0.1, dist);

    // Rotating inner ring
    float ring = smoothstep(0.02, 0.0, abs(dist - 0.5 - 0.1 * sin(time * 0.4)));
    ring += smoothstep(0.015, 0.0, abs(dist - 0.8 - 0.05 * sin(time * 0.3)));

    float3 color = theme * pattern * 1.2 + comp * ring * 0.8;
    return color;
}

// ============================================================
// Mode 2: Point Cloud — drifting luminous particles
// ============================================================
static float3 modePointCloud(float2 uv, float2 centered, float dist, float time, float3 theme) {
    float3 color = float3(0.0);

    // Dense layer
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
            color += theme * smoothstep(0.12, 0.0, d) * bright * pulse * 0.7;
            // Bright white sparkle on closest points
            color += float3(1.0) * smoothstep(0.04, 0.0, d) * bright * pulse * 0.4;
        }
    }

    // Sparse bright layer
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
            float glow = smoothstep(0.25, 0.0, d) * bright * pulse;
            color += mix(theme, float3(1.0), 0.5) * glow * 0.5;
        }
    }

    float vignette = smoothstep(1.5, 0.3, dist);
    color *= vignette;
    return color;
}

// ============================================================
// Mode 3: Aurora — northern lights ribbons
// ============================================================
static float3 modeAurora(float2 centered, float2 uv, float dist, float time, float3 theme, float3 comp) {
    float3 color = float3(0.0);

    // Horizontal wave ribbons at different heights
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float yOffset = -0.3 + fi * 0.2;
        float wave = simplex2d(float2(centered.x * 2.0 + fi * 0.7, time * 0.12 + fi * 1.3));
        float ribbon = smoothstep(0.15, 0.0, abs(centered.y - yOffset - wave * 0.4));
        ribbon *= smoothstep(1.5, 0.0, abs(centered.x));
        float3 ribbonColor = mix(theme, comp, fi / 4.0);
        color += ribbonColor * ribbon * 0.5;
    }

    // Vertical shimmer
    float shimmer = simplex2d(float2(uv.x * 30.0, time * 0.5));
    shimmer = max(shimmer, 0.0);
    color += theme * shimmer * 0.08;

    // Soft glow base
    float glow = smoothstep(1.2, 0.0, dist) * 0.1;
    color += theme * glow;

    return color;
}

// ============================================================
// Mode 4: Pulse Grid — cyberpunk grid with traveling pulses
// ============================================================
static float3 modePulseGrid(float2 centered, float2 uv, float dist, float time, float3 theme, float3 comp) {
    float3 color = float3(0.0);

    // Grid lines
    float2 gridUv = uv * 20.0;
    float2 gridFrac = fract(gridUv);
    float lineX = smoothstep(0.06, 0.0, abs(gridFrac.x - 0.5));
    float lineY = smoothstep(0.06, 0.0, abs(gridFrac.y - 0.5));
    float grid = max(lineX, lineY);

    // Traveling pulse rings from center
    float pulse1 = smoothstep(0.06, 0.0, abs(fract(dist * 2.0 - time * 0.3) - 0.5));
    float pulse2 = smoothstep(0.04, 0.0, abs(fract(dist * 2.0 - time * 0.3 + 0.5) - 0.5));

    // Intersection highlights
    float intersect = lineX * lineY;

    color += theme * grid * 0.25;
    color += comp * pulse1 * 0.5;
    color += theme * pulse2 * 0.3;
    color += float3(1.0) * intersect * 0.15;

    // Scanline
    float scanline = smoothstep(0.02, 0.0, abs(fract(uv.y * 3.0 - time * 0.15) - 0.5));
    color += theme * scanline * 0.2;

    float vignette = smoothstep(1.8, 0.3, dist);
    color *= vignette;
    return color;
}

// ============================================================
// Mode 5: Combined — all layers mixed (original)
// ============================================================
static float3 modeCombined(float2 centered, float2 uv, float dist, float time, float3 theme, float3 comp) {
    // FBM flow
    float slowTime = time * 0.15;
    float flow1 = fbm(centered * 1.2, slowTime);
    float flow2 = fbm(centered * 1.5 + float2(3.7, 1.3), slowTime * 1.3);
    float flow = flow1 * 0.6 + flow2 * 0.4;
    flow = flow * 0.5 + 0.5;

    // Mandala
    float angle = atan2(centered.y, centered.x);
    float mandala = sin(angle * 6.0 + time * 0.3) * 0.5 + 0.5;
    float radialWave = sin(dist * 8.0 - time * 0.5) * 0.5 + 0.5;
    mandala *= radialWave * smoothstep(1.8, 0.2, dist);

    // Points
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

    // Compose
    float3 color = float3(0.0);
    color += mix(theme, comp, flow * 0.4) * flow * 0.4;
    color += theme * 1.2 * mandala * 0.25;
    color += mix(theme, float3(1.0), 0.6) * points * 0.35;

    float vignette = smoothstep(1.5, 0.3, dist);
    float edgeGlow = smoothstep(0.6, 1.3, dist) * (1.0 - smoothstep(1.3, 1.8, dist));
    color += theme * edgeGlow * 0.3;
    color *= vignette;
    return color;
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
    float mode
) {
    if (intensity < 0.001) {
        return half4(0.0h);
    }

    float2 uv = position / float2(viewWidth, viewHeight);
    float2 centered = uv * 2.0 - 1.0;
    centered.x *= viewWidth / viewHeight;
    float dist = length(centered);

    float3 theme = float3(themeR, themeG, themeB);
    float3 comp = float3(theme.z, theme.x, theme.y);

    int m = int(mode);
    float3 color;
    switch (m) {
        case 0:  color = modeOrganicFlow(centered, dist, time, theme, comp); break;
        case 1:  color = modeMandala(centered, dist, time, theme, comp); break;
        case 2:  color = modePointCloud(uv, centered, dist, time, theme); break;
        case 3:  color = modeAurora(centered, uv, dist, time, theme, comp); break;
        case 4:  color = modePulseGrid(centered, uv, dist, time, theme, comp); break;
        default: color = modeCombined(centered, uv, dist, time, theme, comp); break;
    }

    float alpha = intensity * length(color) * 1.5;
    alpha = clamp(alpha, 0.0, intensity * 0.85);

    return half4(half3(color), half(alpha));
}
