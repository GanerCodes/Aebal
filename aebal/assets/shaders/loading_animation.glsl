// https://www.desmos.com/calculator/8uvigkadg9

#ifdef GL_ES
precision mediump float;
#endif

varying vec4 vertTexCoord;
uniform vec2 resolution;
uniform float u_time;

float PI = 3.14159265358;
float HALF_PI = 1.57079632679;
float ANGLE = PI / 5.0;

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float loop(float x, float s, float e) {
    return mod(x + s, e - s) + s;
}
float seg(float x, float i) {
    return 1.0 - min(1.0, 5.0 / 4.0 * abs(x - i));
}
vec2 split(float a) {
    return vec2(cos(a), sin(a));
}
vec2 rot(vec2 p, float a) {
    return length(p) * split(atan(p.y, p.x) + a);
}

float circle(vec2 p) {
    return pow(p.x, 2.0) + pow(p.y, 2.0) - 1.0;
}
float square(vec2 p) {
    return 0.005 * max(abs(p.x), abs(p.y)) - 1.0;
}
float triangle(vec2 p) {
    return abs(p.y + abs(p.x)) + abs(p.x) - 1.0;
}

float getShape(int i, vec2 p) {
	if(i == 0) {
		return 0.85 * pow(abs(p.x), 2.5 * abs(p.y)) + pow(abs(p.y), 2.5 * abs(p.x)) - 1.0;
    }else if(i == 1) {
		return 0.75 * pow(abs(p.y), 0.5) + pow(abs(p.x), 0.5) - 1.0;
    }else if(i == 2) {
		return 0.75 * (abs(p.y - abs(p.x)) + abs(p.x) - 0.2) - (cos(p.x * 4.0) * cos(p.y * 4.0) - 0.1);
    }else if(i == 3) {
		return 1.0 * (pow(p.x, 2.0) + pow(p.y - sin(abs(8.0 * p.x) / 2.0), 2.0) - 1.0);
    }else if(i == 4) {
		return 1.0 * max(abs(p.x), abs(p.y)) - 2.0;
    }
}

void main() {
    vec2 st = 20.0 * (vertTexCoord.xy - 0.5);

    float time = mod(u_time / 10.0, 1.0);
	float d = length(st);
    vec2 v = rot(
        5.0 / 4.0 * d * split(
            loop(
                -8.0 * sin(2.0 * PI * time) * 2.0 * abs(time - 0.5) + atan(st.y, st.x),
                HALF_PI - ANGLE,
                HALF_PI + ANGLE
            )
        ) - vec2(
            0.0, 
            5.0 * pow(4.0 * 2.0 * abs(time - 0.5), 1.0 / 3.0) + 0.25
        ), (d / 3.0 + 1.5) * pow(sin(2.0 * PI * time), 3.0)
    );
    
    float count = 5.0;
    float val = 0.0;    
    val += seg(count * time, 0.0) * getShape(0, v);
    val += seg(count * time, 1.0) * getShape(1, v);
	val += seg(count * time, 2.0) * getShape(2, v);
    val += seg(count * time, 3.0) * getShape(3, v);
    val += seg(count * time, 4.0) * getShape(4, v);
    
    val += seg(count * time, count) * getShape(0, v);
    
    gl_FragColor = vec4(val <= 0.01 ? 25.0 * abs(val) : 0.0);
}