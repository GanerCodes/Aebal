import java.util.Random;
import java.text.DecimalFormat;
Random unimportantRandoms;
float timerUpdateTime;

int rSign() { return random(0, 1) > 0.5 ? 1 : -1; }
PVector vec2(float x, float y) { return new PVector(x, y); }
PVector vec2(float x) { return new PVector(x, x); }
PVector vec2() { return new PVector(0, 0); }
PVector vec3(float x, float y, float z) { return new PVector(x, y, z); }
PVector vec3(float x, float y) { return new PVector(x, y, 0); }
PVector vec3(float x) { return new PVector(x, x, x); }
PVector vec3() { return new PVector(0, 0, 0); }
PVector mulVec(PVector vec1, PVector vec2) {
    return new PVector(vec1.x * vec2.x, vec1.y * vec2.y);
}
float s_random(float a, float b) {
    return lerp(a, b, unimportantRandoms.nextFloat());
}
float cNorm(float a, float b, float c) {
    return constrain(norm(a, b, c), 0, 1);
}
float sign(float x) {
    return x < 0 ? -1 : 1;
}
color mulColor(color c, PVector v) {
    return color(red(c) * v.x, green(c) * v.y, blue(c) * v.z);
}
color lerpColors(float v, color... colors) {
    v *= 0.9999 * (colors.length - 1);
    int indx = constrain(int(v), 0, colors.length - 2);
    return lerpColor(colors[indx], colors[indx + 1], v % 1.0);
}

float clamp(float x, float a, float b) {
    return constrain(x, min(a, b), max(a, b));
}
float clampMap(float x, float r1_min, float r1_max, float r2_min, float r2_max) {
    return clamp(map(x, r1_min, r1_max, r2_min, r2_max), r2_min, r2_max);
}
float constrainMap(float x, float r1_min, float r1_max, float r2_min, float r2_max) {
    return constrain(map(x, r1_min, r1_max, r2_min, r2_max), r2_min, r2_max);
}