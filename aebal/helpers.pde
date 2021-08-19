import java.util.Random;

int rSign() { return random(0, 1) > 0.5 ? 1 : -1; }
PVector vec2(float x, float y) { return new PVector(x, y); }
PVector vec2(float x) { return new PVector(x, x); }
PVector vec2() { return new PVector(0, 0); }
void setVec(PVector vec, float x, float y) {
    vec.x = x;
    vec.y = y;
}
void setVec(PVector vec, float x) {
    vec.x = x;
    vec.y = x;
}
PVector mulVec(PVector vec1, PVector vec2) {
    return new PVector(vec1.x * vec2.x, vec1.y * vec2.y);
}

Random unimportantRandoms;
float s_random(float a, float b) {
    return lerp(a, b, unimportantRandoms.nextFloat());
}

float cNorm(float a, float b, float c) {
    return constrain(norm(a, b, c), 0, 1);
}

float sign(float x) {
    return x < 0 ? -1 : 1;
}