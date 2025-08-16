// Water effects: reflections/refractions/caustics/underwater distortion
#include "/lib/common.glsl"
#include "/lib/uniforms.glsl"

varying vec2 texcoord;

float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }

void main(){
    vec2 uv = texcoord;
    vec3 base = texture2D(colortex0, uv).rgb;

    #if WATER_ENABLE
        float t = frameTimeCounter;
        vec2 wave = vec2(sin(uv.y*60.0 + t*1.6), cos(uv.x*60.0 - t*1.2))*0.0015;
        vec2 uvd = uv + wave;
        vec3 refr = texture2D(colortex0, uvd).rgb;
        // simple fake reflection: flip Y and offset
        vec3 refl = texture2D(colortex0, vec2(uv.x, 1.0-uv.y) + wave*0.5).rgb;
        float fres = pow(1.0 - clamp(texture2D(depthtex0, uv).r, 0.0, 1.0), 3.0);
        base = mix(refr, refl, fres);
        // caustics tint
        float c = hash(floor(uv*vec2(256.0)+t));
        base *= mix(1.0, 1.15, c*0.15);
    #endif

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(base, 1.0);
}
