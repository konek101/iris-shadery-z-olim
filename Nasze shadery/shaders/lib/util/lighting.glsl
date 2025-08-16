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

float computeShadowPCF(vec3 worldPos, float bias){
    vec4 lc = shadowProjection * (shadowModelView * vec4(worldPos, 1.0));
    vec3 ndc = lc.xyz / max(lc.w, 1e-6);
    vec2 uv = ndc.xy * 0.5 + 0.5;
    if(uv.x<=0.0||uv.y<=0.0||uv.x>=1.0||uv.y>=1.0) return 1.0;
    float rcv = ndc.z - bias;
    vec2 texel = 1.0 / vec2(textureSize(shadowtex0, 0));
    float rad = SHADOW_SOFTNESS;
    float sum=0.0; int taps=0;
    for(int y=-1;y<=1;++y){
        for(int x=-1;x<=1;++x){
            vec2 o = vec2(x,y) * texel * rad;
            float d = texture2D(shadowtex0, uv+o).r*2.0-1.0;
            sum += (rcv <= d) ? 1.0 : 0.0; taps++;
        }
    }
    return sum / float(taps);
}

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
