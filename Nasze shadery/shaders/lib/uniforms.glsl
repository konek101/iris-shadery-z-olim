// Shared engine-provided uniforms for Iris/OptiFine shader stages
#ifndef UNIFORMS_GLSL
#define UNIFORMS_GLSL

// G-buffers and matrices
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;

// Color/depth attachments
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;

// Shadow mapping (minimal set)
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform sampler2D shadowtex0;

// Timing
uniform float frameTimeCounter;

// Sun/camera
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 cameraPosition;

// Block/entity classification (from block.properties / entity.properties)
uniform ivec4 mc_Entity;

// Weather/environment (may be provided by Iris/OptiFine; safe if unused)
uniform int isEyeInWater; // 0 none, 1 water, 2 lava, 3 powder snow
uniform float rainStrength; // 0..1
uniform float wetness; // 0..1 accumulated

#endif
