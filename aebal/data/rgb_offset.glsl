#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform sampler2D texture;
uniform vec2 r;
uniform vec2 g;
uniform vec2 b;

varying vec4 vertColor;
varying vec4 vertTexCoord;

void main() {
    gl_FragColor = vec4(
        texture2D(texture, vertTexCoord.xy - r).r, 
        texture2D(texture, vertTexCoord.xy - g).g, 
        texture2D(texture, vertTexCoord.xy - b).b, 
        1.0
    );
}