// Bloom (outputs blurred bright pass to colortex3)
#include "/lib/common.glsl"

varying vec2 texcoord;
uniform sampler2D colortex0;

vec3 brightPass(vec3 c, float threshold){
    float l = dot(c, vec3(0.2126,0.7152,0.0722));
    float w = smoothstep(threshold, 1.5*threshold, l);
    return c * w;
}

vec3 blur9(vec2 uv, vec2 texel, float r){
    vec3 acc = vec3(0.0);
    float wsum = 0.0;
    float w[5]; w[0]=0.227027; w[1]=0.1945946; w[2]=0.1216216; w[3]=0.054054; w[4]=0.016216;
    for(int i=-4;i<=4;i++){
        float wi = w[abs(i)];
        vec2 off = vec2(i,0)*texel*r;
        vec3 s = texture2D(colortex0, uv+off).rgb;
        acc += s*wi; wsum += wi;
    }
    vec3 h = acc / max(wsum,1e-4);
    acc = vec3(0.0); wsum=0.0;
    for(int i=-4;i<=4;i++){
        float wi = w[abs(i)];
        vec2 off = vec2(0,i)*texel*r;
        vec3 s = texture2D(colortex0, uv+off).rgb;
        acc += s*wi; wsum += wi;
    }
    vec3 v = acc / max(wsum,1e-4);
    return (h+v)*0.5;
}

void main(){
    vec2 texel = 1.0 / vec2(textureSize(colortex0, 0));
    vec3 src = texture2D(colortex0, texcoord).rgb;
    vec3 outBloom = vec3(0.0);
    #if BLOOM
        vec3 bright = brightPass(src, 0.8);
        // blur uses colortex0 sampling for simplicity; could ping-pong for better quality
        outBloom = blur9(texcoord, texel, 1.75);
    #endif
    /* DRAWBUFFERS:3 */
    gl_FragData[3] = vec4(outBloom, 1.0);
}
