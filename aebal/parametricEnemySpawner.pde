import net.objecthunter.exp4j.*;
import net.objecthunter.exp4j.shuntingyard.*;
import net.objecthunter.exp4j.tokenizer.*;
import net.objecthunter.exp4j.function.*;
import net.objecthunter.exp4j.operator.*;

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

Function maxEq = new Function("max", 2) {
    public double apply(double... args) {
        return Math.max(args[0], args[1]);
    }
};
Function minEq = new Function("min", 2) {
    public double apply(double... args) {
        return Math.max(args[0], args[1]);
    }
};

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
}