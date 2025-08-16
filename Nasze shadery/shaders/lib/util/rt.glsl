#ifndef RT_GLSL
#define RT_GLSL

// Uses Iris/OF-provided globals: colortex0, depthtex0, gbufferProjection, gbufferProjectionInverse

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
    vec4 homPos = projectionMatrix * vec4(position, 1.0);
    return homPos.xyz / max(homPos.w, 1e-6);
}

vec3 reconstructViewPos(vec2 uv, float depth) {
    vec3 ndc = vec3(uv * 2.0 - 1.0, depth * 2.0 - 1.0);
    return projectAndDivide(gbufferProjectionInverse, ndc);
}

vec3 applySSR(vec3 base, vec3 originView, vec3 viewDir, vec3 n, vec2 uv){
    // Screenspace reflection ray march in view space
    vec3 rdir = reflect(viewDir, normalize(n));
    float steps = mix(16.0, 64.0, clamp(float(RT_QUALITY)/4.0,0.0,1.0));
    float maxDist = mix(8.0, 48.0, clamp(float(RT_QUALITY)/4.0,0.0,1.0));
    float thickness = mix(0.3, 0.05, clamp(float(RT_QUALITY)/4.0,0.0,1.0));
    vec3 pos = originView;
    vec3 stepV = normalize(rdir) * (maxDist / steps);
    vec2 hitUV = uv;
    float hit = 0.0;
    for(int i=0;i<64;i++){
        if(float(i)>=steps) break;
        pos += stepV;
        vec3 ndc = projectAndDivide(gbufferProjection, pos);
        vec2 p = ndc.xy * 0.5 + 0.5;
        if(any(bvec2(p.x<0.0 || p.y<0.0 || p.x>1.0 || p.y>1.0))) break;
    float d = texture2D(depthtex0, p).r;
    if(d >= 0.9999) continue; // sky, skip
        vec3 sceneV = reconstructViewPos(p, d);
        if(abs(sceneV.z - pos.z) < thickness){ hit = 1.0; hitUV = p; break; }
    }
    if(hit>0.5){
    // Sample reflections from the scene color
    vec3 refl = texture2D(colortex0, hitUV).rgb;
    // Reject near-black samples to avoid black overlays
    float lum = dot(refl, vec3(0.2126,0.7152,0.0722));
    if(lum < 0.005) return base;
        float fres = pow(1.0 - max(dot(normalize(-viewDir), normalize(n)), 0.0), 5.0);
        return mix(base, refl, fres);
    }
    return base;
}

vec3 applyOneBounceGI(vec3 viewPos, vec3 n, vec2 uv){
    // cheap diffuse GI in screen space by sampling a small hemisphere
    vec3 accum = vec3(0.0);
    int samples = max(1, PT_SPP);
    float rad = mix(0.5, 0.12, clamp(float(RT_QUALITY)/4.0,0.0,1.0));
    for(int i=0;i<16;i++){
        if(i>=samples) break;
        float a = fract(sin(dot(uv*float(i+1), vec2(12.9898,78.233))) * 43758.5453);
        float b = fract(sin(float(i)*91.7) * 12.37);
        vec2 o = vec2(cos(a*6.2831), sin(a*6.2831)) * (b*rad);
        vec2 sUV = clamp(uv + o, 0.001, 0.999);
        vec3 sCol = texture2D(colortex0, sUV).rgb;
        float sDepth = texture2D(depthtex0, sUV).r;
        vec3 sView = reconstructViewPos(sUV, sDepth);
        vec3 dir = normalize(sView - viewPos);
        float ang = max(dot(normalize(n), dir), 0.0);
        float w = step(sView.z, viewPos.z + 0.05) * ang;
        accum += sCol * w;
    }
    return accum / max(float(samples), 1.0);
}

#endif
