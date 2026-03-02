//
//  ZoneSystemShaders.metal
//  Zone System Master - Photo Editor Engine
//  Replicates Ansel Adams darkroom techniques
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Constants

constant float3 LUMINANCE_WEIGHTS = float3(0.299, 0.587, 0.114);
constant float ZONE_RANGE = 10.0; // Ansel Adams Zone System 0-10
constant float GAMMA_CORRECTION = 2.2;

// MARK: - Helper Functions

// Calculate luminance from RGB
float calculateLuminance(float3 color) {
    return dot(color, LUMINANCE_WEIGHTS);
}

// Convert RGB to grayscale with zone system mapping
float rgbToZone(float3 color, float blackPoint, float whitePoint, float gamma) {
    float luminance = calculateLuminance(color);
    // Normalize to zone system
    float normalized = (luminance - blackPoint) / (whitePoint - blackPoint);
    return pow(saturate(normalized), 1.0 / gamma) * ZONE_RANGE;
}

// Zone to luminosity conversion
float zoneToLuminosity(float zone) {
    return zone / ZONE_RANGE;
}

// Smooth step for feathering
float smoothStep(float edge0, float edge1, float x) {
    float t = saturate((x - edge0) / (edge1 - edge0));
    return t * t * (3.0 - 2.0 * t);
}

// Gaussian function for feathering
float gaussian(float x, float sigma) {
    return exp(-(x * x) / (2.0 * sigma * sigma));
}

// MARK: - Luminosity Mask Generation

// Generate luminosity mask based on zone range
kernel void generateLuminosityMask(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float &minZone [[buffer(0)]],
    constant float &maxZone [[buffer(1)]],
    constant float &feather [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 color = inputTexture.read(gid);
    float luminance = calculateLuminance(color.rgb);
    float zone = luminance * ZONE_RANGE;
    
    // Create mask based on zone range with feathering
    float mask = 0.0;
    
    if (feather > 0.0) {
        // Smooth transition with feathering
        float featherAmount = feather * 0.5;
        mask = smoothStep(minZone - featherAmount, minZone + featherAmount, zone) *
               (1.0 - smoothStep(maxZone - featherAmount, maxZone + featherAmount, zone));
    } else {
        // Hard edge mask
        mask = step(minZone, zone) * step(zone, maxZone);
    }
    
    outputTexture.write(float4(mask, mask, mask, 1.0), gid);
}

// Generate zone-specific masks (Lights, Darks, Midtones)
kernel void generateZoneMasks(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> lightsMask [[texture(1)]],
    texture2d<float, access::write> lightsMediumMask [[texture(2)]],
    texture2d<float, access::write> midtonesMask [[texture(3)]],
    texture2d<float, access::write> darksMediumMask [[texture(4)]],
    texture2d<float, access::write> darksMask [[texture(5)]],
    constant float &feather [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    float4 color = inputTexture.read(gid);
    float luminance = calculateLuminance(color.rgb);
    float zone = luminance * ZONE_RANGE;
    
    float f = feather * 0.5;
    
    // Zone VIII-X: Lights (Highlights)
    float lights = smoothStep(7.5 - f, 8.0 + f, zone);
    
    // Zone VI-VII: Lights Medium (Bright midtones)
    float lightsMedium = smoothStep(5.5 - f, 6.0 + f, zone) * (1.0 - smoothStep(7.0 - f, 7.5 + f, zone));
    
    // Zone V: Midtones
    float midtones = smoothStep(4.5 - f, 5.0 + f, zone) * (1.0 - smoothStep(5.5 - f, 6.0 + f, zone));
    
    // Zone III-IV: Darks Medium (Dark midtones)
    float darksMedium = smoothStep(2.5 - f, 3.0 + f, zone) * (1.0 - smoothStep(4.0 - f, 4.5 + f, zone));
    
    // Zone 0-II: Darks (Shadows)
    float darks = 1.0 - smoothStep(1.5 - f, 2.0 + f, zone);
    
    lightsMask.write(float4(lights, lights, lights, 1.0), gid);
    lightsMediumMask.write(float4(lightsMedium, lightsMedium, lightsMedium, 1.0), gid);
    midtonesMask.write(float4(midtones, midtones, midtones, 1.0), gid);
    darksMediumMask.write(float4(darksMedium, darksMedium, darksMedium, 1.0), gid);
    darksMask.write(float4(darks, darks, darks, 1.0), gid);
}

// MARK: - Dodge & Burn

// Apply dodge (lighten) or burn (darken) with brush
kernel void applyDodgeBurn(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::read> brushTexture [[texture(1)]],
    texture2d<float, access::write> outputTexture [[texture(2)]],
    constant float &intensity [[buffer(0)]],
    constant float &exposureTime [[buffer(1)]],
    constant int &mode [[buffer(2)]], // 0 = dodge, 1 = burn
    constant float &gamma [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 color = inputTexture.read(gid);
    float brush = brushTexture.read(gid).r;
    
    if (brush <= 0.0) {
        outputTexture.write(color, gid);
        return;
    }
    
    // Calculate exposure factor based on time (simulates darkroom exposure)
    float exposureFactor = intensity * brush * (1.0 + exposureTime * 0.1);
    
    float3 result;
    if (mode == 0) {
        // Dodge: lighten (reduce density)
        // Simulates holding back exposure in darkroom
        result = pow(color.rgb, float3(1.0 / (1.0 + exposureFactor)));
    } else {
        // Burn: darken (increase density)
        // Simulates additional exposure in darkroom
        result = pow(color.rgb, float3(1.0 + exposureFactor));
    }
    
    // Apply gamma correction
    result = pow(result, float3(gamma));
    
    outputTexture.write(float4(result, color.a), gid);
}

// Generate brush pattern (circular, elliptical, free-form)
kernel void generateBrushPattern(
    texture2d<float, access::write> brushTexture [[texture(0)]],
    constant float2 &center [[buffer(0)]],
    constant float &radius [[buffer(1)]],
    constant float &hardness [[buffer(2)]],
    constant int &shape [[buffer(3)]], // 0 = circle, 1 = ellipse, 2 = free
    constant float2 &ellipseRatio [[buffer(4)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= brushTexture.get_width() || gid.y >= brushTexture.get_height()) {
        return;
    }
    
    float2 uv = float2(gid) / float2(brushTexture.get_width(), brushTexture.get_height());
    float2 pos = uv - center;
    
    float brushValue = 0.0;
    
    if (shape == 0) {
        // Circular brush
        float dist = length(pos);
        float innerRadius = radius * (1.0 - hardness);
        brushValue = 1.0 - smoothStep(innerRadius, radius, dist);
    } else if (shape == 1) {
        // Elliptical brush
        float2 scaledPos = pos / ellipseRatio;
        float dist = length(scaledPos);
        float innerRadius = radius * (1.0 - hardness);
        brushValue = 1.0 - smoothStep(innerRadius, radius, dist);
    }
    
    brushTexture.write(float4(brushValue, brushValue, brushValue, brushValue), gid);
}

// MARK: - Tonal Curves (H&D Curve Simulation)

// Apply characteristic curve (Hurter-Driffield curve simulation)
kernel void applyCharacteristicCurve(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float &blackPoint [[buffer(0)]],
    constant float &whitePoint [[buffer(1)]],
    constant float &gamma [[buffer(2)]],
    constant float &toe [[buffer(3)]],
    constant float &shoulder [[buffer(4)]],
    constant float &contrast [[buffer(5)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 color = inputTexture.read(gid);
    float luminance = calculateLuminance(color.rgb);
    
    // Normalize input
    float normalized = (luminance - blackPoint) / (whitePoint - blackPoint);
    normalized = saturate(normalized);
    
    // Apply toe (shadow compression)
    float toeValue = toe * 0.1;
    if (normalized < toeValue && toeValue > 0.0) {
        normalized = normalized * (normalized / toeValue) * 0.5 + normalized * 0.5;
    }
    
    // Apply shoulder (highlight compression)
    float shoulderValue = 1.0 - shoulder * 0.1;
    if (normalized > shoulderValue && shoulder > 0.0) {
        float excess = (normalized - shoulderValue) / (1.0 - shoulderValue);
        normalized = shoulderValue + excess * (1.0 - excess) * (1.0 - shoulderValue) * 0.5;
    }
    
    // Apply contrast (S-curve)
    if (contrast != 1.0) {
        float midtone = 0.5;
        normalized = midtone + (normalized - midtone) * contrast;
    }
    
    // Apply gamma
    normalized = pow(saturate(normalized), 1.0 / gamma);
    
    // Scale back
    float resultLuminance = normalized * (whitePoint - blackPoint) + blackPoint;
    
    // Preserve color ratios for color images, or apply to grayscale
    float3 result;
    if (luminance > 0.0) {
        result = color.rgb * (resultLuminance / luminance);
    } else {
        result = float3(resultLuminance);
    }
    
    outputTexture.write(float4(saturate(result), color.a), gid);
}

// Apply paper grade curve (simulates multigrade paper)
kernel void applyPaperGradeCurve(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant int &paperGrade [[buffer(0)]], // 0-5 (00, 0, 1, 2, 3, 4, 5)
    constant float &exposure [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 color = inputTexture.read(gid);
    float luminance = calculateLuminance(color.rgb);
    
    // Paper grade contrast curves (simplified)
    // Grade 00: very soft, Grade 5: very hard
    float contrastFactors[6] = {0.3, 0.5, 0.7, 1.0, 1.4, 2.0};
    float contrast = contrastFactors[clamp(paperGrade, 0, 5)];
    
    // Apply grade curve
    float midtone = 0.5;
    float normalized = luminance;
    
    // S-curve based on grade
    normalized = midtone + (normalized - midtone) * contrast;
    normalized = saturate(normalized);
    
    // Apply exposure
    normalized = pow(normalized, 1.0 / exposure);
    
    float3 result = color.rgb * (normalized / max(luminance, 0.001));
    
    outputTexture.write(float4(saturate(result), color.a), gid);
}

// MARK: - Film Grain Simulation

// Hash function for randomness
float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

// 2D noise function
float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Film grain simulation (HP5, Tri-X style)
kernel void applyFilmGrain(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float &intensity [[buffer(0)]],
    constant float &grainSize [[buffer(1)]],
    constant int &filmType [[buffer(2)]], // 0 = HP5, 1 = Tri-X, 2 = Delta, 3 = T-Max
    constant float &pushPull [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 color = inputTexture.read(gid);
    float2 uv = float2(gid) / float2(outputTexture.get_width(), outputTexture.get_height());
    
    // Film-specific parameters
    float baseIntensity = intensity;
    float size = grainSize;
    
    switch (filmType) {
        case 0: // HP5 Plus - moderate grain, good detail
            baseIntensity *= 0.8;
            size *= 1.0;
            break;
        case 1: // Tri-X - classic grain, high contrast
            baseIntensity *= 1.2;
            size *= 1.1;
            break;
        case 2: // Delta - fine grain
            baseIntensity *= 0.5;
            size *= 0.7;
            break;
        case 3: // T-Max - very fine, sharp
            baseIntensity *= 0.4;
            size *= 0.6;
            break;
    }
    
    // Apply push/pull processing effect on grain
    baseIntensity *= (1.0 + pushPull * 0.3);
    
    // Generate grain using multiple octaves
    float grain = 0.0;
    float amplitude = 1.0;
    float frequency = size;
    
    for (int i = 0; i < 4; i++) {
        grain += noise(uv * frequency * 1000.0) * amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    // Normalize grain to -1 to 1 range
    grain = (grain - 0.5) * 2.0;
    
    // Luminance-dependent grain (more visible in midtones)
    float luminance = calculateLuminance(color.rgb);
    float grainVisibility = 1.0 - abs(luminance - 0.5) * 1.5;
    grainVisibility = max(grainVisibility, 0.3);
    
    // Apply grain
    float grainAmount = grain * baseIntensity * grainVisibility;
    float3 result = color.rgb + grainAmount;
    
    outputTexture.write(float4(saturate(result), color.a), gid);
}

// MARK: - Split Grade Printing

// Apply split grade printing (multiple exposures with different filters)
kernel void applySplitGrade(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::read> maskTexture [[texture(1)]],
    texture2d<float, access::write> outputTexture [[texture(2)]],
    constant int &lowGrade [[buffer(0)]],
    constant int &highGrade [[buffer(1)]],
    constant float &lowExposure [[buffer(2)]],
    constant float &highExposure [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 color = inputTexture.read(gid);
    float mask = maskTexture.read(gid).r;
    float luminance = calculateLuminance(color.rgb);
    
    // Low grade (soft) - affects shadows
    float lowContrast = 0.5 + lowGrade * 0.2;
    float lowResult = pow(luminance, 1.0 / lowExposure);
    lowResult = 0.5 + (lowResult - 0.5) * lowContrast;
    
    // High grade (hard) - affects highlights
    float highContrast = 1.0 + highGrade * 0.3;
    float highResult = pow(luminance, 1.0 / highExposure);
    highResult = 0.5 + (highResult - 0.5) * highContrast;
    
    // Blend based on mask and luminance
    float blend = mask * (1.0 - luminance); // More high grade in highlights
    float resultLuminance = mix(lowResult, highResult, blend);
    
    float3 result = color.rgb * (resultLuminance / max(luminance, 0.001));
    
    outputTexture.write(float4(saturate(result), color.a), gid);
}

// MARK: - Vignetting

// Apply vignetting effect (lens/darkroom edge darkening)
kernel void applyVignetting(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float &intensity [[buffer(0)]],
    constant float &radius [[buffer(1)]],
    constant float &feather [[buffer(2)]],
    constant float2 &center [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 color = inputTexture.read(gid);
    float2 uv = float2(gid) / float2(outputTexture.get_width(), outputTexture.get_height());
    
    // Calculate distance from center
    float2 centered = uv - center;
    float dist = length(centered);
    
    // Create vignette mask
    float vignetteRadius = radius;
    float vignetteFeather = feather;
    
    float vignette = 1.0 - smoothStep(vignetteRadius - vignetteFeather, vignetteRadius, dist);
    vignette = pow(vignette, intensity);
    
    // Apply vignette
    float3 result = color.rgb * vignette;
    
    outputTexture.write(float4(result, color.a), gid);
}

// MARK: - Black & White Conversion

// Advanced B&W conversion with color filter simulation
kernel void convertToBlackAndWhite(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float3 &filterColor [[buffer(0)]], // RGB filter weights
    constant float &contrast [[buffer(1)]],
    constant float &brightness [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 color = inputTexture.read(gid);
    
    // Apply color filter weights (simulates lens filters)
    float luminance = dot(color.rgb, filterColor);
    
    // Apply contrast
    luminance = 0.5 + (luminance - 0.5) * contrast;
    
    // Apply brightness
    luminance += brightness;
    
    float3 result = float3(saturate(luminance));
    
    outputTexture.write(float4(result, color.a), gid);
}

// MARK: - Sharpening (Unsharp Mask)

// Unsharp mask for edge enhancement
kernel void applyUnsharpMask(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::read> blurredTexture [[texture(1)]],
    texture2d<float, access::write> outputTexture [[texture(2)]],
    constant float &amount [[buffer(0)]],
    constant float &threshold [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 original = inputTexture.read(gid);
    float4 blurred = blurredTexture.read(gid);
    
    // Calculate difference
    float3 difference = original.rgb - blurred.rgb;
    
    // Apply threshold
    float3 mask = step(threshold, abs(difference));
    
    // Apply unsharp mask
    float3 result = original.rgb + difference * amount * mask;
    
    outputTexture.write(float4(saturate(result), original.a), gid);
}

// MARK: - Layer Blending

// Blend two textures with various blend modes
kernel void blendLayers(
    texture2d<float, access::read> baseTexture [[texture(0)]],
    texture2d<float, access::read> blendTexture [[texture(1)]],
    texture2d<float, access::read> maskTexture [[texture(2)]],
    texture2d<float, access::write> outputTexture [[texture(3)]],
    constant int &blendMode [[buffer(0)]], // 0=normal, 1=multiply, 2=screen, 3=overlay, 4=soft light
    constant float &opacity [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 base = baseTexture.read(gid);
    float4 blend = blendTexture.read(gid);
    float mask = maskTexture.read(gid).r;
    
    float3 result;
    
    switch (blendMode) {
        case 0: // Normal
            result = blend.rgb;
            break;
        case 1: // Multiply
            result = base.rgb * blend.rgb;
            break;
        case 2: // Screen
            result = 1.0 - (1.0 - base.rgb) * (1.0 - blend.rgb);
            break;
        case 3: // Overlay
            result = mix(2.0 * base.rgb * blend.rgb, 
                        1.0 - 2.0 * (1.0 - base.rgb) * (1.0 - blend.rgb),
                        step(0.5, base.rgb));
            break;
        case 4: // Soft Light
            result = mix(2.0 * base.rgb * blend.rgb + base.rgb * base.rgb * (1.0 - 2.0 * blend.rgb),
                        2.0 * base.rgb * (1.0 - blend.rgb) + sqrt(base.rgb) * (2.0 * blend.rgb - 1.0),
                        step(0.5, blend.rgb));
            break;
        default:
            result = blend.rgb;
    }
    
    // Apply mask and opacity
    float effectiveOpacity = opacity * mask;
    result = mix(base.rgb, result, effectiveOpacity);
    
    outputTexture.write(float4(result, base.a), gid);
}

// MARK: - Gaussian Blur (for masks and effects)

// Horizontal pass of separable Gaussian blur
kernel void gaussianBlurHorizontal(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float &sigma [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    int width = inputTexture.get_width();
    int radius = int(ceil(sigma * 3.0));
    
    float4 sum = float4(0.0);
    float weightSum = 0.0;
    
    for (int x = -radius; x <= radius; x++) {
        int sampleX = clamp(int(gid.x) + x, 0, width - 1);
        float weight = gaussian(float(x), sigma);
        sum += inputTexture.read(uint2(sampleX, gid.y)) * weight;
        weightSum += weight;
    }
    
    outputTexture.write(sum / weightSum, gid);
}

// Vertical pass of separable Gaussian blur
kernel void gaussianBlurVertical(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float &sigma [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    int height = inputTexture.get_height();
    int radius = int(ceil(sigma * 3.0));
    
    float4 sum = float4(0.0);
    float weightSum = 0.0;
    
    for (int y = -radius; y <= radius; y++) {
        int sampleY = clamp(int(gid.y) + y, 0, height - 1);
        float weight = gaussian(float(y), sigma);
        sum += inputTexture.read(uint2(gid.x, sampleY)) * weight;
        weightSum += weight;
    }
    
    outputTexture.write(sum / weightSum, gid);
}

// MARK: - Zone Analysis

// Analyze image zones for visualization
kernel void analyzeZones(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    device atomic_uint *zoneHistogram [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    float4 color = inputTexture.read(gid);
    float luminance = calculateLuminance(color.rgb);
    int zone = int(luminance * ZONE_RANGE);
    zone = clamp(zone, 0, 10);
    
    // Update histogram (atomic)
    atomic_fetch_add_explicit(&zoneHistogram[zone], 1, memory_order_relaxed);
    
    // Create zone visualization
    float3 zoneColors[11] = {
        float3(0.0, 0.0, 0.0),       // Zone 0 - Pure black
        float3(0.05, 0.05, 0.05),    // Zone I
        float3(0.1, 0.1, 0.1),       // Zone II
        float3(0.2, 0.2, 0.2),       // Zone III
        float3(0.3, 0.3, 0.3),       // Zone IV
        float3(0.5, 0.5, 0.5),       // Zone V - 18% gray
        float3(0.65, 0.65, 0.65),    // Zone VI
        float3(0.8, 0.8, 0.8),       // Zone VII
        float3(0.9, 0.9, 0.9),       // Zone VIII
        float3(0.95, 0.95, 0.95),    // Zone IX
        float3(1.0, 1.0, 1.0)        // Zone X - Pure white
    };
    
    float3 zoneColor = zoneColors[zone];
    
    // Blend with original based on visualization mode
    float blend = 0.5;
    float3 result = mix(color.rgb, zoneColor, blend);
    
    outputTexture.write(float4(result, color.a), gid);
}
