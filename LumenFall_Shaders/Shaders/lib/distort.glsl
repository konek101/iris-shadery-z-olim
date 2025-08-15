const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;

// Configurable soft shadow parameters (recognized by Iris/OptiFine when included)
const int shadowMapResolution = 2048; // Shadowmap resolution [1024 1536 2048 3072 4096]

#ifndef SHADOW_RANGE
#define SHADOW_RANGE 4 // PCF half-kernel size (samples = (2*R)^2) [2 3 4 5 6]
#endif
#ifndef SHADOW_RADIUS
#define SHADOW_RADIUS 1.0 // Base kernel radius in shadow texels [0.5 1.0 1.5 2.0 3.0]
#endif
#ifndef SHADOW_SOFTNESS
#define SHADOW_SOFTNESS 1.0 // Distance-based softness multiplier [0.0 0.5 1.0 1.5 2.0]
#endif
#ifndef SHADOW_BIAS
#define SHADOW_BIAS 0.001 // Depth bias to reduce acne [0.0002 0.0005 0.001 0.002 0.004]
#endif

vec3 distortShadowClipPos(vec3 shadowClipPos){
  float distortionFactor = length(shadowClipPos.xy); // distance from the player in shadow clip space
  distortionFactor += 0.1; // very small distances can cause issues so we add this to slightly reduce the distortion

  shadowClipPos.xy /= distortionFactor;
  shadowClipPos.z *= 0.5; // increases shadow distance on the Z axis, which helps when the sun is very low in the sky
  return shadowClipPos;
}