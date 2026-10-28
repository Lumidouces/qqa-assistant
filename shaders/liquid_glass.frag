#version 460 core
// 液态玻璃折射着色器 —— 移植自 SleepDown-Schedule 的 Kyant Backdrop 2.0
// 上游 AGSL 源：third-party/kyant-backdrop/.../internal/Shaders.kt（Apache-2.0）
// SDF 方程、符号约定、lens 位移方向与高光/内阴影公式保持一致，
// 仅把 AGSL 语法换成 Flutter runtime_effect GLSL，并额外拆出面板尺寸/内缩
// 以便在 BackdropFilter 的纹理空间里精确定位圆角。
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;              // [0,1]  引擎注入：滤镜输入纹理尺寸
uniform vec2 uPanelSize;         // [2,3]  面板自身尺寸（px）
uniform vec2 uInset;             // [4,5]  面板在纹理内的左上偏移（px）
uniform vec4 uCornerRadii;       // [6..9] TL, TR, BR, BL（px）
uniform float uRefractionHeight; // [10] lens 高度（px）
uniform float uRefractionAmount; // [11] lens 位移量（px，正值）
uniform float uDepthEffect;      // [12] 0/1
uniform float uDispersion;       // [13] 0/1 色散
uniform float uHighlightAngle;   // [14] 弧度
uniform float uHighlightFalloff; // [15]
uniform float uHighlightAlpha;   // [16]
uniform vec4 uHighlightColor;    // [17..20]
uniform vec4 uSurfaceColor;      // [21..24]
uniform float uInnerShadowAlpha; // [25]
uniform float uInnerShadowRadius;// [26] px
uniform float uVibrancy;         // [27] 0/1 提亮饱和度
uniform sampler2D uTexture;

out vec4 fragColor;

float radiusAt(vec2 coord, vec4 radii) {
    if (coord.x >= 0.0) {
        if (coord.y <= 0.0) return radii.y;
        else return radii.z;
    } else {
        if (coord.y <= 0.0) return radii.x;
        else return radii.w;
    }
}

float sdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    float outside = length(max(cornerCoord, vec2(0.0))) - radius;
    float inside = min(max(cornerCoord.x, cornerCoord.y), 0.0);
    return outside + inside;
}

vec2 gradSdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    if (cornerCoord.x >= 0.0 || cornerCoord.y >= 0.0) {
        return sign(coord) * normalize(max(cornerCoord, vec2(0.0)));
    } else {
        float gradX = step(cornerCoord.y, cornerCoord.x);
        return sign(coord) * vec2(gradX, 1.0 - gradX);
    }
}

float circleMap(float x) {
    return 1.0 - sqrt(max(0.0, 1.0 - x * x));
}

vec4 sampleAt(vec2 coord) {
    vec2 uv = coord / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
    uv.y = 1.0 - uv.y;
#endif
    return texture(uTexture, clamp(uv, vec2(0.0), vec2(1.0)));
}

void main() {
    vec2 local = FlutterFragCoord().xy - uInset;   // 面板局部坐标
    vec2 halfSize = uPanelSize * 0.5;
    vec2 centeredCoord = local - halfSize;
    float radius = radiusAt(centeredCoord, uCornerRadii);

    float sd = sdRoundedRect(centeredCoord, halfSize, radius);

    vec4 color = sampleAt(FlutterFragCoord().xy);

    // ---- lens 折射（上游 RoundedRectRefractionShaderString 同式） ----
    if (uRefractionHeight > 0.0 && uRefractionAmount > 0.0 && -sd < uRefractionHeight) {
        float sdIn = min(sd, 0.0);
        float t = 1.0 + sdIn / uRefractionHeight;      // 1 - (-sd)/h
        float d = -circleMap(t) * uRefractionAmount;   // 上游 refractionAmount 取负后同向
        float gradRadius = min(radius * 1.5, min(halfSize.x, halfSize.y));
        vec2 grad = normalize(
            gradSdRoundedRect(centeredCoord, halfSize, gradRadius) +
            uDepthEffect * normalize(centeredCoord + vec2(1e-5))
        );
        vec2 refracted = FlutterFragCoord().xy + d * grad;

        if (uDispersion > 0.5) {
            float dispersionIntensity =
                (centeredCoord.x * centeredCoord.y) / max(halfSize.x * halfSize.y, 1e-4);
            vec2 dispersed = d * grad * dispersionIntensity;
            vec4 acc = vec4(0.0);
            vec4 s;

            s = sampleAt(refracted + dispersed);
            acc.r += s.r / 3.5; acc.a += s.a / 7.0;
            s = sampleAt(refracted + dispersed * (2.0 / 3.0));
            acc.r += s.r / 3.5; acc.g += s.g / 7.0; acc.a += s.a / 7.0;
            s = sampleAt(refracted + dispersed * (1.0 / 3.0));
            acc.r += s.r / 3.5; acc.g += s.g / 3.5; acc.a += s.a / 7.0;
            s = sampleAt(refracted);
            acc.g += s.g / 3.5; acc.a += s.a / 7.0;
            s = sampleAt(refracted - dispersed * (1.0 / 3.0));
            acc.g += s.g / 3.5; acc.b += s.b / 3.0; acc.a += s.a / 7.0;
            s = sampleAt(refracted - dispersed * (2.0 / 3.0));
            acc.b += s.b / 3.0; acc.a += s.a / 7.0;
            s = sampleAt(refracted - dispersed);
            acc.r += s.r / 7.0; acc.b += s.b / 3.0; acc.a += s.a / 7.0;

            color = vec4(acc.rgb, clamp(acc.a, 0.0, 1.0));
        } else {
            color = sampleAt(refracted);
        }
    }

    // ---- vibrancy：轻微提饱和，贴近玻璃后的真实观感 ----
    if (uVibrancy > 0.5) {
        float luma = dot(color.rgb, vec3(0.299, 0.587, 0.114));
        color.rgb = clamp(mix(vec3(luma), color.rgb, 1.16), 0.0, 1.0);
    }

    // ---- 表面着色（drawRect(surfaceColor) 的 src-over 等价） ----
    color.rgb = color.rgb * (1.0 - uSurfaceColor.a) + uSurfaceColor.rgb * uSurfaceColor.a;

    // ---- 边缘高光（DefaultHighlightShaderString 同式） ----
    if (uHighlightAlpha > 0.0) {
        float gradRadius = min(radius * 1.5, min(halfSize.x, halfSize.y));
        vec2 grad = gradSdRoundedRect(centeredCoord, halfSize, gradRadius);
        vec2 normal = vec2(cos(uHighlightAngle), sin(uHighlightAngle));
        float dh = dot(grad, normal);
        float intensity = pow(abs(dh), max(uHighlightFalloff, 0.01));
        color.rgb += uHighlightColor.rgb * uHighlightColor.a * intensity * uHighlightAlpha;
    }

    // ---- 内阴影：8 向 SDF 采样近似 GlassInnerShadowFrame ----
    if (uInnerShadowAlpha > 0.0 && uInnerShadowRadius > 0.0) {
        float occ = 0.0;
        for (int i = 0; i < 8; i++) {
            float a = 6.2831853 * float(i) / 8.0;
            vec2 o = vec2(cos(a), sin(a)) * uInnerShadowRadius;
            float s2 = sdRoundedRect(centeredCoord + o, halfSize, radius);
            occ = max(occ, -s2);
        }
        float inner = clamp(occ / uInnerShadowRadius, 0.0, 1.0);
        color.rgb *= (1.0 - inner * uInnerShadowAlpha);
    }

    fragColor = vec4(clamp(color.rgb, 0.0, 1.0), 1.0);
}
