#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2D texture;

varying vec4 vertColor;
varying vec4 vertTexCoord;

void main() {
    vec4 clr = texture2D(texture, vertTexCoord.xy);
    if(clr.a < 0.01) {
        gl_FragColor = vec4(0.0);
    }else{
        gl_FragColor = vec4(clr.rgb, clr.a * 0.975 - 0.004);
    }
}