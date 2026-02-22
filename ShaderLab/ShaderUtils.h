#ifndef ShaderUtils_h
#define ShaderUtils_h

#include <metal_stdlib>
using namespace metal;

// ============================================================
// Hash functions
// ============================================================

static inline float2 hash22(float2 p) {
    float3 p3 = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

static inline float hash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// ============================================================
// Simplex 2D noise
// ============================================================

static inline float simplex2d(float2 p) {
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

// ============================================================
// Fractal Brownian Motion
// ============================================================

static inline float fbm(float2 p, float time) {
    float value = 0.0;
    float amplitude = 0.5;
    float2 shift = float2(100.0);
    float2 warp = float2(
        simplex2d(p + float2(0.0, time * 0.3)),
        simplex2d(p + float2(5.2, time * 0.36))
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

static inline float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

static inline float3 rgb2hsv(float3 c) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// ============================================================
// Posterize: map grayscale to analogous color palette
// ============================================================

static inline float3 posterize(float lum, float3 themeRGB, float levels) {
    float3 themeHSV = rgb2hsv(themeRGB);
    float baseHue = themeHSV.x;
    float baseSat = max(themeHSV.y, 0.6);

    float q = floor(lum * levels) / levels;
    float hueOffset = mix(-0.08, 0.08, q);
    float hue = fract(baseHue + hueOffset);

    float sat = baseSat * smoothstep(0.0, 0.3, q) * smoothstep(1.0, 0.7, q);
    sat = max(sat, baseSat * 0.4);

    float val = max(q * 1.3, 0.05);

    return hsv2rgb(float3(hue, sat, val));
}

#endif
