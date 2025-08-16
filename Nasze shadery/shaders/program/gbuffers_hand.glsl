#include "/lib/uniforms.glsl"
#include "/lib/common.glsl"

#ifdef VERTEX_SHADER
varying vec2 texcoord;
varying vec4 vertexColor;
varying vec3 fragPos;           // world-space
varying vec3 encodedNormal;     // world-space normal
void main(){
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vertexColor = gl_Color;
    vec4 posVS = gbufferModelView * gl_Vertex;
    fragPos = (gbufferModelViewInverse * posVS).xyz;
    vec3 nVS = normalize(mat3(gbufferModelView) * gl_Normal.xyz);
    encodedNormal = normalize(mat3(gbufferModelViewInverse) * nVS);
}
#endif

#ifdef FRAGMENT_SHADER
uniform sampler2D texture;
uniform sampler2D lightmap;
varying vec2 texcoord;
varying vec4 vertexColor;
varying vec3 fragPos;
varying vec3 encodedNormal;

void main(){
    vec4 albedo = texture2D(texture, texcoord) * vertexColor;
    if(albedo.a < 0.1) discard;

    vec3 N = normalize(encodedNormal);
    vec3 L = normalize(sunPosition);
    vec3 V = normalize(cameraPosition - fragPos);
    float NdotL = 0.0;
    #if SUNLIGHT_ENABLE
        NdotL = max(dot(N,L), 0.0);
    #endif

    vec3 ambient = albedo.rgb * (float(AMBIENT_MULT)/200.0);
    vec3 sunColor = vec3(1.0, 0.97, 0.92);
    vec3 diffuse = albedo.rgb * sunColor * NdotL;
    vec3 H = normalize(L+V);
    float NdotH = max(dot(N,H), 0.0);
    vec3 spec = sunColor * pow(NdotH, 64.0) * 0.05;

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(ambient + diffuse + spec, albedo.a);
}
#endif
