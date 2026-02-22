#include <metal_stdlib>
using namespace metal;

// --- Simplex noise helpers ---

// Permutation-style hash
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

// 2D simplex noise
static float simplex2d(float2 p) {
    const float K1 = 0.366025404; // (sqrt(3)-1)/2
    const float K2 = 0.211324865; // (3-sqrt(3))/6

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

// Fractal Brownian Motion with domain warping
static float fbm(float2 p, float time) {
    float value = 0.0;
    float amplitude = 0.5;
    float2 shift = float2(100.0);

    // Domain warp: offset the input by a noise lookup
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

// --- Main shader ---

/// Working state visual effect for fadicode.
/// Renders an organic flowing shader overlay with theme color.
///
/// Parameters:
///   position: current pixel position
///   args[0]: time (seconds, continuously advancing)
///   args[1]: intensity (0.0 = invisible, 1.0 = full prominence)
///   args[2]: theme color red (0-1)
///   args[3]: theme color green (0-1)
///   args[4]: theme color blue (0-1)
///   args[5]: viewport width
///   args[6]: viewport height
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
    float viewHeight
) {
    if (intensity < 0.001) {
        return currentColor;
    }

    // Normalize coordinates
    float2 uv = position / float2(viewWidth, viewHeight);
    float2 centered = uv * 2.0 - 1.0;
    centered.x *= viewWidth / viewHeight; // Correct aspect ratio

    float dist = length(centered);

    // Theme color
    float3 theme = float3(themeR, themeG, themeB);

    // Complementary color: rotate hue ~120 degrees in a simple way
    float3 comp = float3(theme.z, theme.x, theme.y);

    // --- Layer 1: Domain-warped FBM organic flow ---
    float slowTime = time * 0.15;
    float flow1 = fbm(centered * 1.2, slowTime);
    float flow2 = fbm(centered * 1.5 + float2(3.7, 1.3), slowTime * 1.3);
    float flow = flow1 * 0.6 + flow2 * 0.4;
    flow = flow * 0.5 + 0.5; // Remap to 0-1

    // --- Layer 2: Radial mandala / sacred geometry ---
    float angle = atan2(centered.y, centered.x);
    float mandalaFreq = 6.0; // 6-fold symmetry
    float mandala = sin(angle * mandalaFreq + time * 0.3) * 0.5 + 0.5;
    float radialWave = sin(dist * 8.0 - time * 0.5) * 0.5 + 0.5;
    mandala *= radialWave;
    mandala *= smoothstep(1.8, 0.2, dist); // Fade at edges

    // --- Layer 3: Point cloud (scattered bright drifting dots) ---
    float2 pointGrid = uv * 20.0; // Grid density
    float2 cellId = floor(pointGrid);
    float2 cellUv = fract(pointGrid);

    float points = 0.0;
    // Check neighboring cells for smooth appearance
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            float2 neighbor = float2(float(dx), float(dy));
            float2 id = cellId + neighbor;
            float2 randOffset = hash22(id);
            // Animate point positions
            float2 pointPos = neighbor + randOffset + 0.1 * sin(time * 0.3 + randOffset * 6.28);
            float d = length(cellUv - pointPos);
            float brightness = hash21(id + 0.5);
            float pulse = sin(time * (0.5 + brightness) + brightness * 6.28) * 0.5 + 0.5;
            points += smoothstep(0.15, 0.0, d) * brightness * pulse;
        }
    }
    points = min(points, 1.0);

    // --- Compose layers ---
    float3 flowColor = mix(theme, comp, flow * 0.4);
    float3 mandalaColor = theme * 1.2;
    float3 pointColor = mix(theme, float3(1.0), 0.6); // Brighter points

    float3 combined = float3(0.0);
    combined += flowColor * flow * 0.4;
    combined += mandalaColor * mandala * 0.25;
    combined += pointColor * points * 0.35;

    // Edge vignette glow
    float vignette = smoothstep(1.5, 0.3, dist);
    float edgeGlow = smoothstep(0.6, 1.3, dist) * (1.0 - smoothstep(1.3, 1.8, dist));
    combined += theme * edgeGlow * 0.3;
    combined *= vignette;

    // Apply intensity
    float alpha = intensity * length(combined) * 1.5;
    alpha = clamp(alpha, 0.0, intensity * 0.85);

    // Dim the terminal content when overlay is prominent
    float dimFactor = 1.0 - intensity * 0.3;
    half4 dimmedContent = half4(half3(float3(currentColor.rgb) * dimFactor), currentColor.a);

    // Blend shader on top
    half3 overlay = half3(combined);
    half overlayAlpha = half(alpha);
    half3 result = dimmedContent.rgb * (1.0h - overlayAlpha) + overlay * overlayAlpha;

    return half4(result, currentColor.a);
}
