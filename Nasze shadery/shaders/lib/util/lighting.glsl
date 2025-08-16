#ifndef LIGHTING_UTIL_GLSL
#define LIGHTING_UTIL_GLSL

#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"

vec3 kelvinToRGB(float k){
    float t = k / 100.0;
    float r = 0.0, g = 0.0, b = 0.0;
    if(t <= 66.0){
        r = 1.0;
        g = clamp(0.3900815788 * log(t) - 0.6318414438, 0.0, 1.0);
        b = t <= 19.0 ? 0.0 : clamp(0.5432067891 * log(t - 10.0) - 1.1962540891, 0.0, 1.0);
    } else {
        r = clamp(1.2929361861 * pow(t - 60.0, -0.1332047592), 0.0, 1.0);
        g = clamp(1.1298908609 * pow(t - 60.0, -0.0755148492), 0.0, 1.0);
        b = 1.0;
    }
    return vec3(r,g,b);
}

vec3 getDirectionalLightDir(){
    vec3 s = normalize(sunPosition);
    vec3 m = normalize(moonPosition);
    return (s.y > 0.05) ? s : m;
}

// Time-of-day light color and intensity from elevation
void getLightColorIntensity(out vec3 Lcol, out float Lint){
    vec3 L = normalize(getDirectionalLightDir());
    float elev = clamp(L.y, -1.0, 1.0);
    // Map elevation to Kelvin: warm sunrise/sunset to neutral midday; cooler at night (moon)
    float kDay = mix(3800.0, 6500.0, smoothstep(0.0, 0.6, elev));
    float kNight = 7000.0; // moonlight cool tint
    float dayFactor = smoothstep(0.02, 0.2, elev); // fade in with elevation
    float nightFactor = 1.0 - dayFactor;
    vec3 dayCol = kelvinToRGB(kDay);
    vec3 nightCol = kelvinToRGB(kNight) * 0.6;
    Lcol = mix(nightCol, dayCol, dayFactor);
    // Intensity stronger near midday, weaker at horizon/night
    float baseI = clamp((elev + 0.1), 0.0, 1.0);
    Lint = mix(0.12, 1.0, baseI);
}

// Percentage-closer filtering with distance-based kernel (PCF); upgraded to PCSS if enabled
float shadowDepthAt(vec2 uv){
    return texture2D(shadowtex0, uv).r; // 0..1
}

float computeShadowPCF(vec3 worldPos, float bias){
    vec4 lc = shadowProjection * (shadowModelView * vec4(worldPos, 1.0));
    vec3 ndc = lc.xyz / max(lc.w, 1e-6);
    vec2 uv = ndc.xy * 0.5 + 0.5;
    if(uv.x<=0.0||uv.y<=0.0||uv.x>=1.0||uv.y>=1.0) return 1.0;
    float rcv = ndc.z * 0.5 + 0.5 - bias;
    vec2 texel = 1.0 / vec2(textureSize(shadowtex0, 0));
    // Increase softness with receiver distance for pseudo-cascade effect
    float rad = SHADOW_SOFTNESS * (1.0 + abs(ndc.z) * 1.5);
    float sum=0.0; int taps=0;
    for(int y=-1;y<=1;++y){
        for(int x=-1;x<=1;++x){
            vec2 o = vec2(x,y) * texel * rad;
            float d = shadowDepthAt(uv+o);
            sum += (rcv <= d) ? 1.0 : 0.0; taps++;
        }
    }
    return sum / float(taps);
}

#if SHADOW_PCSS_ENABLE
// Simple PCSS: blocker search in a small kernel to estimate penumbra
float computeShadowPCSS(vec3 worldPos, float bias){
    vec4 lc = shadowProjection * (shadowModelView * vec4(worldPos, 1.0));
    vec3 ndc = lc.xyz / max(lc.w, 1e-6);
    vec2 uv = ndc.xy * 0.5 + 0.5;
    if(uv.x<=0.0||uv.y<=0.0||uv.x>=1.0||uv.y>=1.0) return 1.0;
    float rcv = ndc.z * 0.5 + 0.5 - bias;
    vec2 texel = 1.0 / vec2(textureSize(shadowtex0, 0));
    // Blocker search (small kernel)
    float blockers=0.0; int bcount=0;
    for(int y=-2;y<=2;++y){
        for(int x=-2;x<=2;++x){
            vec2 o = vec2(x,y) * texel * 1.0;
            float d = shadowDepthAt(uv+o);
            if(d < rcv){ blockers += d; bcount++; }
        }
    }
    float avgBlocker = (bcount>0) ? (blockers/float(bcount)) : rcv;
    // Penumbra proportional to receiver - blocker distance
    float pen = clamp((rcv - avgBlocker) * 80.0, 0.5, 4.0);
    pen *= (1.0 + abs(ndc.z) * 1.2) * SHADOW_SOFTNESS;
    // PCF with variable kernel
    float sum=0.0; int taps=0;
    for(int y=-PCSS_SAMPLES; y<=PCSS_SAMPLES; ++y){
        for(int x=-PCSS_SAMPLES; x<=PCSS_SAMPLES; ++x){
            vec2 o = vec2(x,y) * texel * pen;
            float d = shadowDepthAt(uv+o);
            sum += (rcv <= d) ? 1.0 : 0.0; taps++;
        }
    }
    return sum / float(taps);
}
#endif

// --- Volumetric Clouds: simple FBM value-noise ---
float hash12(vec2 p){
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise2(vec2 p){
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    vec2 u = f*f*(3.0-2.0*f);
    return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
}

float fbm(vec2 p){
    float v=0.0; float a=0.5; vec2 s=p;
    for(int i=0;i<5;i++){ v += a * noise2(s); s *= 2.02; a *= 0.5; }
    return v;
}

float cloudDensityAt(vec3 worldPos){
    #if CLOUDS_ENABLE
        // Project to cloud layer height
        vec2 uv = worldPos.xz * 0.003; // scale
        uv += vec2(CLOUD_SPEED, -CLOUD_SPEED) * frameTimeCounter;
        float base = fbm(uv);
        if(CLOUD_DETAIL==1){ base = mix(base, fbm(uv*2.7), 0.35); }
        // Coverage/remapping
        float cov = CLOUD_COVERAGE; // 0..1 desired clear sky fraction
        float d = smoothstep(cov, 1.0, base) * CLOUD_DENSITY;
        return clamp(d, 0.0, 1.0);
    #else
        return 0.0;
    #endif
}

// Cast from worldPos toward light to cloud layer, sample density for shadowing
float cloudShadowAt(vec3 worldPos){
    #if CLOUDS_ENABLE
        vec3 L = normalize(getDirectionalLightDir());
        float ly = max(abs(L.y), 1e-3);
        float t = (CLOUD_HEIGHT - worldPos.y) / L.y;
        if(t < 0.0) return 1.0; // below or sun below layer
        vec3 cpos = worldPos + L * t;
        float cd = cloudDensityAt(cpos);
        // convert density to transmittance (Beer-Lambert approx)
        float trans = exp(-cd * 1.8);
        return clamp(trans, 0.3, 1.0);
    #else
        return 1.0;
    #endif
}

#endif

// --- Water Caustics (procedural, no textures required) ---
#ifndef CAUSTICS_UTIL_GLSL
#define CAUSTICS_UTIL_GLSL

float causticsPattern(vec2 p){
    // Two scrolling bands to imitate interference
    float t = frameTimeCounter;
    float a = sin(p.x*7.1 + t*1.7) * cos(p.y*6.3 - t*1.3);
    float b = sin((p.x+p.y)*5.7 - t*0.9) * cos((p.x-p.y)*6.9 + t*1.1);
    float v = a*b;
    v = smoothstep(0.2, 0.8, v*0.5+0.5);
    return v;
}

float causticsAt(vec3 worldPos){
    #if CAUSTICS_ENABLE
        vec2 p = worldPos.xz * 0.35;
        float v = causticsPattern(p);
        return v;
    #else
        return 0.0;
    #endif
}

#endif
