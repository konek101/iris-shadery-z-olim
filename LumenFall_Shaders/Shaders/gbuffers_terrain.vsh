#version 330 compatibility

uniform mat4 gbufferModelViewInverse;
uniform mat4 gl_ModelViewMatrix;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 normal;
out vec3 worldPos;

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;

	normal = gl_NormalMatrix * gl_Normal; // this gives us the normal in view space
	normal = mat3(gbufferModelViewInverse) * normal; // this converts the normal to world/player space

	vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
	worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
}