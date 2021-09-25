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
    }
};

abstract class Transformation {
    abstract PVector apply(PVector p);
}
class Translate extends Transformation {
    PVector loc;
    Translate(PVector loc) {
        this.loc = loc;
    }
    PVector apply(PVector p) {
        p.add(loc);
        return p;
    }
}
class Scale extends Transformation {
    PVector scale;
    Scale(PVector scale) {
        this.scale = scale;
    }
    PVector apply(PVector p) {
        p.add(scale);
        return p;
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
}
class EnemyPatternProperties {
    /**
    Order:
        1. Run equation
        2. Apply the things under "transform"
        3. At this point, calculate the velocity
        4. If enabled in the pattern, apply random rotation
        5. Apply random modifications at this point
        6. Blow up location pattern (factor of 1/4 * min field size), then translate to middle

    song intensity will probs just divide the song intensity by some constant. Maybe some nonlinear properties towards the end to make hard and impossible actually be close to it's title 
    if a bound only has one value, then both bounds are set to that value.
    if a bound is in reverse order, it is applied as such, so that it varies in the opposite way you would expect to the song intensity
    Velocity equations can use x, y, and time. If the location is defined implicity, then the angle from (translated) origin will be used.
    speed is anticipated to be around 1
    Mental reminder to keep count in float form until it's time to itterate so that bounds and stuff work right
    
    //The relationship for song dependant bounding and song intensity would something like this:
    //    song intensity under average: lerp(min, default, intensity / average)
    //    song intensity after average: lerp(default, max, m)
    //        m = nonlinear function that starts slowish and increases faster as it goes along, based on song intensity ranging from average to some high relevent value; output is between 0 and 1, obviously

    [ LV | IP |   ] difficulty              - 0                                                             - a order number rather than value [so having enemies 1 & 2 have difficulty 1 & 2 isn't diffrent from difficulty 1 & 500], basically higher value = less likely to spawn / will spawn more likely on higher song intensity. This is also applied when picking a velocity pattern from the list
    [ LV | IP |   ] disableRandomRotation   - false                                                         - disable randomized rotation
    [  V | IP ]   ] disableRotationStacking - false                                                         - prevents random rotation of spawn pattern [if enabled] from alterning the velocity spawning
    [ L  | IP |   ] defaultCount            - I: 4; P: 16                                                   - standard number of enemies [note, on implicit equations it represents the step count in both the x and y directions, basically sqrt() the expected count]
    [ L  | IP | * ] countBounds             - I: (3, 5); P: (7, 25)                                         - enemy count range, depends mostly on current song intensity
    [ LV | IP | * ] distBounds              - (0.2, 0.8)                                                    - distance range to add to starting [after default translate value] location (Location: 1.0 is gameHeight (no margins) / 2 , Velocity: 1.0 is 1.0)
    [  V |  P | * ] speedBounds             - (0.5, 1.5); (defaultSpeed / 2, defaultSpeed * 2) if available - speed range, depends mostly on current song intensity
    [ LV | IP | * ] scaleBounds             - (0.5, 1.5)                                                    - scale multiplier range, depends mostly on current song intensity, applied after default scale adjustments but before rotation and translate [obviously]
    [ LV | IP |   ] defaultScale            - 1                                                             - default scale multiplier
    [  V |  P |   ] defaultSpeed            - MidPoint of speedBounds                                       - default multiplier applied to velocity
    [ L  | I  |   ] range                   - 1                                                             - graph scaling factor; 1 yeilds analyzing the equation from -1 to 1 on both the X and Y directions, while 2 would be -2 to 2. Mental note: use lerp again and keep origional ordering xd
    [ LV |  P |   ] angleSweep              - -PI, PI                                                       - the values t will range from; mental note: keep order as is, use lerp to calculate t, making sure that both endpoints are included.
    
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
            scaleBounds: [0.5, 2]
            modifiers: ["disableRandomRotation", ...],
        }
    },
    "velPatterns": {
        "examplevelPatternhaha": {
            equationX: "x + t + y",
            equationY: "max(2, y / x * sin(x))",
            defaultSpeed: "1",
            speedBounds: [0.8, 1.5],
            angleSweep: "0, 1",
            modifiers: ["disableRandomRotation", "disableRotationStacking"],
        }
    }
    **/
    float difficulty, range;
    boolean disableRandomRotation, disableRotationStacking;
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
class Equation1D extends Equation { //1 output dimension; implicit equation
    String equationStr;
    Expression equation;
    Equation1D(String ID, String[] relatedEquationNames, EnemyPatternProperties spawnProperties, String eq) {
        super(IMPLICIT, ID, relatedEquationNames, eq, spawnProperties);
        equation = new ExpressionBuilder(eq).functions(customEquationFunctions).variables("x", "y").build();
    }
    float getVal(float x, float y, float t) {
        return (float)equation.setVariable("x", x).setVariable("y", y).setVariable("t", t).evaluate();
    }
}
class Equation2D extends Equation { //2 output dimensions; parametric equation
    String equationXStr, equationYStr;
    Expression equationX, equationY;
    Equation2D(String ID, String[] relatedEquationNames, EnemyPatternProperties spawnProperties, String eqX, String eqY) {
        super(PARAMETRIC, ID, relatedEquationNames, String.format("[%s, %s]", eqX, eqY), spawnProperties);
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
class EquationDifficultySorter implements Comparator<Equation> {
    @Override
    int compare(Equation a, Equation b) {
        return Float.compare(a.spawnProperties.difficulty, b.spawnProperties.difficulty);
    }
}

class PatternSpawner {
    ArrayList<Equation> locations;
    ArrayList<Equation2D> velocities;
    HashMap<String, Equation>   locIDMapping;
    HashMap<String, Equation2D> velIDMapping;
    HashMap<String, ArrayList<Equation2D>> locIDVelMapping;

    PatternSpawner(String filename) {
        ArrayList<Equation>   locations  = new ArrayList();
        ArrayList<Equation2D> velocities = new ArrayList();

        String jsonString = "";
        for(String s : loadStrings(filename)) {
            String t = trim(s);
            if(!(t.charAt(0) == '/' && t.charAt(1) == '/')) jsonString += s + '\n';
        }

        JSONObject json = parseJSONObject(jsonString);
        JSONObject locationPatterns = json.getJSONObject("location");
        JSONObject velocityPatterns = json.getJSONObject("velocity");

        for(Object key : locationPatterns.keys()) {
            String k = (String)key;
            locations .add(            parsePattern(locationPatterns.getJSONObject(k), k, false));
        }
        for(Object key : velocityPatterns.keys()) {
            String k = (String)key;
            velocities.add((Equation2D)parsePattern(velocityPatterns.getJSONObject(k), k, true ));
        }

        init(locations, velocities);
    }

    Equation parsePattern(JSONObject pattern, String ID, boolean isVelocityPattern) {        
        int equationType;

        float difficulty = jsonVal(pattern, "difficulty", 0);
        String[] relatedEquationNames;
        if(!isVelocityPattern) relatedEquationNames = pattern.getJSONArray("velChoices").getStringArray();
        
        String equation, equationX, equationY;
        if(pattern.isNull("equation")) {
            equationType = Equation.PARAMETRIC;
            if(pattern.isNull("equationX") || pattern.isNull("equationY")) {
                throw new Exception("Pattern Parsing Error: Could not find equation");
            }
            equationX = pattern.getString("equationX");
            equationY = pattern.getString("equationY");
        }else{
            equationType = Equation.IMPLICIT;
            if(isVelocityPattern) throw new Exception("Pattern Parsing Error: Implicit equation used for velocity");
            equation = pattern.getString("equation");
        }

        ChainedTransformation transformations = new ChainedTransformation(new ArrayList());
        EnemyPatternProperties properties = new EnemyPatternProperties(difficulty, transformations);
        Equation equation;
        if(equationType == Equation.PARAMETRIC) {
            equation = new Equation2D(ID, relatedEquationNames, properties, equationX, equationY);
        }else{
            equation = new Equation1D(ID, relatedEquationNames, properties, equation);
        }

        if(isVelocityPattern) {
            properties.speedBounds = defaultParse(pattern, "speedBounds", vec3(1));
            properties.angleSweep = defaultParse2D(pattern, "angleSweep", vec2(-PI, PI));
        }else{
            properties.countBounds = defaultParse(pattern, "countBounds", equationType == Equation.PARAMETRIC ? vec3(25) : vec3(5));
            
        }
        properties. distBounds = defaultParse(pattern, "distBounds" , vec3(0));
        properties.scaleBounds = defaultParse(pattern, "scaleBounds", vec3(1));


        //distBounds, speedBounds, countBounds, scaleBounds, angleSweep;

        return new Equation(0, null, null, null, null);
    }
    
    PVector defaultParse(JSONObject json, String s, PVector alternate) {
        return json.isNull(s) ? alternate : parseBounds(json.getString(s));
    }
    PVector parseBounds(String s) {
        String[] spl = split(s, ',');
        float[] vals = new floats[spl.length];
        for(int i = 0; i < vals.length; i++) {
            vals[i] = float(trim(spl[i]));
        }
        if(vals.length == 1) return new PVector(vals[0], vals[0]                , vals[0]);
        if(vals.length == 2) return new PVector(vals[0], (vals[0] + vals[1]) / 2, vals[1]);
        if(vals.length >= 3) return new PVector(vals[0], vals[1]                , vals[2]);
        throw new Exception("Pattern Parsing Error: Couldn't parse bounds");
    }
    PVector defaultParse2D(JSONObject json, String s, PVector alternate) {
        return json.isNull(s) ? alternate : parseBounds2D(json.getString(s));
    }
    PVector parseBounds2D(String s) {
        String[] spl = split(s, ',');
        if(spl.length < 2) throw new Exception("Pattern Parsing Error: Couldn't parse bounds");
        return new PVector(
            float(trim(spl[0]).toLowerCase().replace("pi", -PI)),
            float(trim(spl[1]).toLowerCase().replace("pi",  PI))
        );
    }
    

    void init(ArrayList<Equation> locations, ArrayList<Equation2D> velocities) {
        this.locations = locations;
        this.velocities = velocities;

        locations.sort(new EquationDifficultySorter());

        velIDMapping = new HashMap<String, Equation2D>();
        locIDMapping = new HashMap<String, Equation  >();
        for(Equation2D velEquation : velocities) velIDMapping.put(velEquation.ID, velEquation);

        locIDVelMapping = new HashMap<String, ArrayList<Equation2D>>();
        for(Equation locEquation : locations) {
            locIDMapping.put(locEquation.ID, locEquation);
            ArrayList<Equation2D> complementVelocities = new ArrayList();
            for(String velName : locEquation.relatedEquationNames) complementVelocities.add(velIDMapping.get(velName));
            complementVelocities.sort(new EquationDifficultySorter());
            locIDVelMapping.put(locEquation.ID, complementVelocities);
        }
    }

    ArrayList<Enemy> spawnPattern(GameMap gameMap, RNG rng, float time, float intensity, float difficulty) {
        //intensity needs to range from 0 to around 1
        //difficulty ranges from 0.1 to 1.0; 0.1 = nearly zero chance of hard pattern; 1.0 = every pattern is the same 
        Equation spawnLocEq = locations.get(int(locations.size() * getWeighedRandom(rng, intensity, difficulty)));
        ArrayList<Equation2D> velEquationChoices = locIDVelMapping.get(spawnLocEq.ID);
        Equation2D spawnVelEq = velEquationChoices.get(int(velEquationChoices.size() * getWeighedRandom(rng, intensity, difficulty)));
        return generatePattern(spawnLocEq, spawnVelEq, gameMap, rng, time, getWeighedRandom(rng, intensity, difficulty));
    }
    ArrayList<Enemy> spawnPattern(GameMap gameMap, String locEqName, String velEqName, RNG rng, float time, float intensity, float difficulty) {
        return generatePattern(locIDMapping.get(locEqName), (Equation2D)locIDMapping.get(velEqName), gameMap, rng, time, getWeighedRandom(rng, intensity, difficulty));
    }

    float getWeighedRandom(RNG rng, float intensity, float difficulty) {
        return 1 - pow(rng.rand(), intensity * difficulty);
    }

    ArrayList<Enemy> generatePattern(Equation locEq, Equation2D velEq, GameMap gameMap, RNG rng, float time, float iLerp) {
        EnemyPatternProperties locationProps = locEq.spawnProperties;
        EnemyPatternProperties velocityProps = velEq.spawnProperties;
        ArrayList<PVector> locs = new ArrayList();
        ArrayList<PVector> vels = new ArrayList();
        
        int   count      = round(lerpCentered(locationProps.countBounds, iLerp)); //defaultCount
        float speed      =       lerpCentered(velocityProps.speedBounds, iLerp);  //defaultSpeed
        float locScale   =       lerpCentered(locationProps.scaleBounds, iLerp);  //defaultScale
        float velScale   =       lerpCentered(velocityProps.scaleBounds, iLerp);  //defaultScale
        float locDistAdj =       lerpCentered(locationProps.distBounds , rng.random()) * gameMap.gameDisplaySize.y;

        float locDistAdjRotation = rng.randCentered(PI);
        float locRotation = rng.randCentered(PI);
        float velRotation = rng.randCentered(PI);

        if(locEq.type == Equation.PARAMETRIC) {
            Equation2D parEq = (Equation2D)locEq;
            for(int i = 0; i < count; i++) {
                float t = map(i, 0, count - 1, locationProps.angleSweep);
                PVector loc = locationProps.defaultTransformation.apply(parEq.getVal(0, 0, t));
                locs.add(loc);
                vels.add(velocityProps.defaultTransformation.apply(velEq.getVal(loc.x, loc.y, t)));
            }
        }else if(locEq.type == Equation.IMPLICIT) {
            Equation1D impEq = (Equation1D)locEq;
            for(int i = 0; i < count; i++) {
                float x = map(i, 0, count - 1, -locationProps.range, locationProps.range);
                for(int o = 0; o < count; o++) {
                    float y = map(o, 0, count - 1, -locationProps.range, locationProps.range);
                    if(impEq.getVal(x, y, atan2(y, x)) > 0) continue;
                    PVector loc = locationProps.defaultTransformation.apply(new PVector(x, y));
                    locs.add(loc);
                    vels.add(velocityProps.defaultTransformation.apply(velEq.getVal(loc.x, loc.y, loc.heading()))); //im just gonna assume .heading will work
                }
            }
        }
        
        for(int i = 0; i < locs.size(); i++) {
            PVector loc = locs.get(i).mult(locScale);
            PVector vel = vels.get(i).mult(velScale);
            
            if(!locationProps.disableRandomRotation) {
                loc.rotate(locRotation);
                if(!velocityProps.disableRotationStacking) {
                    vel.rotate(locRotation);
                }
            }
            if(!velocityProps.disableRandomRotation) vel.rotate(velRotation);
            vel.mult(speed);
        }

        ArrayList<Enemy> enemies = new ArrayList();
        for(int i = 0; i < locs.size(); i++) {
            PVector loc = locs.get(i);
            PVector vel = vels.get(i);
            if(vel.mag() <= 0.01) {
                println(String.format("Enemy ([%s, %s], [%s, %s]) was excluded for having low or zero velocity.", loc.x, loc.y, vel.x, vel.y));
                continue;
            }
            //todo: add field to songmap and have default location multiplier be min fieldsize / 3
            loc.mult(height / 3).add(gameMap.gameCenter).add(PVector.fromAngle(locDistAdjRotation).mult(locDistAdj));
            if(!velRectIntersection(loc, vel, gameMap.gameSize, gameMap.gameCenter)) {
                println(String.format("Enemy ([%s, %s], [%s, %s]) was excluded for having no intersection with play area.", loc.x, loc.y, vel.x, vel.y));
                continue;
            }
            Enemy newEnemy = gameMap.createEnemy(loc, vel, time);
            if(newEnemy.spawnTime < 0) {
                println(String.format("Enemy (%s) was excluded for being on screen at song start.", newEnemy));
                continue;
            }
            enemies.add(newEnemy);
        }
        return enemies;
    }   
}