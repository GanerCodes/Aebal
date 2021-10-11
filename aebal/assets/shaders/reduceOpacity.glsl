#ifdef GL_ES
precision lowp float;
#endif

uniform sampler2D texture;

varying vec4 vertColor;
varying vec4 vertTexCoord;

float multiplier = 0.927; //0.975
float subtracter = 0.004; //0.004

void main() {
    vec4 clr = texture2D(texture, vertTexCoord.xy);
    gl_FragColor = clr.a < 0.01 ? vec4(0.0) : vec4(clr.rgb, clr.a * multiplier - subtracter);
}