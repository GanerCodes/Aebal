#ifdef GL_ES
precision lowp float;
#endif

varying vec4 vertTexCoord;
uniform vec2 resolution;
uniform float u_time;

uniform float clr; //0.2
uniform float mul; //0.1
uniform float opacity; //1.0?

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 0.66666, 0.33333, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float v = 10.0 / pow(0.6, 2.0);
void main() {
    vec2 st = vertTexCoord.xy;
    st = 0.45*vec2(st.x * resolution.x / resolution.y - 0.5, st.y - 0.5);
    
    vec4 color = vec4(0.0);
    
    float t = v*abs(pow(0.7*st.x+0.07*sin((6.0+sin(u_time))*st.x+cos(u_time)),2.0)+pow(0.7*st.y+0.07*sin(st.y*(6.0+cos(u_time+sin(u_time)))-sin(2.0*u_time)),2.0));
    if(t <= 1) {
        float curve = 0.933+3.32*pow(t, 10.0)-t*3.85+11.09*pow(t, 2.0)-10.22*pow(t, 3.0);
        // float curve = 0.5;
        color = vec4(hsv2rgb(vec3(mul * u_time + curve * 0.2, clr, 0.4 + curve)), opacity);
    }
    gl_FragColor = color;
}