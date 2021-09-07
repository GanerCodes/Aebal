//alg nabbed from https://github.com/kiwipxl/GLSL-shaders/blob/master/bloom.glsl#L56

#ifdef GL_ES
precision lowp float;
#endif

uniform sampler2D texture;
varying vec4 vertTexCoord;
uniform vec2 resolution;

uniform float bloom_spread = 1.0;
uniform float bloom_intensity = 2.0 / 81.0;
uniform float saturation = 1.0;

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
    float uv_x = vertTexCoord.x * resolution.x;
    float uv_y = vertTexCoord.y * resolution.y;

    vec4 sum = vec4(0.0);
    for(int n = 0; n < 9; ++n) {
        uv_y = vertTexCoord.y * resolution.y + bloom_spread * float(n - 4);
        sum += texelFetch(texture, ivec2(uv_x - (4.0 * bloom_spread), uv_y), 0);
        sum += texelFetch(texture, ivec2(uv_x - (3.0 * bloom_spread), uv_y), 0);
        sum += texelFetch(texture, ivec2(uv_x - (2.0 * bloom_spread), uv_y), 0);
        sum += texelFetch(texture, ivec2(uv_x - (      bloom_spread), uv_y), 0);
        sum += texelFetch(texture, ivec2(uv_x                       , uv_y), 0);
        sum += texelFetch(texture, ivec2(uv_x + (      bloom_spread), uv_y), 0);
        sum += texelFetch(texture, ivec2(uv_x + (2.0 * bloom_spread), uv_y), 0);
        sum += texelFetch(texture, ivec2(uv_x + (3.0 * bloom_spread), uv_y), 0);
        sum += texelFetch(texture, ivec2(uv_x + (4.0 * bloom_spread), uv_y), 0);
    }

    vec4 clr = texture2D(texture, vertTexCoord.xy) + bloom_intensity * sum;
    if(saturation == 1.0) {
        gl_FragColor = clr;
    }else{
        vec3 hsv = rgb2hsv(clr.rgb);
        hsv.y *= saturation;
        gl_FragColor = vec4(hsv2rgb(hsv), clr.a);
    }
}