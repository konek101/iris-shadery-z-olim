#version 130

#define FRAGMENT_SHADER
#define OVERWORLD
#define GBUFFERS_WATER
// Fixes: proper sun/moon-aligned caustics applied only to water

#include "/program/gbuffers_water.glsl"
