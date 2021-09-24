import net.objecthunter.exp4j.*;
import net.objecthunter.exp4j.shuntingyard.*;
import net.objecthunter.exp4j.tokenizer.*;
import net.objecthunter.exp4j.function.*;
import net.objecthunter.exp4j.operator.*;

Function[] customEquationFunctions = new Function[] {
    new Function("max", 2) {
        public double apply(double... args) {
            return Math.max(args[0], args[1]);
        }
    }, new Function("min", 2) {
        public double apply(double... args) {
            return Math.max(args[0], args[1]);
        }
    }
};

class ChainedTransformation {
    PVector translate, scale;
    float rotation;
    ChainedTransformation(PVector scale, float rotation, PVector translate) {
        this.translate = translate;
        this.scale = scale;
        this.rotation = rotation;
    }

    //static = changes in place; default is to create new vector
    PVector applyStatic(PVector p) { return mulVecStatic(p.rotate(rotation), scale).add(translate); }
    PVector applyScaleStatic(PVector p) { return mulVecStatic(p, scale); }
    PVector applyRotationStatic(PVector p) { return p.rotate(rotation); }
    PVector applyTranslationStatic(PVector p) { return p.add(translate); }

    PVector apply(PVector p) { return applyStatic(p.copy()); }
    PVector applyScale(PVector p) { return applyScaleStatic(p.copy()); }
    PVector applyRotation(PVector p) { return applyRotationStatic(p.copy()); }
    PVector applyTranslation(PVector p) { return applyTranslationStatic(p.copy()); }
}
class EnemyPatternProperties {
    /**
    pattern will be blown up by a factor of 1/4  * smallest field size
    song intensity will probs just divide the song intensity by some constant. Maybe some nonlinear properties towards the end to make hard and impossible actually be close to it's title 
    if a bound is in reverse order, it is applied as such, so that it varies in the opposite way you would expect to the song intensity
    if a bound only has one value, then both bounds are set to that value.
    Velocity equations can use x, y, and time. If the location is defined implicity, then the angle from (translated) origin will be used.
    speed is anticipated to be around 1
    count is anticipated to not be stupid. Mental reminder to keep it in float form until it's time to itterate so that bounds and stuff work right

    difficulty              - [0] - a order number rather than value [so having enemies 1 & 2 have difficulty 1 & 2 isn't diffrent from difficulty 1 & 500], basically higher value = less likely to spawn / will spawn more likely on higher song intensity. This is also applied when picking a velocity pattern from the list
    disableRandomRotation   - [false] - distance randomized rotation
    defaultCount            - [implicit: 4, parametric: 16] - standard number of enemies [note, on implicit equations it represents the step count in both the x and y directions, basically sqrt() the expected count]
    countBounds             - [implicit: (3, 5), parametric: (7, 25)] - enemy count range, depends mostly on current song intensity
    distBounds              - [0.2, 0.8] - distance range to add to starting [after default translate value] location (1.0 is gameHeight (without margins ofc) / 2)
    defaultSpeed            - [midpoint of speedBounds] - default multiplier applied to velocity
    speedBounds             - [0.5, 1.5; defaultSpeed / 2, defaultSpeed * 2 if available] speed range, depends mostly on current song intensity
    scaleBounds             - [0.5, 1.5] scale multiplier range, depends mostly on current song intensity, applied after default scale adjustments but before rotation and translate [obviously]
    range                   - [1; only applies to implicit equation] graph scaling factor; 1 yeilds analyzing the equation from -1 to 1 on both the X and Y directions, while 2 would be -2 to 2. Mental note: use lerp again and keep origional ordering xd
    angleSweep              - [-PI, PI; only applies to parametric] - the values t will range from; mental note: keep order as is, use lerp to calculate t, making sure that both endpoints are included.
    
    "locPatterns": {
        "examplePattern": {
            difficulty: 1,
            velChoices: ["examplevelPatternhaha"]
            equation: "pow(x, 2) + y - 1",
            range: 1.5,
            transform: {
                "scale": "1, 1",
                "rotate": "0",
                "translate": "0, 0"
            }
            defaultCount: 5,
            countBounds: "4, 6",
            distBounds: "0.5, 1",
            defaultSpeed: "1",
            speedBounds: [0.8, 1.5]
            scaleBounds: [0.5, 2]
            modifiers: ["disableRandomRotation", ...],
        }
    },
    "velPatterns": {
        "examplevelPatternhaha": {
            equationX: "x + t + y",
            equationY: "max(2, y / x * sin(x))",
            angleSweep: "0, 1"
        }
    }


    The relationship for song dependant bounding and song intensity would something like this:
        song intensity under average: lerp(min, default, intensity / average)
        song intensity after average: lerp(default, max, m)
            m = nonlinear function that starts slowish and increases faster as it goes along, based on song intensity ranging from average to some high relevent value; output is between 0 and 1, obviously
    **/
    float difficulty, defaultCount, defaultSpeed, range;
    boolean allowRandomRotation, disableVelocityRotation;
    PVector distBounds, speedBounds, countBounds, scaleBounds, angleSweep;
    ChainedTransformation defaultTransformation;
    EnemyPatternProperties(float difficulty, ChainedTransformation defaultTransformation) {
        this.difficulty = difficulty;
        this.defaultTransformation = defaultTransformation;
    }
}
class Equation {
    static final int IMPLICIT   = 0;
    static final int PARAMETRIC = 1;

    int type;
    String ID, equationPrintable;
    String[] relatedEquationNames;

    EnemyPatternProperties spawnProperties;
    Equation(int type, String ID, String[] relatedEquationNames, String equationPrintable, EnemyPatternProperties spawnProperties) {
        this.type = type;
        this.ID = ID;
        this.relatedEquationNames = relatedEquationNames;
        this.equationPrintable = equationPrintable;
        this.spawnProperties = spawnProperties;
    }
    String toString() {
        return ID + ": " + equationPrintable;
    }
}
class Equation1D extends Equation {
    String equationStr;
    Expression equation;
    Equation1D(String ID, String[] relatedEquationNames, EnemyPatternProperties spawnProperties, String eq) {
        super(IMPLICIT, ID, relatedEquationNames, eq, spawnProperties);
        equation = new ExpressionBuilder(eq).functions(customEquationFunctions).variables("x", "y").build();
        this.range = range;
    }
    float getValAtLoc(float x, float y) {
        return (float)equation.setVariable("x", x).setVariable("y", y).evaluate();
    }
}
class Equation2D extends Equation {
    String equationXStr, equationYStr;
    float rangeStart, rangeEnd;
    Expression equationX, equationY;
    Equation2D(String ID, String[] relatedEquationNames, EnemyPatternProperties spawnProperties, String eqX, String eqY, float rangeStart, float rangeEnd) {
        super(PARAMETRIC, ID, relatedEquationNames, String.format("[%s, %s]", eqX, eqY), spawnProperties);
        equationX = new ExpressionBuilder(eqX).functions(customEquationFunctions).variables("x", "y", "t").build();
        equationY = new ExpressionBuilder(eqY).functions(customEquationFunctions).variables("x", "y", "t").build();
        this.rangeStart = rangeStart;
        this.rangeEnd = rangeEnd;
    }
    PVector getValAtLoc(float x, float y, float t) {
        return new PVector(
            (float)equationX.setVariable("x", x).setVariable("y", y).setVariable("t", t).evaluate(),
            (float)equationY.setVariable("x", x).setVariable("y", y).setVariable("t", t).evaluate()
        );
    }
}
class SpawnPatterns {
    ArrayList<Equation> locations;
    ArrayList<Equation2D> velocities;
    HashMap<String, Equation2D> VelIDMapping;
    HashMap<String, ArrayList<Equation2D>> locIDVelMapping;

    SpawnPatterns(ArrayList<Equation> locations, ArrayList<Equation2D> velocities) {
        this.locations = locations;
        this.velocities = velocities;

        VelIDMapping = new HashMap<String, Equation2D>();
        for(Equation2D velEquation : velocities) VelIDMapping.put(velEquation.ID, velEquation);

        locVelPatternMapping = new HashMap<String, ArrayList<Equation2D>>();
        for(Equation locEquation : locations) {
            ArrayList<Equation2D> complementVelocities = new ArrayList();
            for(String velName : locEquation.relatedEquationNames) complementVelocities.add(VelIDMapping.get(velName));
            locVelPatternMapping.put(locEquation.ID, complementVelocities);
        }
    }
    void adjustEnemy(PVector loc, PVector vel) {
        loc = loc;
        vel = vel;
    }
    void spawnLocVel(Equation location, Equation2D velocity, RNG rng, float time) {
        if(location.type == Equation.PARAMETRIC) {
            Equation1D parametricEquation = (Equation1D)location;
        }else if(location.type == Equation.IMPLICIT) {
            Equation2D implicitEquation = (Equation2D)location;
        }
    }
    void spawnPattern(GameMap gameMap, float difficulty, RNG rng, float time) {
        Equation spawnEquation = Equationlocations.get((int)rng.rand(locations.size()));
        ArrayList<Equation2D> spawnOptions = locIDVelMapping.get(spawnEquation.ID);
        Equation2D spawnVelocity = spawnOptions.get((int)rng.rand(spawnOptions.size()));
        spawnLocVel(spawnEquation, spawnVelocity, time);
    }
}

/*
class expressionLocPair {
    Expression x, y;
    float countDiv = 1, speedDiv = 1, scaleDiv = 1;
    String equation;
    expressionLocPair(Expression x, Expression y) {
        this.x = x;
        this.y = y;
    }
    void setDivs(float speedDiv, float countDiv, float scaleDiv) {
        this.speedDiv = speedDiv;
        this.countDiv = countDiv;
        this.scaleDiv = scaleDiv;
    }
}

float multiplyLenient(float a, float b) {
    return a > 0 && b > 0 ? a * b - abs((a - b) / (a + b)) : a * b;
}
void addExpression(ArrayList<expressionLocPair> exList, String eqX, String eqY, float speedDiv, float countDiv, float scaleDiv, char mode) {
    expressionLocPair newExp = (mode == 'p') ? new expressionLocPair(
        new ExpressionBuilder(eqX).functions(minEq, maxEq).variables("t").build(),
        new ExpressionBuilder(eqY).functions(minEq, maxEq).variables("t").build()
    ) : new expressionLocPair(
        new ExpressionBuilder(eqX).functions(minEq, maxEq).variables("x", "y").build(),
        new ExpressionBuilder(eqY).functions(minEq, maxEq).variables("x", "y").build()
    );
    
    newExp.setDivs(speedDiv, countDiv, scaleDiv);
    newExp.equation = "("+eqX+", "+eqY+")";
    exList.add(newExp);
}
PVector getLoc(expressionLocPair eq, float t) {
    return new PVector(
        (float)eq.x.setVariable("t", t).evaluate(),
        (float)eq.y.setVariable("t", t).evaluate()
    );
}
PVector getVel(expressionLocPair eq, PVector loc) {
    return new PVector(
        (float)eq.x.setVariable("x", loc.x).setVariable("y", loc.y).evaluate(),
        (float)eq.y.setVariable("x", loc.x).setVariable("y", loc.y).evaluate()
    );
}
PVector getVel(expressionLocPair eq, float x, float y) {
    return getVel(eq, new PVector(x, y));
}
boolean verifyObjSpawn(PVector loc, PVector vel, PVector playSize, PVector startLoc, float timeEnd) {
    PVector screenLoc  = new PVector(0, 0);
    PVector endLoc     = PVector.add(loc, PVector.mult(vel, timeEnd));

    return !inBounds(startLoc, screenLoc, playSize) && !inBounds(endLoc, screenLoc, playSize) && rectIntersection(screenLoc, playSize, startLoc, endLoc);
}
ArrayList<obj> makeObjectGroup(expressionLocPair locEq, expressionLocPair velEq, int objCount, float minTime, float maxTime, float speedMult, float scaleMult, float ang, PVector playArea, PVector objTranslate) {
    ArrayList<obj> group = new ArrayList();
    PVector center = PVector.div(playArea, 2.0);
    
    float speedDiv = multiplyLenient(locEq.speedDiv, velEq.speedDiv);
    float countDiv = multiplyLenient(locEq.countDiv, velEq.countDiv);
    float scaleDiv = multiplyLenient(locEq.scaleDiv, velEq.scaleDiv);

    speedMult /= abs(speedDiv);
    objCount = max(1, int(objCount / countDiv));
    scaleMult /= scaleDiv;

    float step = TWO_PI / objCount;
    for(int i = 0; i < objCount; i++) {
        float t = i * step;
        PVector loc = getLoc(locEq, t  );
        PVector vel = getVel(velEq, loc).mult(speedMult);
        loc.mult(scaleMult).add(objTranslate).add(center);
        PVector startLoc = PVector.add(loc, PVector.mult(vel, minTime));
        if(verifyObjSpawn(loc, vel, playArea, startLoc, maxTime)) {
            group.add(new obj(startLoc, vel));
        }
    }
    return group;
}
ArrayList<obj> getRandomGroup(ArrayList<expressionLocPair> locExpressions, ArrayList<expressionLocPair> velExpressions, PVector screenSize, RNG rng, int count, float sizeDiv, float speedDiv) {
    float baseSize = 3.0;

    float speedProp = 22.5 / 1000;
    float speedScaleFactor = speedProp * float(width) / (baseSize * speedDiv);
    float finalSize = random(200, 425) / (baseSize * sizeDiv);

    expressionLocPair locExp = locExpressions.get((int)rng.random(locExpressions.size()));
    expressionLocPair velExp = velExpressions.get((int)rng.random(velExpressions.size()));
    logmsg(String.format("Parametric Spawn: [%s, %s]", locExp.equation, velExp.equation));
    return makeObjectGroup(
        locExp, velExp, count, -10 / speedProp, 15 / speedProp, speedScaleFactor, finalSize, rng.randBool() ? rng.randomC(PI) : (rng.randBool() ? 0 : PI), screenSize,
        new PVector(
            rng.random(-1.0 / 6.5 * screenSize.x, 1.0 / 6.5 * screenSize.x),
            rng.random(-1.0 / 6.5 * screenSize.y, 1.0 / 6.5 * screenSize.y)
        )
    );
}

void loadPatternFile(String patternFileName, ArrayList locExpressions, ArrayList velExpressions) {
    if(locExpressions == null) locExpressions = new ArrayList();
    if(velExpressions == null) velExpressions = new ArrayList();
    String[] patternFile = loadStrings(patternFileName);
    for(String s : patternFile) {
        s = trim(split(s, "#")[0]);
        if(s.length() < 3 || s.charAt(0) == '#') continue;
        String[] spl = split(s.substring(2), "|");
        for(int i = 0; i < spl.length; i++) {
            spl[i] = trim(spl[i]);
        }
        boolean isParametric = s.substring(0, 2).equals("L:");
        addExpression(isParametric ? locExpressions : velExpressions, spl[0], spl[1], 
            spl.length > 2 && spl[2].length() > 0 ? float(spl[2]) : 1, 
            spl.length > 3 && spl[3].length() > 0 ? float(spl[3]) : 1, 
            spl.length > 4 && spl[4].length() > 0 ? float(spl[4]) : 1, 
            isParametric ? 'p' : 'i'
        );
    }
}*/