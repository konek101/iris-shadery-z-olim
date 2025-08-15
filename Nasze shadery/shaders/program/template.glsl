#version 130

#ifdef VERTEX_SHADER
varying vec2 texcoord;
void main(){
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
#endif

#ifdef FRAGMENT_SHADER
varying vec2 texcoord;
void main(){
    gl_FragColor = vec4(0.0);
}
#endif
