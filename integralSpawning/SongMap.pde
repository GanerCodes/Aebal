import java.util.Comparator;

class Enemy {
    PVector loc, vel;
    float spawnTime, despawnTime, velOffset;
    GameMap GameMap;
    Enemy(GameMap GameMap, PVector loc, PVector vel, float spawnTime, float despawnTime) {
        this.GameMap = GameMap;
        this.loc = loc;
        this.vel = vel;
        this.spawnTime = spawnTime;
        this.despawnTime = despawnTime;
        velOffset = GameMap.getIntegralVal(GameMap.SPS * spawnTime);
    }
    PVector getLoc(float currentTime) {
        return PVector.add(
            loc, PVector.mult(
                vel, GameMap.getIntegralVal(GameMap.SPS * currentTime) - velOffset
            )
        );
    }
    String toString() {
        return String.format("Pos: (%f, %f), Vel: (%f, %f), SpawnTime: %f", loc.x, loc.y, vel.x, vel.y, spawnTime);
    }
}

class GameMap {
    int SPS, formCount, spawnIndex;
    float finalIntegralValue, songDuration, defaultSpeed, dt, marginSize;
    String songName;
    float[] velArr, integralArr, complexityArr;
    Enemy[] enemySpawns;
    ArrayList<Enemy> enemies;
    AudioPlayer song;
    PVector gameDisplaySize, gameSize, gameCenter;

    class enemySpawnTimeSorter implements Comparator<Enemy> {
        @Override
        int compare(Enemy a, Enemy b) {
            return Float.compare(a.spawnTime, b.spawnTime);
        }
    }

    void init(PVector gameSize) {
        this.marginSize = GAME_MARGIN_SIZE;
        this.gameDisplaySize = gameSize.copy();
        this.gameSize = PVector.add(gameSize, vec2(marginSize * 2));
        this.gameCenter = PVector.mult(gameSize, 0.5);
        SPS = SAMPLES_PER_SECOND;
        dt = 1.0 / SPS;
        defaultSpeed = DEFAULT_SPEED;
    }

    void prepareSong(AudioSample songRaw) {
        float[] leftSamples  = songRaw.getChannel(AudioSample.LEFT );
        float[] rightSamples = songRaw.getChannel(AudioSample.RIGHT);
        float[] samples = new float[rightSamples.length];
        for(int i = 0; i < leftSamples.length; i++) samples[i] = 0.5 * (leftSamples[i] + rightSamples[i]);

        formCount = samples.length / SAMPLES_PER_SECOND;
        songDuration = song.length() / 1000.0;

        complexityArr = new float[formCount];
        float[] buffer = new float[formCount];
        for(int i = 0; i < formCount - 1; i++) {
            for(int o = 0; o < SAMPLES_PER_SECOND; o++) buffer[o] = samples[i * SAMPLES_PER_SECOND + o];
            complexityArr[i] = findComplexity(buffer);
        }
    }
    GameMap(String songName, PVector gameSize) {
        init(gameSize);
        this.songName = songName;

        song = minim.loadFile(songName);
        prepareSong(minim.loadSample(songName));
        generateEnemies();
    }
    float[] generateVels() {
        float[] velArr = new float[SAMPLES_PER_SECOND * int(songDuration)];
        for(int i = 0; i < velArr.length; i++) {
            velArr[i] = defaultSpeed + 200 * (complexityArr[int(map(i, 0, velArr.length, 0, complexityArr.length))]);
        }
        return velArr;
    }
    void addRecentEnemies(float time) {
        while(spawnIndex < enemySpawns.length && time >= enemySpawns[spawnIndex].spawnTime) {
            Enemy e = enemySpawns[spawnIndex];
            if(time < e.despawnTime) enemies.add(e);
            spawnIndex++;
        }
    }
    void removeExpiredEnemies(float time) {
        if(enemies.size() == 0) return;
        for(int i = enemies.size() - 1; i >= 0; i--) {
            if(time >= enemies.get(i).despawnTime) {
                enemies.remove(i);
            }
        }
    }
    void updateEnemies(float time) {
        removeExpiredEnemies(time);
        addRecentEnemies(time);
    }
    void resetEnemies() {
        spawnIndex = 0;
        enemies = new ArrayList<Enemy>();
    }
    void generateEnemies() {
        resetEnemies();

        float average = 0;
        for(int i = 0; i < complexityArr.length; i++) average += complexityArr[i];
        average /= complexityArr.length;
        for(int i = 0; i < complexityArr.length; i++) complexityArr[i] = pow(complexityArr[i] / (2.25 * average), 1.5);
        average = 0;
        for(int i = 0; i < complexityArr.length; i++) average += complexityArr[i];
        average /= complexityArr.length;

        float totalComplexity = findComplexity(complexityArr);

        int iSec = int(complexityArr.length / songDuration); //seconds to sample time
        float sampSecFactor = map(1, 0, complexityArr.length, 0, songDuration); //sample time to seconds

        float boost = 0;
        for(int i = 0; i < complexityArr.length; i++) {
            float c = complexityArr[i] + boost;
            if(c < average) {
                boost = lerp(boost, average / 1.5, sampSecFactor / 20.0);
            }else if(c > average + 1.5 * totalComplexity) {
                boost = 0;
            }
            complexityArr[i] = c + boost;
        }

        generateIntegral(generateVels(), gameSize);

        // EnemyPatternProperties locPtest = new EnemyPatternProperties(0, new ChainedTransformation(new ArrayList<Transformation>()));
        // EnemyPatternProperties velPtest = new EnemyPatternProperties(0, new ChainedTransformation(new ArrayList<Transformation>()));
        // Equation1D loctest = new Equation1D("l", new String[] {"v"}, locPtest, "abs(y + abs(x)) + abs(x) - 1");
        // Equation2D veltest = new Equation2D("v", new String[] {}, velPtest, "-x", "y");
        // ArrayList<Equation> locEtest = new ArrayList();
        // ArrayList<Equation2D> velEtest = new ArrayList();
        // locPtest.range = 1;
        // locPtest.defaultCount = 10;
        // locPtest.distBounds  = vec2(0);
        // locPtest.countBounds = vec2(50);
        // locPtest.scaleBounds = vec2(1);

        // velPtest.defaultSpeed = 5;
        // velPtest.distBounds  = vec2(0);
        // velPtest.speedBounds = vec2(5);
        // velPtest.scaleBounds = vec2(1);
        // velPtest.angleSweep  = vec2(-PI, PI);
        // velPtest.disableRandomRotation = true;
        // locEtest.add(loctest);
        // velEtest.add(veltest);
        // enemies.addAll(new PatternSpawner(locEtest, velEtest).spawnPattern(this, new RNG(), 10, 1, 1));

        enemies.addAll(new PatternSpawner("patterns.json").spawnPattern(this, new RNG(), 10, 1, 1));

        { //Beat detection
            //iSec / 9 - Defines the smallest duration between a beat pattern as 1s / x
            int minSeg = iSec / 2;
            //5 - How many seconds foward can the next beat in the pattern be. Note, setting this higher can yeilds better results on songs with a non-linear but repeating beat
            int maxSeg = 5 * iSec;
            //2 - How high the "variance" needs to be for a beat
            float thresComplexityMultiplier = 2;
            //2 ^ 2 - How close to start looking for stacked patterns, just leave at 2 honestly 
            float lookaheadStackedDivider = pow(2, 2);
            //iSec / 15 - How close together two beats have to be to be considered the same beat
            float spawnTimeDeltaRemoval = iSec / 15;
            //5 - At least this many beats in a row for it to be considered
            int minConsecutiveBeats = 5;
            // int(minSeg / 1.5) - how far a beat can be offset from a previous beat. Note, this being larger than the minSeg / 2 can lead to an infinite loop as a pattern keeps backtracking into the previous pattern.
            int beatDurDelMaxChange = int(minSeg / 2) - 1;

            FloatList avoidTimings = new FloatList();
            float thres = average + totalComplexity * thresComplexityMultiplier; //Threshold for being a beat
            for(int i = 0; i < complexityArr.length; i++) {
                float c = complexityArr[i];
                if(c > thres) {
                    BTD: for(int o = minSeg; o < maxSeg; o++) { //Range of beat durations
                        FloatList beats = new FloatList();
                        int beatInc = o;
                        int t = o;
                        beatCounter: while(true) { //Start counting beats
                            if(!GTLT(i + t, beatDurDelMaxChange, complexityArr.length - beatDurDelMaxChange) || complexityArr[i + t] < thres) { //Verify that beat is within thres and not outside the song
                                if(beats.size() > minConsecutiveBeats) { //Make sure we have enough beats to be considered a pattern
                                    for(float beatTime : beats) { //Itterate all detected beats in pattern
                                        boolean marker = false; //Marker because you still need to add this beat to the list but not itterate through it.
                                        for(float avoidTime : avoidTimings) { //Verify that this beat isn't too close to any other beats
                                            if(abs(beatTime - avoidTime) < spawnTimeDeltaRemoval) {
                                                marker = true;
                                                break;
                                            }
                                        }
                                        avoidTimings.append(beatTime);
                                        if(marker) continue;

                                        enemies.add(
                                            createEnemy(
                                                new PVector(width - 1, height / 2),
                                                new PVector(10, 0),
                                                sampSecFactor * beatTime
                                            )
                                        );
                                    }
                                    i += int(iSec / lookaheadStackedDivider);
                                    o += int(iSec / lookaheadStackedDivider);
                                }
                                break beatCounter;
                            }
                            
                            beats.append(i + t);
                            t += beatInc;

                            float cVal = complexityArr[i + t + beatInc    ]; //Current value
                            float rVal = complexityArr[i + t + beatInc + 1]; //Right value
                            float lVal = complexityArr[i + t + beatInc - 1]; //Left value

                            int beatTimeD2 = 0;
                            if(rVal > cVal && rVal >= lVal) { //Check right for better value
                                for(int offsetter = 1; offsetter < beatDurDelMaxChange; offsetter++) {
                                    float comVal = complexityArr[i + t + offsetter];
                                    if(comVal <= cVal / 2) break;
                                    if(comVal > complexityArr[i + t + beatTimeD2]) {
                                        beatTimeD2 = offsetter;
                                    }
                                }
                            }else if(lVal > cVal) { //Check left for better value
                                for(int offsetter = 1; offsetter < beatDurDelMaxChange; offsetter++) {
                                    float comVal = complexityArr[i + t - offsetter];
                                    if(comVal <= cVal / 2) break;
                                    if(comVal > complexityArr[i + t + beatTimeD2]) {
                                        beatTimeD2 = -offsetter;
                                    }
                                }
                            }
                            t += beatTimeD2;
                            beatInc += beatTimeD2;
                        }
                    }
                }
            }
        }
        enemies.sort(new enemySpawnTimeSorter());
        enemySpawns = enemies.toArray(new Enemy[enemies.size()]);
        enemies = new ArrayList<Enemy>();

    }
    float findComplexity(float[] k) { //Variance calculation
        float adv = 0;
        for (int i = 0; i < k.length; i++) {
            adv += k[i];
        }
        adv /= k.length;
        float complexity = 0;
        for (int i = 0; i < k.length; i++) {
            complexity += abs(k[i] - adv);
        }
        complexity /= k.length;
        return complexity;
    }
    void generateIntegral(float[] velArr, PVector gameSize) {
        integralArr = new float[velArr.length];
        integralArr[0] = 0;
        for(int i = 1; i < integralArr.length; i++) {
            integralArr[i] = integralArr[i - 1] + velArr[i] * dt;
        }
        finalIntegralValue = integralArr[integralArr.length - 1];
    }
    float getIntegralVal(float val) {
        if(val >= integralArr.length) {
            return integralArr[integralArr.length - 1] + (val - integralArr[integralArr.length - 1]) * defaultSpeed * dt;
        }else if(val < 0) {
            return val * defaultSpeed * dt;
        }else{
            return integralArr[int(val)];
        }
    }
    float getIntegralTimeDelta(float checkDist, float checkLocation) {
        if(checkLocation > finalIntegralValue) {
            return integralArr.length + SPS * defaultSpeed;
        }else if(checkLocation < 0) {
            return SPS * checkLocation / defaultSpeed;
        }else{
            for(float i = 0; i < integralArr.length; i++) {
                if(getIntegralVal(i) >= checkLocation) return i;
            }
        }
        return -1;
    }
    Enemy createEnemy(PVector loc, PVector vel, float time) {
        float currentTime = time * SPS;
        float currentVal = getIntegralVal(currentTime);

        float startDist = distToRect(loc, PVector.mult(vel, -1), gameSize, gameCenter) / vel.mag();
        float startCheckLocation = currentVal - startDist;
        float startTime = getIntegralTimeDelta(startDist, startCheckLocation);
        float startVal = getIntegralVal(startTime);
        
        float finalDist = distToRect(loc, vel, gameSize, gameCenter) / vel.mag();
        float finalCheckLocation = currentVal + finalDist;
        float finalTime = getIntegralTimeDelta(finalDist, finalCheckLocation);

        float positionDelta = currentVal - startVal;
        PVector location = PVector.sub(loc, PVector.mult(vel, positionDelta));

        return new Enemy(this, location, vel, startTime / SPS, finalTime / SPS);
    }
}