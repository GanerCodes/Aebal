import java.util.Arrays;
import java.util.Iterator;
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
    }, new Function("atan2", 2) {
        public double apply(double... args) {
            return Math.atan2(args[0], args[1]);
        }
    }
};

abstract class Transformation {
    abstract PVector apply(PVector p);
}
class Scale extends Transformation {
    PVector scale;
    Scale(PVector scale) {
        this.scale = scale;
    }
    PVector apply(PVector p) {
        mulVec(p, scale);
        return p;
    }
    String toString() {
        return String.format("Scale: (%s, %s)", scale.x, scale.y);
    }
}
class Rotate extends Transformation {
    float angle;
    Rotate(float angle) {
        this.angle = angle;
    }
    PVector apply(PVector p) {
        p.rotate(angle);
        return p;
    }
    String toString() {
        return String.format("Rotation: %srad", angle);
    }
}
class Translate extends Transformation {
    PVector translation;
    Translate(PVector translation) {
        this.translation = translation;
    }
    PVector apply(PVector p) {
        p.add(translation);
        return p;
    }
    String toString() {
        return String.format("Translation: (%s, %s)", translation.x, translation.y);
    }
}

class ChainedTransformation {
    ArrayList<Transformation> transformations;
    ChainedTransformation(ArrayList<Transformation> transformations) {
        this.transformations = transformations;
    }
    PVector apply(PVector p) {
        for(Transformation t : transformations) t.apply(p);
        return p;
    }
    PVector applyCopy(PVector p) {
        apply(p = p.copy());
        return p;
    }
    String toString() {
        String r = "";
        for(int i = 0; i < transformations.size(); i++) {
            r += transformations.get(i).toString() + (i == transformations.size() - 1 ? "" : "\n");
        }
        return r;
    }
}
class EnemyPatternProperties {
    int spawnMode;
    float difficulty, range, rotationSnapping;
    boolean disableRandomRotation, disableRotationStacking, evenSpacing;
    PVector distBounds, speedBounds, countBounds, scaleBounds, angleSweep;
    ChainedTransformation defaultTransformation;
    EnemyPatternProperties(float difficulty, ChainedTransformation defaultTransformation) {
        this.difficulty = difficulty;
        this.defaultTransformation = defaultTransformation;
    }
    String toString() {
        return String.format(
            "Difficulty: %s"+
            "\nParametric Angle Bounds: %s"+
            "\nImplicit coordinate range: %s"+
            "\nRotation Snapping: %s"+
            "\nModifiers: [spawnMode=%s, disableRandomRotation=%s, disableRotationStacking=%s, evenSpacing=%s]"+
            "\nBounds:"+
            "\n\tCount Bounds: %s"+
            "\n\tSpeed Bounds: %s"+
            "\n\tDist  Bounds: %s"+
            "\n\tScale Bounds: %s"+
            "\nDefault Transformations:%s",
            difficulty, angleSweep, range, rotationSnapping, spawnMode, disableRandomRotation, disableRotationStacking, evenSpacing, countBounds, speedBounds, distBounds, scaleBounds,
            (defaultTransformation.transformations.size() > 0 ? ('\n' + defaultTransformation.toString().replaceAll("(?m)^", "\t")) : " None")
        );
    }
}
class Equation {
    final static int IMPLICIT   = 0;
    final static int PARAMETRIC = 1;

    int type;
    String ID, equationPrintable;

    EnemyPatternProperties spawnProperties;
    Equation(int type, String ID, String equationPrintable, EnemyPatternProperties spawnProperties) {
        this.type = type;
        this.ID = ID;
        this.equationPrintable = equationPrintable;
        this.spawnProperties = spawnProperties;
    }
    String toString() {
        return String.format(
            "%s:\n\tEquation: %s\n\tProperties:\n%s",
            ID, equationPrintable, spawnProperties.toString().replaceAll("(?m)^", "\t\t")
        );
    }
    String toShortString() {
        return String.format("\"%s\": %s", ID, equationPrintable);
    }
}
class Equation1D extends Equation { //1 output dimension; implicit equation
    String equationStr;
    Expression equation;
    Equation1D(String ID, EnemyPatternProperties spawnProperties, String eq) {
        super(IMPLICIT, ID, eq, spawnProperties);
        equation = new ExpressionBuilder(eq).functions(customEquationFunctions).variables("x", "y").build();
    }
    float getVal(float x, float y, float t) {
        return (float)equation.setVariable("x", x).setVariable("y", y).setVariable("t", t).evaluate();
    }
}
class Equation2D extends Equation { //2 output dimensions; parametric equation
    String equationXStr, equationYStr;
    Expression equationX, equationY;
    float[] distanceIntegral;
    Equation2D(String ID, EnemyPatternProperties spawnProperties, String eqX, String eqY) {
        super(PARAMETRIC, ID, String.format("[%s, %s]", eqX, eqY), spawnProperties);
        equationX = new ExpressionBuilder(eqX).functions(customEquationFunctions).variables("x", "y", "t").build();
        equationY = new ExpressionBuilder(eqY).functions(customEquationFunctions).variables("x", "y", "t").build();
    }
    PVector getVal(float x, float y, float t) {
        return new PVector(
            (float)equationX.setVariable("x", x).setVariable("y", y).setVariable("t", t).evaluate(),
            (float)equationY.setVariable("x", x).setVariable("y", y).setVariable("t", t).evaluate()
        );
    }
}


float getWeighedRandom(RNG rng, float difficulty, float intensity) {
    return 1 - pow(rng.rand(), max(0.85, difficulty * intensity));
}
class SpawnPattern {
    String ID;
    String[] choices;
    float[]  probs;
    SpawnPattern(String ID, String[] choices, float[] probs) {
        this.ID = ID;
        this.choices = choices;
        this.probs = normalizeProportions(probs);
        
        int[] sortOrder = reverse(getSortIndices(this.probs));
        this.probs = sortByIndicies(this.probs, sortOrder);
        this.choices = sortByIndicies(this.choices, sortOrder);
    }
    String generate(RNG rng, float difficulty, float intensity) {
        return choices[getProportionIndex(probs, getWeighedRandom(rng, difficulty, intensity))];
    }
    String toString() {
        String r = "";
        for(int i = 0; i < choices.length; i++) {
            r += format("%s (%s%%)", choices[i], new DecimalFormat("###.###").format(100 * probs[i]));
            if(i != choices.length - 1) r += ", ";
        }
        return r;
    }
}
class PatternSpawner {
    final static int INTERCEPT_DEFAULT = 0;
    final static int INTERCEPT_ENTER   = 1;
    final static int INTERCEPT_EXIT    = 2;

    boolean disableNegativeSpawnTimeExclusion;

    ArrayList<Equation> locations;
    ArrayList<Equation2D> velocities;
    HashMap<String, Equation>   locIDMap;
    HashMap<String, Equation2D> velIDMap;
    HashMap<String, SpawnPattern> categories;
    HashMap<String, SpawnPattern> locVelMap;
    
    void decompositJSONCategory(JSONObject json, HashMap<String, SpawnPattern> categories) { //took me way too long to make
        for(Object key_temp : json.keys()) {
            String category_name = (String)key_temp;
            for(String key : splitTrim(category_name, ",")) {
                StringList names = new StringList();
                FloatList probs = new FloatList();
                if(isJSONObject(json, category_name)) {
                    JSONObject innerJSON = json.getJSONObject(category_name);
                    for(Object key_inner_temp : innerJSON.keys()) {
                        String inner_name = (String)key_inner_temp;
                        float prob = innerJSON.getFloat(inner_name);
                        for(String name : splitTrim(inner_name, ",")) {
                            names.append(name);
                            probs.append(prob);
                        }
                    }
                }else{
                    String keyVal = json.getString(category_name);
                    for(String name : splitTrim(keyVal, ",")) {
                        names.append(name);
                        probs.append(1);
                    }
                }
                categories.put(key, new SpawnPattern(key, names.array(), probs.array()));
            }
        }
    }

    PatternSpawner(String filename) {
        locations  = new ArrayList();
        velocities = new ArrayList();
        locIDMap   = new HashMap();
        velIDMap   = new HashMap();
        categories = new HashMap();
        locVelMap  = new HashMap();

        String jsonString = "";
        for(String s : loadStrings(filename)) {
            String t = trim(s);
            if(t.length() > 0 && !(t.length() > 1 && t.charAt(0) == '/' && t.charAt(1) == '/')) {
                jsonString += s + '\n';
            }
        }

        JSONObject json = parseJSONObject(jsonString);
        JSONObject jsonLocs = json.getJSONObject("location");
        JSONObject jsonVels = json.getJSONObject("velocity");
        JSONObject jsonCategories = json.getJSONObject("categories");
        JSONObject jsonLocVelMap  = json.getJSONObject("locVelMap" );

        for(Object key_temp : jsonLocs.keys()) {
            try {
                String key = (String)key_temp;
                JSONObject jVal = jsonLocs.getJSONObject(key);
                Equation loc = parsePattern(jVal, key, false); 
                locations.add(loc);
                locIDMap.put(loc.ID, loc);
            } catch(Throwable t) { logmsg("Failed to parse location pattern: " + t.toString()); }
        }
        for(Object key_temp : jsonVels.keys()) {
            try {
                String key = (String)key_temp;
                JSONObject jVal = jsonVels.getJSONObject(key);
                Equation2D vel = (Equation2D)parsePattern(jVal, key, true);
                velocities.add(vel);
                velIDMap.put(vel.ID, vel);
            } catch(Throwable t) { logmsg("Failed to parse velocity pattern: " + t.toString()); }
        }
        
        decompositJSONCategory(jsonCategories, categories);
        decompositJSONCategory(jsonLocVelMap , locVelMap);
        
        for(Map.Entry<String, SpawnPattern> entry : categories.entrySet()) {
            logf("Category %s: %s", entry.getKey(), entry.getValue());
        }
        for(Map.Entry<String, SpawnPattern> entry : locVelMap.entrySet()) {
            logf("Location %s: %s", entry.getKey(), entry.getValue());
        }
        
    }

    ArrayList<Enemy> makePattern(GameMap gameMap, String loc, String vel, RNG rng, float time, float intensity, float difficulty) {
        return generatePattern(locIDMap.get(loc), velIDMap.get(vel), gameMap, rng, time, intensity, difficulty);
    }
    ArrayList<Enemy> makePatternFromLocation(GameMap gameMap, String loc, RNG rng, float time, float intensity, float difficulty) {
        return makePattern(gameMap, loc, locVelMap.get(loc).generate(rng, difficulty, intensity), rng, time, intensity, difficulty);
    }
    ArrayList<Enemy> makePatternFromCategory(GameMap gameMap, String categoryName, RNG rng, float time, float intensity, float difficulty) {
        return makePatternFromLocation(gameMap, categories.get(categoryName).generate(rng, difficulty, intensity), rng, time, intensity, difficulty);
    }

    Equation parsePattern(JSONObject pattern, String ID, boolean isVelocityPattern) throws Exception {        
        int equationType;

        float difficulty = jsonVal(pattern, "difficulty", 0);
        
        String equationImp = null, equationX = null, equationY = null;
        if(pattern.isNull("equation")) {
            equationType = Equation.PARAMETRIC;
            if(pattern.isNull("equationX") || pattern.isNull("equationY")) {
                throw new Exception("Pattern Parsing Error: Could not find equation");
            }
            equationX = pattern.getString("equationX");
            equationY = pattern.getString("equationY");
        }else{
            equationType = Equation.IMPLICIT;
            if(isVelocityPattern) {
                throw new Exception("Pattern Parsing Error: Implicit equation used for velocity");
            }
            equationImp = pattern.getString("equation");
        }

        ChainedTransformation transformations = new ChainedTransformation(new ArrayList());
        EnemyPatternProperties properties = new EnemyPatternProperties(difficulty, transformations);
        Equation equation;
        if(equationType == Equation.PARAMETRIC) {
            equation = new Equation2D(ID, properties, equationX, equationY);
            properties.angleSweep = defaultParse2D(pattern, "angleSweep", vec2(-PI, PI));
        }else{
            equation = new Equation1D(ID, properties, equationImp);
        }

        properties.countBounds = defaultParse(pattern, "countBounds", isVelocityPattern ? vec3(1) : (equationType == Equation.PARAMETRIC ? vec3(25) : vec3(5)));
        properties. distBounds = defaultParse(pattern, "distBounds" , vec3(0));
        properties.scaleBounds = defaultParse(pattern, "scaleBounds", vec3(1));
        properties.speedBounds = defaultParse(pattern, "speedBounds", vec3(1));
        properties.rotationSnapping = jsonVal(pattern, "rotationSnapping", 0);
        properties.spawnMode        = jsonVal(pattern, "spawnMode"       , isVelocityPattern ? -1 : 0);
        if(!isVelocityPattern) properties.range = jsonVal(pattern, "range", 1);

        if(!pattern.isNull("transform")) {
            JSONArray transformList = pattern.getJSONArray("transform");
            for(int i = 0; i < transformList.size(); i++) {
                JSONObject cur = transformList.getJSONObject(i);
                String transformationType = (String)cur.keys().iterator().next();
                String transformationValue = cur.getString(transformationType);
                switch(transformationType) {
                    case "scale": {
                        transformations.transformations.add(new Scale(parseBounds2D(transformationValue)));
                    } break;
                    case "rotate": {
                        transformations.transformations.add(new Rotate(float(transformationValue)));
                    } break;
                    case "translate": {
                        transformations.transformations.add(new Translate(parseBounds2D(transformationValue)));
                    } break;
                }
            }
        }
        if(isVelocityPattern) properties.evenSpacing = true;
        if(!pattern.isNull("modifiers")) {
            for(String s : pattern.getJSONArray("modifiers").getStringArray()) {
                switch(s) {
                    case "disableRandomRotation": {
                        properties.disableRandomRotation = true;
                    } break;
                    case "disableRotationStacking": {
                        properties.disableRotationStacking = true; 
                    } break;
                    case "evenSpacing": {
                        properties.evenSpacing = true; 
                    } break;
                    case "disableEvenSpacing": {
                        properties.evenSpacing = false;
                    } break;
                }
            }
        }

        return equation;
    }
    
    PVector defaultParse(JSONObject json, String s, PVector alternate) throws Exception {
        return json.isNull(s) ? alternate : parseBounds(json.getString(s));
    }
    PVector parseBounds(String s) throws Exception {
        String[] spl = split(s, ',');
        float[] vals = new float[spl.length];
        for(int i = 0; i < vals.length; i++) {
            vals[i] = float(trim(spl[i]));
        }
        if(vals.length == 1) return new PVector(vals[0], vals[0]                , vals[0]);
        if(vals.length == 2) return new PVector(vals[0], (vals[0] + vals[1]) / 2, vals[1]);
        if(vals.length >= 3) return new PVector(vals[0], vals[1]                , vals[2]);
        throw new Exception("Pattern Parsing Error: Couldn't parse bounds");
    }
    PVector defaultParse2D(JSONObject json, String s, PVector alternate) throws Exception {
        return json.isNull(s) ? alternate : parseBounds2D(json.getString(s));
    }
    PVector parseBounds2D(String s) throws Exception {
        String[] spl = split(s, ',');
        float[] vals = new float[spl.length];
        for(int i = 0; i < vals.length; i++) {
            vals[i] = float(trim(spl[i]).toLowerCase().replace("pi", str(PI)));
        }
        if(vals.length == 1) return new PVector(vals[0], vals[0]);
        if(vals.length == 2) return new PVector(vals[0], vals[1]);
        throw new Exception("Pattern Parsing Error: Couldn't parse bounds");
    }

    ArrayList<Enemy> generatePattern(Equation locEq, Equation2D velEq, GameMap gameMap, RNG rng, float time, float intensity, float difficulty) {
        EnemyPatternProperties locationProps = locEq.spawnProperties;
        EnemyPatternProperties velocityProps = velEq.spawnProperties;
        ArrayList<PVector> locs = new ArrayList();
        ArrayList<PVector> vels = new ArrayList();
        
        float[] lerps = new float[3];
        for(int i = 0; i < lerps.length; i++) lerps[i] = getWeighedRandom(rng, intensity, difficulty);
        
        int   count        = round(lerpCentered(locationProps.countBounds, lerps[0]) * lerpCentered(velocityProps.countBounds, lerps[0]));
        float speed        =       lerpCentered(velocityProps.speedBounds, lerps[1]) * lerpCentered(locationProps.speedBounds, lerps[1]) ;
        float locScale     =       lerpCentered(locationProps.scaleBounds, lerps[2]) * lerpCentered(velocityProps.scaleBounds, lerps[2]) ;

        PVector locDistAdj = new PVector(
            0.5 * rng.randSgn(lerpCentered(locationProps.distBounds, rng.rand()) * gameMap.gameDisplaySize.x),
            0.5 * rng.randSgn(lerpCentered(locationProps.distBounds, rng.rand()) * gameMap.gameDisplaySize.y)
        );
        PVector velDistAdj = rng.randVec(0.5 * lerpCentered(velocityProps.distBounds, rng.rand()));
        
        float locRotation = rng.randCentered(PI);
        float velRotation = rng.randCentered(PI);
        if(locationProps.rotationSnapping > 0) locRotation = roundArbitrary(locRotation, TWO_PI / locationProps.rotationSnapping);
        if(velocityProps.rotationSnapping > 0) velRotation = roundArbitrary(velRotation, TWO_PI / velocityProps.rotationSnapping);
        if(locEq.type == Equation.PARAMETRIC) {
            Equation2D parEq = (Equation2D)locEq;
            if(locationProps.evenSpacing && velocityProps.evenSpacing) {
                int precision = 1000;
                if(parEq.distanceIntegral == null) {
                    parEq.distanceIntegral = new float[precision];
                    float multiplier = (1.0 / precision) * (locationProps.angleSweep.y - locationProps.angleSweep.x);
                    for(int i = 0; i < precision; i++) {
                        parEq.distanceIntegral[i] = PVector.dist(
                            parEq.getVal(0, 0, locationProps.angleSweep.x + multiplier * (i    )),
                            parEq.getVal(0, 0, locationProps.angleSweep.x + multiplier * (i + 1))
                        );
                    }
                    accumulate(parEq.distanceIntegral);
                }
                
                float j = 0, distTarget = parEq.distanceIntegral[precision - 1] / count;
                for(int i = 0; i < precision; i++) {
                    float offset = parEq.distanceIntegral[i] - j - distTarget;
                    if(offset > -0.001) {
                        float ang = map(i - offset, 0, precision - 1, locationProps.angleSweep.x, locationProps.angleSweep.y);
                        PVector loc = locationProps.defaultTransformation.apply(parEq.getVal(0    , 0    , ang));
                        PVector vel = velocityProps.defaultTransformation.apply(velEq.getVal(loc.x, loc.y, ang));
                        locs.add(loc);
                        vels.add(vel);
                        j = parEq.distanceIntegral[i] - offset;
                    }
                }
            }else{
                for(int i = 0; i < count; i++) {
                    float t = map(i, 0, max(count - 1, 1), locationProps.angleSweep);
                    PVector loc = locationProps.defaultTransformation.apply(parEq.getVal(0, 0, t));
                    locs.add(loc);
                    vels.add(velocityProps.defaultTransformation.apply(velEq.getVal(loc.x, loc.y, t)));
                }
            }
        }else if(locEq.type == Equation.IMPLICIT) {
            Equation1D impEq = (Equation1D)locEq;
            for(int i = 0; i < count; i++) {
                float x = map(i, 0, max(count - 1, 1), -locationProps.range, locationProps.range);
                for(int o = 0; o < count; o++) {
                    float y = map(o, 0, max(count - 1, 1), -locationProps.range, locationProps.range);
                    if(impEq.getVal(x, y, atan2(y, x)) > 0.0001) continue;
                    PVector loc = locationProps.defaultTransformation.apply(new PVector(x, y));

                    locs.add(loc);
                    vels.add(velocityProps.defaultTransformation.apply(velEq.getVal(loc.x, loc.y, loc.heading()))); //im just gonna assume .heading will work
                }
            }
        }

        for(int i = 0; i < locs.size(); i++) {
            PVector loc = locs.get(i).mult(locScale);
            PVector vel = vels.get(i).mult(speed   );
            
            if(!locationProps.disableRandomRotation) {
                loc.rotate(locRotation);
                if(!velocityProps.disableRotationStacking) {
                    vel.rotate(locRotation);
                }
            }
            if(!velocityProps.disableRandomRotation) {
                vel.rotate(velRotation);
            }
            
            vel.add(velDistAdj);
        }

        ArrayList<Enemy> enemies = new ArrayList();
        for(int i = 0; i < locs.size(); i++) {
            PVector loc = locs.get(i);
            PVector vel = vels.get(i);
            if(vel.mag() <= 0.01) {
                // logmsg(String.format("Enemy was excluded for having low or zero velocity: [t=%ss] ([%s, %s], [%s, %s])", time, loc.x, loc.y, vel.x, vel.y));
                continue;
            }
            
            loc.mult(gameMap.field.minCenterSize / 3.0).add(gameMap.gameCenter).add(locDistAdj);
            if(!velRectIntersection(loc, vel, gameMap.gameSize, gameMap.gameCenter)) {
                // logmsg(String.format("Enemy was excluded for having no intersection with play area: [t=%ss] ([%s, %s], [%s, %s])", time, loc.x, loc.y, vel.x, vel.y));
                continue;
            }

            enemies.add(new Enemy(loc, vel));
        }

        int spawnMode = velocityProps.spawnMode == -1 ? locationProps.spawnMode : velocityProps.spawnMode;
        if(spawnMode == 3) {
            spawnMode = int(rng.random(3));
        }else if(spawnMode == 4) {
            spawnMode = rng.randBool() ? 1 : 2;
        }
        PVector locOffset = null;
        if(spawnMode != INTERCEPT_DEFAULT) {
            int middleIndex = locs.size() / 2;
            PVector loc = locs.get(middleIndex);
            PVector vel = vels.get(middleIndex);
            PVector adjustedGameSize = PVector.sub(gameMap.gameSize, vec2(GAME_MARGIN_SIZE * 2));
            locOffset = lineRectIntersectionPoint(loc, vel, adjustedGameSize, gameMap.gameCenter);
            locOffset = lineRectIntersectionPoint(locOffset, PVector.mult(vel, -1), adjustedGameSize, gameMap.gameCenter);
            if(spawnMode == INTERCEPT_EXIT) {
                locOffset = lineRectIntersectionPoint(locOffset, vel, adjustedGameSize, gameMap.gameCenter);
            }
            locOffset.sub(loc);
        }else{
            locOffset = new PVector(0, 0);
        }
        
        if(enemies.size() > 0) {
            String spawnInfo = format("%s | %s", locEq.ID, velEq.ID);
            for(int i = enemies.size() - 1; i >= 0; i--) {
                Enemy e = enemies.get(i);
                e.loc.add(locOffset);
                
                e = gameMap.createEnemy(e, time);
                enemies.set(i, e);
                e.spawnInfo = spawnInfo;
                
                if(e.spawnTime < 0 && !disableNegativeSpawnTimeExclusion) {
                    // logmsg(String.format("Enemy was excluded for being on screen at song start: [t=%ss] (%s)", time, e));
                    enemies.remove(i);
                }
            }
        }
        return enemies;
    }   
}