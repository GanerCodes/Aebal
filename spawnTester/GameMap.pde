import java.util.Comparator;

class Enemy {
    PVector loc, vel;
    float spawnTime, despawnTime, velOffset;
    GameMap gameMap;
    Enemy(GameMap gameMap, PVector loc, PVector vel, float spawnTime, float despawnTime) {
        this(loc, vel);
        init(gameMap, spawnTime, despawnTime);
    }
    Enemy(PVector loc, PVector vel) {
        this.loc = loc;
        this.vel = vel;
    }
    void init(GameMap gameMap, float spawnTime, float despawnTime) {
        this.gameMap = gameMap;
        this.spawnTime = spawnTime;
        this.despawnTime = despawnTime;
        velOffset = gameMap.getIntegralVal(gameMap.SPS * spawnTime);
    }
    PVector getLoc(float currentTime) {
        return PVector.add(
            loc, PVector.mult(
                vel, gameMap.getIntegralVal(gameMap.SPS * currentTime) - velOffset
            )
        );
    }
    String toString() {
        return String.format("Pos: (%f, %f), Vel: (%f, %f), SpawnTime: %f", loc.x, loc.y, vel.x, vel.y, spawnTime);
    }
}

class GameMap {
    

    int SPS, formCount, spawnIndex;
    float finalIntegralValue, songDuration, defaultSpeed, dt, marginSize, difficulty;
    String songName;
    PVector gameDisplaySize, gameSize, gameCenter;
    float[] velArr, integralArr, complexityArr;
    
    RNG rng;
    AudioPlayer song;
    PatternSpawner spawner;
    ArrayList<Enemy> enemies;
    Enemy[] enemySpawns;

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
            for(int o = 0; o < buffer.length; o++) {
                int indx = i * SAMPLES_PER_SECOND + o;
                if(indx == samples.length) break;
                buffer[o] = samples[i * SAMPLES_PER_SECOND + o];
            }
            complexityArr[i] = findComplexity(buffer);
        }
    }
    GameMap(String songName, String patternFileName, PVector gameSize, RNG rng, float difficulty) {
        init(gameSize);
        this.songName = songName;
        this.difficulty = difficulty;
        this.rng = rng;

        song = minim.loadFile(songName);
        prepareSong(minim.loadSample(songName));
        spawner = new PatternSpawner(patternFileName);
        generateEnemies();
    }
    float[] generateVels() {
        float[] velArr = new float[SAMPLES_PER_SECOND * int(songDuration)];
        for(int i = 0; i < velArr.length; i++) {
            velArr[i] = defaultSpeed + 1000 * (complexityArr[int(map(i, 0, velArr.length, 0, complexityArr.length))]);
        }
        return velArr;
    }
    void createPattern(float time, float intensity, int intercept) {
        enemies.addAll(spawner.spawnPattern(this, rng, time, 1, difficulty, intercept));
    }
    void createPattern(String category, float time, float intensity, int intercept) {
        enemies.addAll(spawner.spawnPattern(this, category, rng, time, 1, difficulty, intercept));
    }
    void createPattern(String locEqName, String velEqName, float time, float intensity, int intercept) {
        enemies.addAll(spawner.spawnPattern(this, locEqName, velEqName, rng, time, 1, difficulty, intercept));
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

        float intensityScale = 1 / average + 2.25 * totalComplexity;
        { //Beat detection [AIDS WARNING]
            int minSeg = iSec / 3;                         //iSec / 3 - Defines the smallest duration between a beat pattern as 1s / x
            int maxSeg = 5 * iSec;                         //5 * iSec - How many seconds foward can the next beat in the pattern be. Note, setting this higher can yeilds better results on songs with a non-linear but repeating beat
            float thresComplexityMultiplier = 2;           //2 - How high the variance needs to be for a beat
            float lookaheadStackedDivider = pow(2, 2);     //2 ^ 2 - How close to start looking for stacked patterns, just leave at 2 honestly 
            float spawnTimeDeltaRemoval = iSec / 9;        //iSec / 15 - How close together two beats have to be to be considered the same beat
            int minConsecutiveBeats = 5;                   //5 - At least this many beats in a row for it to be considered
            int beatDurDelMaxChange = int(minSeg / 2) - 1; //int(minSeg / 2) - how far a beat can be offset from a previous beat. Note, this being larger than the minSeg / 2 can lead to an infinite loop as a pattern keeps backtracking into the previous pattern.

            IntList avoidTimings = new IntList();
            float thres = average + totalComplexity * thresComplexityMultiplier; //Threshold for being a beat
            for(int i = 0; i < complexityArr.length; i++) {
                float c = complexityArr[i];
                if(c > thres) {
                    BTD: for(int o = minSeg; o < maxSeg; o++) { //Range of beat durations
                        IntList beats = new IntList();
                        int beatInc = o;
                        int t = o;
                        beatCounter: while(true) { //Start counting beats
                            if(!GTLT(i + t, beatDurDelMaxChange, complexityArr.length - beatDurDelMaxChange) || complexityArr[i + t] < thres) { //Verify that beat is within thres and not outside the song
                                if(beats.size() > minConsecutiveBeats) { //Make sure we have enough beats to be considered a pattern
                                    for(int beatTime : beats) { //Itterate all detected beats in pattern
                                        boolean marker = false; //Marker because you still need to add this beat to the list but not itterate through it.
                                        for(int avoidTime : avoidTimings) { //Verify that this beat isn't too close to any other beats
                                            if(abs(beatTime - avoidTime) < spawnTimeDeltaRemoval) {
                                                marker = true;
                                                break;
                                            }
                                        }
                                        avoidTimings.append(beatTime);
                                        if(marker) continue;

                                        createPattern("beat", beatTime * sampSecFactor, complexityArr[beatTime] * intensityScale, PatternSpawner.INTERCEPT_DEFAULT);
                                        // enemies.add(createEnemy(vec2(gameSize.x, height / 2), vec2(1, 0), beatTime * sampSecFactor));
                                    }
                                    i += int(iSec / lookaheadStackedDivider);
                                    o += int(iSec / lookaheadStackedDivider);
                                }
                                break beatCounter;
                            }
                            
                            if(i + t + 2 * beatInc + beatDurDelMaxChange + 1 >= complexityArr.length) {
                                i = complexityArr.length;
                                continue;
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
    Enemy createEnemy(Enemy e, float time) {
        return createEnemy(e.loc, e.vel, time);
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