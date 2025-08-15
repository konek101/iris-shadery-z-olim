#version 330 compatibility

uniform sampler2D depthtex0;

uniform sampler2D shadowtex1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowcolor0;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;

uniform sampler2D noisetex;

uniform vec3 shadowLightPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

#include "/lib/distort.glsl"

// Boolean lighting options (recognized by Iris/OptiFine, default OFF)
// #define DIRECTIONAL_SKYLIGHT // Directionalize skylight based on upward normal. [DIRECTIONAL_SKYLIGHT]
// #define DIRECTIONAL_BLOCKLIGHT // Add mild face variation to blocklight. [DIRECTIONAL_BLOCKLIGHT]

/*
const int colortex0Format = RGB16;
*/

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

// Configurable lighting multipliers (can be overridden in shaders.properties)
#ifndef BLOCKLIGHT_STRENGTH
#define BLOCKLIGHT_STRENGTH 1.0 // [0.0 0.5 1.0 1.5 2.0]
#endif
#ifndef SKYLIGHT_STRENGTH
#define SKYLIGHT_STRENGTH 1.0 // [0.0 0.5 1.0 1.5 2.0]
#endif
#ifndef SUNLIGHT_STRENGTH
#define SUNLIGHT_STRENGTH 1.0 // [0.0 0.5 1.0 1.5 2.0]
#endif
#ifndef AMBIENT_STRENGTH
#define AMBIENT_STRENGTH 1.0 // [0.0 0.25 0.5 0.75 1.0]
#endif

const vec3 blocklightColor = vec3(1.0, 0.5, 0.08) * BLOCKLIGHT_STRENGTH;
const vec3 skylightColor = vec3(0.05, 0.15, 0.3) * SKYLIGHT_STRENGTH;
const vec3 sunlightColor = vec3(1.0) * SUNLIGHT_STRENGTH;
const vec3 ambientColor = vec3(0.02) * AMBIENT_STRENGTH;

// PBR toggles
#ifndef PBR_ENABLED
#define PBR_ENABLED 1 // [0 1]
#endif
#ifndef PBR_STANDARD
#define PBR_STANDARD 0 // 0 LabPBR, 1 OldPBR [0 1]
#endif
#ifndef SPECULAR_STRENGTH
#define SPECULAR_STRENGTH 1.0 // [0.0 0.5 1.0 1.5 2.0]
#endif
#ifndef ROUGHNESS_MULT
#define ROUGHNESS_MULT 1.0 // [0.25 0.5 1.0 1.5 2.0]
#endif
#ifndef METALNESS_MULT
#define METALNESS_MULT 1.0 // [0.0 0.5 1.0 1.5 2.0]
#endif
#ifndef AO_STRENGTH
#define AO_STRENGTH 1.0 // [0.0 0.5 1.0]
#endif
#ifndef EMISSIVE_STRENGTH
#define EMISSIVE_STRENGTH 1.0 // [0.0 0.5 1.0 2.0 3.0]
#endif

// Screen-space ray features (SSR/SSGI)
#ifndef SSR_ENABLED
#define SSR_ENABLED 1 // [0 1]
#endif
#ifndef SSR_STEPS
#define SSR_STEPS 16 // [8 16 24 32 48 64]
#endif
#ifndef SSR_MAX_DIST
#define SSR_MAX_DIST 24.0 // [8.0 16.0 24.0 32.0 48.0 64.0]
#endif
#ifndef SSR_THICKNESS
#define SSR_THICKNESS 0.2 // [0.02 0.05 0.1 0.2 0.4 1.0]
#endif
#ifndef SSR_JITTER
#define SSR_JITTER 1 // [0 1]
#endif
#ifndef SSGI_ENABLED
#define SSGI_ENABLED 1 // [0 1]
#endif
#ifndef SSGI_STEPS
#define SSGI_STEPS 8 // [4 8 12 16 24]
#endif
#ifndef SSGI_RADIUS
#define SSGI_RADIUS 2.0 // [0.5 1.0 2.0 4.0 6.0]
#endif
#ifndef SSGI_STRENGTH
#define SSGI_STRENGTH 0.35 // [0.0 0.2 0.35 0.5 0.8 1.0]
#endif

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
	vec4 homPos = projectionMatrix * vec4(position, 1.0);
	return homPos.xyz / homPos.w;
}

vec3 getShadow(vec3 shadowScreenPos){
  float transparentShadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r); // sample the shadow map containing everything

  /*
  note that a value of 1.0 means 100% of sunlight is getting through
  not that there is 100% shadowing
  */

  if(transparentShadow == 1.0){
    /*
    since this shadow map contains everything,
    there is no shadow at all, so we return full sunlight
    */
    return vec3(1.0);
  }

  float opaqueShadow = step(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.xy).r); // sample the shadow map containing only opaque stuff

  if(opaqueShadow == 0.0){
    // there is a shadow cast by something opaque, so we return no sunlight
    return vec3(0.0);
  }

  // contains the color and alpha (transparency) of the thing casting a shadow
  vec4 shadowColor = texture(shadowcolor0, shadowScreenPos.xy);


  /*
  we use 1 - the alpha to get how much light is let through
  and multiply that light by the color of the caster
  */
  return shadowColor.rgb * (1.0 - shadowColor.a);
}

vec4 getNoise(vec2 coord){
  ivec2 screenCoord = ivec2(coord * vec2(viewWidth, viewHeight)); // exact pixel coordinate onscreen
  ivec2 noiseCoord = screenCoord % 64; // wrap to range of noiseTextureResolution
  return texelFetch(noisetex, noiseCoord, 0);
}

vec3 getSoftShadow(vec4 shadowClipPos){
  float noise = getNoise(texcoord).r;

  float theta = noise * radians(360.0); // random angle using noise value
  float cosTheta = cos(theta);
  float sinTheta = sin(theta);

  mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta); // matrix to rotate the offset around the original position by the angle

  vec3 shadowAccum = vec3(0.0); // sum of all shadow samples
  const int samples = SHADOW_RANGE * SHADOW_RANGE * 4; // we are taking 2 * SHADOW_RANGE * 2 * SHADOW_RANGE samples

  // Distance-based softness: increase kernel radius as the receiver gets farther in light space
  vec3 baseNDC = shadowClipPos.xyz / shadowClipPos.w;
  float depth01 = clamp(baseNDC.z * 0.5 + 0.5, 0.0, 1.0);
  float softness = max(0.0, SHADOW_SOFTNESS) * mix(0.75, 2.5, depth01);

  for(int x = -SHADOW_RANGE; x < SHADOW_RANGE; x++){
    for(int y = -SHADOW_RANGE; y < SHADOW_RANGE; y++){
      vec2 offset = vec2(x, y) * (SHADOW_RADIUS * max(0.0001, softness)) / float(SHADOW_RANGE);
      offset = rotation * offset; // rotate the sampling kernel using the rotation matrix we constructed
      offset /= shadowMapResolution; // offset in the rotated direction by the specified amount. We divide by the resolution so our offset is in terms of pixels
      vec4 offsetShadowClipPos = shadowClipPos + vec4(offset, 0.0, 0.0); // add offset
      offsetShadowClipPos.z -= SHADOW_BIAS; // apply bias
      offsetShadowClipPos.xyz = distortShadowClipPos(offsetShadowClipPos.xyz); // apply distortion
      vec3 shadowNDCPos = offsetShadowClipPos.xyz / offsetShadowClipPos.w; // convert to NDC space
      vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5; // convert to screen space
      shadowAccum += getShadow(shadowScreenPos); // take shadow sample
    }
  }

  return shadowAccum / float(samples); // divide sum by count, getting average shadow
}

void main() {
	color = texture(colortex0, texcoord);
	color.rgb = pow(color.rgb, vec3(2.2));

	float depth = texture(depthtex0, texcoord).r;
	if (depth == 1.0) {
		return;
	}

  vec2 lightmap = texture(colortex1, texcoord).rg; // r,g
  vec3 encodedNormal = texture(colortex2, texcoord).rgb;
  vec3 normal = normalize((encodedNormal - 0.5) * 2.0);
  vec4 matData = texture(colortex3, texcoord);
  float rough = clamp(matData.r * ROUGHNESS_MULT, 0.02, 1.0);
  float metal = clamp(matData.g * METALNESS_MULT, 0.0, 1.0);
  float ao = mix(1.0, matData.b, AO_STRENGTH);
  float emiss = matData.a * EMISSIVE_STRENGTH;

	vec3 lightVector = normalize(shadowLightPosition);
	vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector;

	vec3 NDCPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
	vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);

	vec3 shadow = getSoftShadow(shadowClipPos);

  // Base components
  vec3 blocklight = lightmap.r * blocklightColor;
  vec3 skylight = lightmap.g * skylightColor;
  vec3 ambient = ambientColor;
  float NdotL = clamp(dot(worldLightVector, normal), 0.0, 1.0);
  vec3 sunlight = sunlightColor * NdotL * shadow;

  // Directionalize skylight using a simple hemisphere term (favor upward normals)
  #ifdef DIRECTIONAL_SKYLIGHT
    float hemi = clamp(0.5 * (normal.y + 1.0), 0.0, 1.0);
    skylight *= mix(0.25, 1.0, hemi);
  #endif

  // Add mild variation to blocklight by reducing lighting on top/bottom faces
  #ifdef DIRECTIONAL_BLOCKLIGHT
    float faceVar = 0.5 + 0.5 * (1.0 - abs(normal.y)); // brighter on vertical faces
    blocklight *= mix(0.7, 1.0, faceVar);
  #endif

  vec3 lighting = clamp(blocklight + skylight + ambient + sunlight, 0.0, 10.0);

  #if PBR_ENABLED
    // View vector approximated as camera-to-fragment in view space Z; use worldSun for spec dir
    vec3 V = normalize(-viewPos);
    vec3 L = normalize(worldLightVector);
    vec3 H = normalize(V + L);

    // Fresnel (Schlick), base reflectance F0 from base color and metalness
    vec3 baseColor = color.rgb;
    vec3 F0 = mix(vec3(0.04), baseColor, metal);
    float HoV = clamp(dot(H, V), 0.0, 1.0);
    float alpha = max(1e-3, rough*rough);
    float a2 = alpha*alpha;

    // GGX NDF
    float NoH = max(dot(normal, H), 0.0);
    float dDen = (NoH*NoH*(a2-1.0)+1.0);
    float D = a2 / max(3.14159 * dDen * dDen, 1e-5);

    // Smith G (Schlick-GGX)
    float NoV = max(dot(normal, V), 0.0);
    float NoL = max(dot(normal, L), 0.0);
    float k = (alpha + 1.0);
    k = (k*k) / 8.0;
    float Gv = NoV / max(NoV * (1.0 - k) + k, 1e-5);
    float Gl = NoL / max(NoL * (1.0 - k) + k, 1e-5);
    float G = Gv * Gl;

    // Fresnel
    vec3 F = F0 + (1.0 - F0) * pow(1.0 - HoV, 5.0);

    // Specular term
    vec3 spec = (D * G) * F / max(4.0 * NoV * NoL + 1e-5, 1e-5);
    spec *= SPECULAR_STRENGTH;

    // Diffuse term (Lambert) reduced by metalness (metals have little diffuse)
    vec3 kd = (1.0 - F) * (1.0 - metal);
    vec3 diffuse = baseColor / 3.14159 * kd;

    vec3 direct = (diffuse + spec) * (sunlight + skylight + ambient) + blocklight * baseColor;
    vec3 indirect = vec3(0.0);
    #if SSGI_ENABLED
      vec3 normalView = mat3(gbufferModelView) * normal;
      indirect += ssgi(viewPos, normalView) * baseColor;
    #endif
    #if SSR_ENABLED
      vec3 normalViewR = mat3(gbufferModelView) * normal;
      vec3 Vv = normalize(-viewPos);
      vec3 rcol = ssr(viewPos, Vv, normalViewR);
      float reflWeight = (1.0 - rough*rough);
      indirect += rcol * reflWeight;
    #endif
    color.rgb = (direct + indirect) * ao + emiss;
  #else
    color.rgb *= lighting;
  #endif
}

// --- Screen-space ray helpers ---
vec3 reconstructViewPos(vec2 uv, float depth) {
  vec3 ndc = vec3(uv*2.0-1.0, depth*2.0-1.0);
  return projectAndDivide(gbufferProjectionInverse, ndc);
}

bool depthHit(vec2 uv, float viewZ, float thickness) {
  float d = texture(depthtex0, uv).r;
  vec3 vp = reconstructViewPos(uv, d);
  return abs(vp.z - viewZ) < thickness;
}

vec3 sampleScene(vec2 uv) { return texture(colortex0, uv).rgb; }

vec3 ssr(vec3 originView, vec3 viewDir, vec3 normalView) {
  vec3 refl = reflect(viewDir, normalize(normalView));
  vec3 pos = originView;
  vec3 stepV = normalize(refl);
  float stepLen = SSR_MAX_DIST / float(SSR_STEPS);
  vec3 hitColor = vec3(0.0);
  float hit = 0.0;
  #if SSR_JITTER
    float n = getNoise(texcoord).r;
    pos += stepV * (n * stepLen);
  #endif
  for (int i=0;i<SSR_STEPS;i++) {
    pos += stepV * stepLen;
    vec3 ndc = projectAndDivide(gbufferProjection, pos);
    vec2 uv = ndc.xy * 0.5 + 0.5;
    if (uv.x<0.0||uv.y<0.0||uv.x>1.0||uv.y>1.0) break;
    if (depthHit(uv, pos.z, SSR_THICKNESS)) { hit = 1.0; hitColor = sampleScene(uv); break; }
  }
  return mix(vec3(0.0), hitColor, hit);
}

vec3 ssgi(vec3 originView, vec3 normalView) {
  vec3 n = normalize(normalView);
  vec3 acc = vec3(0.0);
  float wsum = 0.0;
  for (int i=0;i<SSGI_STEPS;i++) {
    float h1 = fract(getNoise(texcoord + float(i)*0.01).r + float(i)*0.37);
    float h2 = fract(getNoise(texcoord + float(i)*0.02).g + float(i)*0.73);
    float phi = 6.28318 * h1;
    float cosT = sqrt(1.0 - h2);
    float sinT = sqrt(h2);
    vec3 dir = vec3(cos(phi)*sinT, sin(phi)*sinT, cosT);
    // build a simple orthonormal basis around n
    vec3 up = abs(n.z) < 0.999 ? vec3(0.0,0.0,1.0) : vec3(0.0,1.0,0.0);
    vec3 tangent = normalize(cross(up, n));
    vec3 bitangent = cross(n, tangent);
    vec3 dirV = normalize(tangent*dir.x + bitangent*dir.y + n*dir.z);
    vec3 samplePos = originView + dirV * SSGI_RADIUS;
    vec3 ndc = projectAndDivide(gbufferProjection, samplePos);
    vec2 uv = ndc.xy * 0.5 + 0.5;
    if (uv.x<0.0||uv.y<0.0||uv.x>1.0||uv.y>1.0) continue;
    vec3 c = sampleScene(uv);
    float w = max(dot(n, dirV), 0.0);
    acc += c * w;
    wsum += w;
  }
  if (wsum < 1e-4) return vec3(0.0);
  return acc / wsum * SSGI_STRENGTH;
}