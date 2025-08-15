// Temporal accumulation and simple denoiser for RT/PT-lite
#include "/lib/common.glsl"

varying vec2 texcoord;

uniform sampler2D colortex0;   // current color
uniform sampler2D colortex3;   // history color
uniform sampler2D depthtex0;   // current depth

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;

vec3 projectAndDivide(mat4 M, vec3 p){
    vec4 h = M * vec4(p,1.0);
    return h.xyz / max(h.w, 1e-6);
}

vec3 reconstructViewPos(vec2 uv, float depth){
    vec3 ndc = vec3(uv*2.0-1.0, depth*2.0-1.0);
    return projectAndDivide(gbufferProjectionInverse, ndc);
}

vec2 reprojectPrevUV(vec2 uv, float depth){
    // current view -> world -> prev view -> prev ndc -> prev uv
    vec3 viewPos = reconstructViewPos(uv, depth);
    vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos,1.0)).xyz;
    vec3 prevView = (gbufferPreviousModelView * vec4(worldPos,1.0)).xyz;
    vec3 prevNDC = projectAndDivide(gbufferPreviousProjection, prevView);
    return prevNDC.xy * 0.5 + 0.5;
}

vec3 neighborhoodClamp(vec3 c, vec2 uv, vec2 texel, float depth){
    // simple 3x3 clamp to reduce fireflies
    vec3 cmin = c, cmax = c;
    for(int y=-1;y<=1;y++){
        for(int x=-1;x<=1;x++){
            vec2 o = vec2(x,y)*texel;
            float dz = abs(texture2D(depthtex0, uv+o).r - depth);
            if(dz > 0.01) continue; // avoid disocclusion
            vec3 s = texture2D(colortex0, uv+o).rgb;
            cmin = min(cmin, s);
            cmax = max(cmax, s);
        }
    }
    return clamp(c, cmin, cmax);
}

void main(){
    vec2 uv = texcoord;
    vec2 texel = 1.0 / vec2(textureSize(colortex0, 0));

    vec3 curr = texture2D(colortex0, uv).rgb;
    float depth = texture2D(depthtex0, uv).r;

    #ifdef PT_CLAMP_FIREFLIES
        curr = neighborhoodClamp(curr, uv, texel, depth);
    #endif

    vec2 prevUV = reprojectPrevUV(uv, depth);
    bool valid = prevUV.x > 0.0 && prevUV.y > 0.0 && prevUV.x < 1.0 && prevUV.y < 1.0;
    vec3 prev = valid ? texture2D(colortex3, prevUV).rgb : curr;

    // Disocclusion check: reject history if big color or depth change
    float prevDepth = valid ? texture2D(depthtex0, prevUV).r : depth; // fallback
    float dz = abs(prevDepth - depth);
    float reject = step(0.0025, dz);

    float w = mix(0.9, 0.0, reject);
    vec3 accum = mix(curr, prev, w);

    /* DRAWBUFFERS:03 */
    gl_FragData[0] = vec4(accum, 1.0);
    gl_FragData[3] = vec4(accum, 1.0);
}
