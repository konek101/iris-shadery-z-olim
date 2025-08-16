// Ambient Occlusion: simple SSAO-like screen-space occlusion to colortex1
#include "/lib/common.glsl"
#include "/lib/uniforms.glsl"

varying vec2 texcoord;
uniform sampler2D depthtex0;
uniform sampler2D colortex0;

vec3 reconstructViewPos(vec2 uv, float depth){
    vec3 ndc = vec3(uv*2.0-1.0, depth*2.0-1.0);
    vec4 v = gbufferProjectionInverse * vec4(ndc,1.0);
    return v.xyz / max(v.w, 1e-6);
}

void main(){
    vec2 uv = texcoord;
    float depth = texture2D(depthtex0, uv).r;
    vec3 p = reconstructViewPos(uv, depth);
    float occ = 0.0;
    int S = 8;
    float rad = 0.6;
    for(int i=0;i<S;i++){
        float a = float(i) * 6.28318 / float(S);
        vec2 off = vec2(cos(a), sin(a)) * rad / vec2(textureSize(depthtex0,0));
        float d = texture2D(depthtex0, uv+off).r;
        vec3 q = reconstructViewPos(uv+off, d);
        float dd = max(0.0, q.z - p.z);
        occ += step(0.02, dd);
    }
    occ = clamp(1.0 - occ/float(S), 0.0, 1.0);
    /* DRAWBUFFERS:1 */
    gl_FragData[1] = vec4(vec3(occ), 1.0);
}
