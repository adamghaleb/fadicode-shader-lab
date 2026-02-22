#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// =============================================================================
// Inferno Shader Collection (from github.com/twostraws/Inferno)
// Curated selection of visually interesting shaders for the Shader Lab.
// All functions are [[ stitchable ]] for SwiftUI integration.
// =============================================================================

// MARK: - Passthrough (no-op fallback)

[[ stitchable ]] half4 passthrough(float2 position, half4 color) {
    return color;
}

// MARK: - Generation: Light Grid

[[ stitchable ]] half4 lightGrid(float2 position, half4 color, float2 size, float time, float density, float speed, float groupSize, float brightness) {
    half aspectRatio = size.x / size.y;
    half2 uv = half2(position / size);
    uv.x *= aspectRatio;

    if (color.a > 0.0h) {
        half2 point = uv * density;
        half2 nonRepeating = half2(12.9898h, 78.233h);
        half2 groupNumber = floor(point);
        half sum = dot(groupNumber, nonRepeating);
        half sine = sin(sum);
        float hugeNumber = float(sine) * 43758.5453;
        half variance = (0.5h * sin(time + hugeNumber)) + 0.5h;
        half acceleratedVariance = speed * variance;

        half3 baseColor = half3(3.0h, 1.5h, 0.0h);
        half3 variedColor = baseColor + acceleratedVariance + time;
        half3 variedColorSine = sin(variedColor);
        half3 newColor = (0.5h * variedColorSine) + 0.5h;

        half2 adjustedGroupSize = M_PI_H * 2.0h * groupSize * (point - (0.25h / groupSize));
        half2 groupSine = (0.5h * sin(adjustedGroupSize)) + 0.5h;
        half2 pulse = smoothstep(0.0h, 1.0h, groupSine);

        return half4(newColor * pulse.x * pulse.y * brightness, 1.0h) * color.a;
    } else {
        return color;
    }
}

// MARK: - Generation: Sinebow

[[ stitchable ]] half4 sinebow(float2 position, half4 color, float2 size, float time) {
    half aspectRatio = size.x / size.y;
    half2 uv = half2(position / size.x) * 2.0h - 1.0h;
    uv.x /= aspectRatio;

    half wave = sin(uv.x + time);
    wave *= wave * 50.0h;

    half3 waveColor = half3(0.0h);

    for (half i = 0.0h; i < 10.0h; i++) {
        half luma = abs(1.0h / (100.0h * uv.y + wave));
        half y = sin(uv.x * sin(time) + i * 0.2h + time);
        uv.y += 0.05h * y;

        half3 rainbow = half3(
            sin(i * 0.3h + time) * 0.5h + 0.5h,
            sin(i * 0.3h + 2.0h + sin(time * 0.3h) * 2.0h) * 0.5h + 0.5h,
            sin(i * 0.3h + 4.0h) * 0.5h + 0.5h
        );

        waveColor += rainbow * luma;
    }

    return half4(waveColor, 1.0h) * color.a;
}

// MARK: - Transformation: Animated Gradient Fill

[[ stitchable ]] half4 animatedGradientFill(float2 position, half4 color, float2 size, float time) {
    half2 uv = half2(position / size);
    half2 rp = uv * 2.0h - 1.0h;
    float wrappedTime = fmod(time, 2.0 * 3.1415927);
    half angle = atan2(rp.y, rp.x) + wrappedTime;
    return half4(abs(sin(angle)), abs(sin(angle + 2.0h)), abs(sin(angle + 4.0h)), 1.0h) * color.a;
}

// MARK: - Transformation: Circle Wave

[[ stitchable ]] half4 circleWave(float2 position, half4 color, float2 size, float time, float brightness, float speed, float strength, float density, float2 center, half4 circleColor) {
    if (color.a > 0.0h) {
        half2 uv = half2(position / size);
        half2 delta = uv - half2(center);
        half aspectRatio = size.x / size.y;
        delta.x *= aspectRatio;
        half pixelDistance = sqrt((delta.x * delta.x) + (delta.y * delta.y));
        half waveSpeed = -(time * speed * 10.0h);
        half3 newBrightness = half3(brightness);
        half3 gradientColor = half3(circleColor.r, circleColor.g, circleColor.b) * newBrightness;
        half colorStrength = pow(1.0h - pixelDistance, 3.0h);
        colorStrength *= strength;
        half waveDensity = density * pixelDistance;
        half cosine = cos(waveSpeed + waveDensity);
        half cosineAdjustment = (0.5h * cosine) + 0.5h;
        half luma = colorStrength * (strength + cosineAdjustment);
        luma *= 1.0h - (pixelDistance * 2.0h);
        luma = max(0.0h, luma);
        half4 finalColor = half4(gradientColor * luma, luma);
        return finalColor * color.a;
    } else {
        return color;
    }
}

// MARK: - Transformation: Chromatic Aberration (Color Planes)

[[ stitchable ]] half4 colorPlanes(float2 position, SwiftUI::Layer layer, float2 offset) {
    float2 red = position - (offset * 2.0);
    float2 blue = position - offset;
    half4 color = layer.sample(position);
    color.r = layer.sample(red).r;
    color.b = layer.sample(blue).b;
    return color * color.a;
}

// MARK: - Transformation: Emboss

[[ stitchable ]] half4 emboss(float2 position, SwiftUI::Layer layer, float strength) {
    half4 currentColor = layer.sample(position);
    half4 newColor = currentColor;
    newColor += layer.sample(position + 1.0) * strength;
    newColor -= layer.sample(position - 1.0) * strength;
    return half4(newColor) * currentColor.a;
}

// MARK: - Transformation: Infrared

[[ stitchable ]] half4 infrared(float2 position, half4 color) {
    if (color.a > 0) {
        half3 cold = half3(0.0h, 0.0h, 1.0h);
        half3 medium = half3(1.0h, 1.0h, 0.0h);
        half3 hot = half3(1.0h, 0.0h, 0.0h);
        half3 grayValues = half3(0.2125h, 0.7154h, 0.0721h);
        half luma = dot(color.rgb, grayValues);
        half3 newColor;
        if (luma < 0.5h) {
            newColor = mix(cold, medium, luma / 0.5h);
        } else {
            newColor = mix(medium, hot, (luma - 0.5h) / 0.5h);
        }
        return half4(newColor, 1.0h) * color.a;
    } else {
        return color;
    }
}

// MARK: - Transformation: Interlace (CRT Scanlines)

[[ stitchable ]] half4 interlace(float2 position, half4 color, float width, half4 replacement, float strength) {
    if (color.a > 0.0h) {
        if (fmod(position.y, width * 2.0) <= width) {
            return color;
        } else {
            return half4(mix(color, replacement, strength)) * color.a;
        }
    } else {
        return color;
    }
}

// MARK: - Transformation: Checkerboard

[[ stitchable ]] half4 checkerboard(float2 position, half4 color, half4 replacement, float size) {
    uint2 posInChecks = uint2(position.x / size, position.y / size);
    bool isColor = (posInChecks.x ^ posInChecks.y) & 1;
    return isColor ? replacement * color.a : color;
}

// MARK: - Transformation: Rainbow Noise

float rainbowRandom(float offset, float2 position, float time) {
    float2 nonRepeating = float2(12.9898 * time, 78.233 * time);
    float sum = dot(position, nonRepeating);
    float sine = sin(sum);
    float hugeNumber = sine * 43758.5453 * offset;
    return fract(hugeNumber);
}

[[ stitchable ]] half4 rainbowNoise(float2 position, half4 color, float time) {
    if (color.a > 0.0h) {
        return half4(
            rainbowRandom(1.23, position, time),
            rainbowRandom(5.67, position, time),
            rainbowRandom(8.90, position, time),
            1.0h
        ) * color.a;
    } else {
        return color;
    }
}

// MARK: - Transformation: White Noise

float whiteRandom(float offset, float2 position, float time) {
    float2 nonRepeating = float2(12.9898 * time, 78.233 * time);
    float sum = dot(position, nonRepeating);
    float sine = sin(sum);
    float hugeNumber = sine * 43758.5453 * offset;
    return fract(hugeNumber);
}

[[ stitchable ]] half4 whiteNoise(float2 position, half4 color, float time) {
    if (color.a > 0.0h) {
        return half4(half3(whiteRandom(1.0, position, time)), 1.0h) * color.a;
    } else {
        return color;
    }
}

// MARK: - Transformation: Shimmer

half3 rgbToHSL(half3 rgb) {
    half minC = min3(rgb.r, rgb.g, rgb.b);
    half maxC = max3(rgb.r, rgb.g, rgb.b);
    half delta = maxC - minC;
    half3 hsl = half3(0.0h, 0.0h, 0.5h * (maxC + minC));
    if (delta > 0.0h) {
        if (maxC == rgb.r) {
            hsl[0] = fmod((rgb.g - rgb.b) / delta, 6.0h);
        } else if (maxC == rgb.g) {
            hsl[0] = (rgb.b - rgb.r) / delta + 2.0h;
        } else {
            hsl[0] = (rgb.r - rgb.g) / delta + 4.0h;
        }
        hsl[0] /= 6.0h;
        if (hsl[2] > 0.0h && hsl[2] < 1.0h) {
            hsl[1] = delta / (1.0h - abs(2.0h * hsl[2] - 1.0h));
        } else {
            hsl[1] = 0.0h;
        }
    }
    return hsl;
}

half3 hslToRGB(half3 hsl) {
    half c = (1.0h - abs(2.0h * hsl[2] - 1.0h)) * hsl[1];
    half h = hsl[0] * 6.0h;
    half x = c * (1.0h - abs(fmod(h, 2.0h) - 1.0h));
    half3 rgb = half3(0.0h, 0.0h, 0.0h);
    if (h < 1.0h) { rgb = half3(c, x, 0.0h); }
    else if (h < 2.0h) { rgb = half3(x, c, 0.0h); }
    else if (h < 3.0h) { rgb = half3(0.0h, c, x); }
    else if (h < 4.0h) { rgb = half3(0.0h, x, c); }
    else if (h < 5.0h) { rgb = half3(x, 0.0h, c); }
    else { rgb = half3(c, 0.0h, x); }
    half m = hsl[2] - 0.5h * c;
    return rgb + m;
}

[[ stitchable ]] half4 shimmer(float2 position, half4 color, float2 size, float time, float animationDuration, float gradientWidth, float maxLightness) {
    if (color.a == 0.0h) { return color; }
    float loopedProgress = fmod(time, float(animationDuration));
    half progress = loopedProgress / animationDuration;
    half2 uv = half2(position / size);
    half minU = 0.0h - gradientWidth;
    half maxU = 1.0h + gradientWidth;
    half start = minU + maxU * progress + gradientWidth * uv.y;
    half end = start + gradientWidth;
    if (uv.x > start && uv.x < end) {
        half gradient = smoothstep(start, end, uv.x);
        half intensity = sin(gradient * M_PI_H);
        half3 hsl = rgbToHSL(color.rgb);
        hsl[2] = hsl[2] + half(maxLightness * (maxLightness > 0.0h ? 1 - hsl[2] : hsl[2])) * intensity;
        color.rgb = hslToRGB(hsl);
    }
    return color;
}

// MARK: - Distortion: Water

[[ stitchable ]] float2 water(float2 position, float2 size, float time, float speed, float strength, float frequency) {
    float2 uv = position / size;
    float adjustedSpeed = time * speed * 0.05f;
    float adjustedStrength = strength / 100.0f;
    const float TWO_PI = 6.28318530718f;
    float phase = fmod(adjustedSpeed * frequency, TWO_PI);
    float argX = frequency * uv.x + phase;
    float argY = frequency * uv.y + phase;
    uv.x += fast::sin(argX) * adjustedStrength;
    uv.y += fast::cos(argY) * adjustedStrength;
    return uv * size;
}

// MARK: - Distortion: Wave

[[ stitchable ]] float2 wave(float2 position, float time, float speed, float smoothing, float strength) {
    position.y += sin(time * speed + position.x / smoothing) * strength;
    return position;
}

// MARK: - Distortion: Relative Wave

[[ stitchable ]] float2 relativeWave(float2 position, float2 size, float time, float speed, float smoothing, float strength) {
    half2 uv = half2(position / size);
    half offset = sin(time * speed + position.x / smoothing);
    position.y += offset * uv.x * strength;
    return position;
}

// MARK: - Transition: Swirl

[[stitchable]] half4 swirl(float2 position, SwiftUI::Layer layer, float2 size, float amount, float radius) {
    half2 uv = half2(position / size);
    uv -= 0.5h;
    half distanceFromCenter = length(uv);
    if (distanceFromCenter < radius) {
        half swirlStrength = (radius - distanceFromCenter) / radius;
        half swirlAmount;
        if (amount <= 0.5) {
            swirlAmount = mix(0.0h, 1.0h, half(amount) / 0.5h);
        } else {
            swirlAmount = mix(1.0h, 0.0h, (half(amount) - 0.5h) / 0.5h);
        }
        half swirlAngle = swirlStrength * swirlStrength * swirlAmount * 8.0h * M_PI_H;
        half sinAngle = sin(swirlAngle);
        half cosAngle = cos(swirlAngle);
        uv = half2(dot(uv, half2(cosAngle, -sinAngle)), dot(uv, half2(sinAngle, cosAngle)));
    }
    uv += 0.5h;
    return mix(layer.sample(float2(uv) * size), 0.0h, amount);
}

// MARK: - Transition: Pixellate

[[stitchable]] half4 pixellateTransition(float2 position, SwiftUI::Layer layer, float2 size, float amount, float squares, float steps) {
    half2 uv = half2(position / size);
    half direction = min(amount, 1.0 - amount);
    half steppedProgress = ceil(direction * steps) / steps;
    half2 squareSize = 2.0h * steppedProgress / half2(squares);
    half2 newPosition;
    if (steppedProgress == 0.0h) {
        newPosition = uv;
    } else {
        newPosition = (floor(uv / squareSize) + 0.5h) * squareSize;
    }
    return mix(layer.sample(float2(newPosition) * size), 0.0h, amount);
}
