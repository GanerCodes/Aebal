//Literally 80% of this is practically useless

import java.util.Random;
import java.text.DecimalFormat;
float timerUpdateTime;

int sgn(float x)       { return x > 0 ? 1 : (x < 0 ? -1 : 0); }
int sign(float x)      { return sgn(x); }
int signnum(float x)   { return sgn(x); }

int sgnNZ(float x)         { return x >= 0 ? 1 : -1; }
int signNZ(float x)        { return sgnNZ(x); }
int signumNZ(float x)      { return sgnNZ(x); }
int sngNonZero(float x)    { return sgnNZ(x); }
int signNonZero(float x)   { return sgnNZ(x); }
int signumNonZero(float x) { return sgnNZ(x); }

class RNG {
    Random RNG;
    float seed;
    
    float setSeed(float seed) {
        this.seed = seed;
        RNG.setSeed((long) (1000000 * seed));
        return this.seed;
    }
    float randomizeSeed() {
        RNG = new Random(); 
        return setSeed(RNG.nextFloat());
    }

    RNG(float seed) {
        RNG = new Random();
        setSeed(seed);
    }
    RNG() {
        randomizeSeed();
    }

    float r()                      { return RNG.nextFloat(); }
    float r(float a, float b)      { return lerp(a, b, r()); }
    float r(float x)               { return r() * x;         }
    float r(PVector p)             { return r(p.x, p.y);     }
    float rng()                    { return r();             }
    float rng(float a, float b)    { return r(a, b);         }
    float rng(float x)             { return r(x);            }
    float rng(PVector p)           { return r(p);            }
    float rand()                   { return r();             }
    float rand(float a, float b)   { return r(a, b);         }
    float rand(float x)            { return r(x);            }
    float rand(PVector p)          { return r(p);            }
    float random()                 { return r();             }
    float random(float a, float b) { return r(a, b);         }
    float random(float x)          { return r(x);            }
    float random(PVector p)        { return r(p);            }

    float rC(float x)             { return r(-x, x); }
    float rngC(float x)           { return rC(x);    }
    float randC(float x)          { return rC(x);    }
    float randomC(float x)        { return rC(x);    }
    float rCentered(float x)      { return rC(x);    }
    float rngCentered(float x)    { return rC(x);    }
    float randCentered(float x)   { return rC(x);    }
    float randomCentered(float x) { return rC(x);    }
    float rC()                    { return rC(1);    }
    float rngC()                  { return rC();     }
    float randC()                 { return rC();     }
    float randomC()               { return rC();     }
    float rCentered()             { return rC();     }
    float rngCentered()           { return rC();     }
    float randCentered()          { return rC();     }
    float randomCentered()        { return rC();     }
    
    float randAngle()             { return rC(PI);   }
    PVector randVec()               { return PVector.fromAngle(randAngle()); }
    PVector randVec(float x)        { return randVec().mult(x); }

    boolean rB()            { return RNG.nextBoolean(); }
    boolean rBool()         { return rB(); }
    boolean rBoolean()      { return rB(); }
    boolean rngB()          { return rB(); }
    boolean rngBool()       { return rB(); }
    boolean rngBoolean()    { return rB(); }
    boolean randB()         { return rB(); }
    boolean randBool()      { return rB(); }
    boolean randBoolean()   { return rB(); }
    boolean randomB()       { return rB(); }
    boolean randomBool()    { return rB(); }
    boolean randomBoolean() { return rB(); }

    int rSgn()             { return rB() ? 1 : -1; }
    int rSign()            { return rSgn(); }
    int rSignum()          { return rSgn(); }
    int rngSgn()           { return rSgn(); }
    int rngSign()          { return rSgn(); }
    int rngSignum()        { return rSgn(); }
    int randSgn()          { return rSgn(); }
    int randSign()         { return rSgn(); }
    int randSignum()       { return rSgn(); }
    int randomSgn()        { return rSgn(); }
    int randomSign()       { return rSgn(); }
    int randomSignum()     { return rSgn(); }
    float rSgn(float x)         { return rSgn() * x; }
    float rSign(float x)        { return rSgn(x); }
    float rSignum(float x)      { return rSgn(x); }
    float rngSgn(float x)       { return rSgn(x); }
    float rngSign(float x)      { return rSgn(x); }
    float rngSignum(float x)    { return rSgn(x); }
    float randSgn(float x)      { return rSgn(x); }
    float randSign(float x)     { return rSgn(x); }
    float randSignum(float x)   { return rSgn(x); }
    float randomSgn(float x)    { return rSgn(x); }
    float randomSign(float x)   { return rSgn(x); }
    float randomSignum(float x) { return rSgn(x); }

    boolean rP(float x)               { return random() < x; }
    boolean rngP(float x)             { return rP(x); }
    boolean randP(float x)            { return rP(x); }
    boolean randomP(float x)          { return rP(x); }
    boolean rProp(float x)            { return rP(x); }
    boolean rngProp(float x)          { return rP(x); }
    boolean randProp(float x)         { return rP(x); }
    boolean randomProp(float x)       { return rP(x); }
    boolean rProportion(float x)      { return rP(x); }
    boolean rngProportion(float x)    { return rP(x); }
    boolean randProportion(float x)   { return rP(x); }
    boolean randomProportion(float x) { return rP(x); }
    boolean rP()               { return rP(1); }
    boolean rngP()             { return rP();  }
    boolean randP()            { return rP();  }
    boolean randomP()          { return rP();  }
    boolean rProp()            { return rP();  }
    boolean rngProp()          { return rP();  }
    boolean randProp()         { return rP();  }
    boolean randomProp()       { return rP();  }
    boolean rProportion()      { return rP();  }
    boolean rngProportion()    { return rP();  }
    boolean randProportion()   { return rP();  }
    boolean randomProportion() { return rP();  }

}

// This is dumb and forces evaluation of all arguments
// boolean GTLT  (float a, float b, float c) { return a >  b && a <  c; }
// boolean LTGT  (float a, float b, float c) { return a <  c && a >  b; }
// boolean GTLTE (float a, float b, float c) { return a >= b && a <= c; }
// boolean LTGTE (float a, float b, float c) { return a <= c && a >= b; }
// boolean GTLT  (int   a, int   b, int   c) { return a >  b && a <  c; }
// boolean LTGT  (int   a, int   b, int   c) { return a <  c && a >  b; }
// boolean GTLTE (int   a, int   b, int   c) { return a >= b && a <= c; }
// boolean LTGTE (int   a, int   b, int   c) { return a <= c && a >= b; }
// boolean NGTLT (float a, float b, float c) { return a <  b || a >  c; }
// boolean NLTGT (float a, float b, float c) { return a >  c || a <  b; }
// boolean NGTLTE(float a, float b, float c) { return a <= b || a >= c; }
// boolean NLTGTE(float a, float b, float c) { return a >= c || a <= b; }
// boolean NGTLT (int   a, int   b, int   c) { return a <  b || a >  c; }
// boolean NLTGT (int   a, int   b, int   c) { return a >  c || a <  b; }
// boolean NGTLTE(int   a, int   b, int   c) { return a <= b || a >= c; }
// boolean NLTGTE(int   a, int   b, int   c) { return a >= c || a <= b; }

float map(float v, PVector r1, PVector r2) {
    return map(v, r1.x, r1.y, r2.x, r2.y);
}
float map(float v, PVector r1, float r2_min, float r2_max) {
    return map(v, r1.x, r1.y, r2_min, r2_max);
}
float map(float v, float r1_min, float r1_max, PVector r2) {
    return map(v, r1_min, r1_max, r2.x, r2.y);
}

float cNorm(float a, float b, float c) {
    return constrain(norm(a, b, c), 0, 1);
}
float cNorm(float v, PVector range) {
    return cNorm(v, range.x, range.y);
}

float clamp(float v, float a, float b) {
    return constrain(v, min(a, b), max(a, b));
}
float clamp(float v, PVector range) {
    return clamp(v, range.x, range.y);
}

float clampMap(float v, float r1_min, float r1_max, float r2_min, float r2_max) {
    return clamp(map(v, r1_min, r1_max, r2_min, r2_max), r2_min, r2_max);
}
float clampMap(float v, PVector r1, PVector r2) {
    return clampMap(v, r1.x, r1.y, r2.x, r2.y);
}
float clampMap(float v, PVector r1, float r2_min, float r2_max) {
    return clampMap(v, r1.x, r1.y, r2_min, r2_max);
}
float clampMap(float v, float r1_min, float r1_max, PVector r2) {
    return clampMap(v, r1_min, r1_max, r2.x, r2.y);
}

float constrainMap(float v, float r1_min, float r1_max, float r2_min, float r2_max) {
    return constrain(map(v, r1_min, r1_max, r2_min, r2_max), r2_min, r2_max);
}
float constrainMap(float v, PVector r1, PVector r2) {
    return constrain(map(v, r1.x, r1.y, r2.x, r2.y), r2.x, r2.y);
}
float constrainMap(float v, float r1_min, float r1_max, PVector r2) {
    return constrain(map(v, r1_min, r1_max, r2.x, r2.y), r2.x, r2.y);
}
float constrainMap(float v, PVector r1, float r2_min, float r2_max) {
    return constrain(map(v, r1.x, r1.y, r2_min, r2_max), r2_min, r2_max);
}

//Why do lerp and norm have diffrent orderings
float norm(float v, PVector range) {
    return norm(v, range.x, range.y);
}
float lerp(PVector range, float val) {
    return lerp(range.x, range.y, val);
}
float lerp(float val, PVector range) {
    return lerp(range.x, range.y, val);
}
float lerpCentered(PVector range, float val) {
    if(val < 0.5) {
        return lerp(range.x, range.y, val * 2);
    }else{
        return lerp(range.y, range.z, val * 2 - 1);
    }
}
float lerpCentered(float val, PVector range) {
    return lerpCentered(range, val);
}

float multiplyLenient(float a, float b) {
    return a > 0 && b > 0 ? a * b - abs((a - b) / (a + b)) : a * b;
}
float roundArbitrary(float v, float r) {
    return r * round(v / r);
}
float rootMeanSquare(float[] vals) {
    float r = 0;
    for(int i = 0; i < vals.length; i++) r += sq(vals[i]);
    return sqrt(r / vals.length);
}
float[] accumulate(float[] vals) {
    if(vals.length <= 1) return vals;
    for(int i = 1; i < vals.length; i++) {
        vals[i] += vals[i - 1];
    }
    return vals;
}


int findLocalMaxRight(float[] vals, int index, int maxOffset) {
    if(index >= vals.length - 1) return index;
    
    int m = index;
    for(int i = index + 1; i < min(vals.length, index + maxOffset + 1); i++) {
        if(vals[i] > vals[m]) {
            m = i;
        }else{
            return m;
        }
    }
    return m;
}
int findLocalMaxLeft(float[] vals, int index, int maxOffset) {
    if(index <= 1) return index;
    
    int m = index;
    for(int i = index - 1; i >= max(0, index - maxOffset - 1); i--) {
        if(vals[i] > vals[m]) {
            m = i;
        }else{
            return m;
        }
    }
    return m;
}
int findLocalMax(float[] vals, int index, int maxOffset) {
    int l = findLocalMaxLeft (vals, index, maxOffset);
    int r = findLocalMaxRight(vals, index, maxOffset);
    return vals[l] > vals[r] ? l : r;
}
int findLocalMaxOffset(float[] vals, int index, int maxOffset) {
    return findLocalMax(vals, index, maxOffset) - index;
}

color mulColor(color c, PVector v) {
    return color(red(c) * v.x, green(c) * v.y, blue(c) * v.z);
}
color lerpColors(float v, color... colors) {
    v *= 0.9999 * (colors.length - 1);
    int indx = constrain(int(v), 0, colors.length - 2);
    return lerpColor(colors[indx], colors[indx + 1], v % 1.0);
}

int     jsonVal(JSONObject json, String key, int     alternate) {
    return json.isNull(key) ? alternate : json.getInt    (key);
}
float   jsonVal(JSONObject json, String key, float   alternate) {
    return json.isNull(key) ? alternate : json.getFloat  (key);
}
String  jsonVal(JSONObject json, String key, String  alternate) {
    return json.isNull(key) ? alternate : json.getString (key);
}
boolean jsonVal(JSONObject json, String key, boolean alternate) {
    return json.isNull(key) ? alternate : json.getBoolean(key);
}