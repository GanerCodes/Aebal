#ifdef GL_ES
precision mediump float;
#endif

varying vec4 vertTexCoord;
uniform vec2 resolution;
uniform float u_time;

uniform float clr; //0.2
uniform float mul; //0.1
uniform float opacity; //1.0?

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float v = pow(0.6, 2.0) / 10.0;
void main() {
    vec2 st = vertTexCoord.xy;
    st = vec2(st.x * resolution.x / resolution.y - 0.5, st.y - 0.5);
    
    vec4 color = vec4(0.0);
    
    float t = (pow(abs((0.7*(st.x+0.1*sin((6.0+sin(u_time))*st.x+cos(u_time))))),2.0)+pow(abs((0.7*(st.y+0.1*sin((6.0+cos(u_time+sin(u_time)))*st.y+sin(-2.0*u_time))))),(2.0)))/v;
    if(t <= 1) {
        float curve = 0.933-3.85*(t)+11.09*pow(abs(t),2.0)-10.22*pow(abs(t),3.0)+3.32*pow(abs(t), 10.0);
        color = vec4(hsv2rgb(vec3(mul * u_time + curve * 0.2, clr, 0.4 + curve)), opacity);
    }
    gl_FragColor = color;
}