#ifdef GL_ES
precision lowp float;
#endif

varying vec4 vertTexCoord;
uniform vec2 resolution;

uniform float clr; //0.2
uniform float mul; //0.1
uniform float opacity; //1.0?

const int BUBBLE_COUNT = 4;
uniform float coord_x[BUBBLE_COUNT];
uniform float coord_y[BUBBLE_COUNT];
uniform float timeOff[BUBBLE_COUNT];

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 0.66666, 0.33333, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, p - K.xxx, c.y);
}

float v = 13.6111111;
float resFact = resolution.x / resolution.y;
void main() {
    vec4 result = vec4(0.0);
    for(int i = 0; i < BUBBLE_COUNT; i++) {
        vec2 st = 0.75 * vec2(resFact * (vertTexCoord.x - coord_x[i]), vertTexCoord.y - coord_y[i]);
        float u_time = timeOff[i];
        float timeCos = cos(u_time);
        float timeSin = sin(u_time);
        float t2sc = 2 * timeCos * timeSin;
        float t = v*(pow(st.x + 0.1*sin((6 + timeSin)*st.x + timeCos), 2.0) + pow(st.y + 0.1*sin((6 + cos(u_time + 2*timeSin)) * st.y - t2sc), 2.0));
        if(t <= 1.0) {
            float curve = 0.933 + 3.32*pow(t, 10.0) - 3.85*t + 11.09*pow(t, 2.0) - 10.22*pow(t, 3.0);
            result = vec4(hsv2rgb(vec3(mul*u_time + 0.2*curve, clr, 0.4 + curve)), opacity);
        }
    }
    gl_FragColor = result;
}