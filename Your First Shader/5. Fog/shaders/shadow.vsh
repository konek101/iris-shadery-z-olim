#version 330 compatibility

out vec2 texcoord;
out vec4 glcolor;

#include "/lib/distort.glsl"

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	glcolor = gl_Color;
	gl_Position = ftransform();
  gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);
}