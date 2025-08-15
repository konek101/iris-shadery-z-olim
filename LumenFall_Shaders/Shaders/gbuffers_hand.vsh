#version 330 compatibility

uniform mat4 gbufferModelViewInverse;

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

	vec3 viewNormal = gl_NormalMatrix * gl_Normal;
	normal = mat3(gbufferModelViewInverse) * viewNormal;
	vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
	worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
}
