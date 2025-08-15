#version 330 compatibility

uniform sampler2D colortex0;

in vec2 texcoord;

layout(location = 0) out vec4 color;

void main() {
	color = texture(colortex0, texcoord);
	color.rgb = pow(color.rgb, vec3(1.0 / 2.2));
	color.a = 1.0; // Make final framebuffer opaque to avoid screen-wide transparency issues
}