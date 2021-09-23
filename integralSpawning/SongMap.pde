import java.util.Comparator;

float distToRect(PVector p, PVector v, PVector r) {
    return v.mag() * min(
        abs((sgn(v.x) * p.x - 0.5 * r.x) / v.x),
        abs((sgn(v.y) * p.y - 0.5 * r.y) / v.y)
    );
}

class enemySpawnTimeSorter implements Comparator<Enemy> {
    @Override
    int compare(Enemy a, Enemy b) {
        return Float.compare(a.spawnTime, b.spawnTime);
    }
}

class Enemy {
    PVector loc, vel;
    float spawnTime, velOffset;
    SongMap songMap;
    Enemy(SongMap songMap, PVector loc, PVector vel, float spawnTime) {
        this.songMap = songMap;
        this.loc = loc;
        this.vel = vel;
        this.spawnTime = spawnTime;
        velOffset = songMap.getIntegralVal(songMap.SPS * spawnTime);
    }
    PVector getLoc(float currentTime) {
        return PVector.add(
            loc, PVector.mult(
                vel, songMap.getIntegralVal(songMap.SPS * currentTime) - velOffset
            )
        );
    }
    String toString() {
        return String.format("Pos: (%f, %f), Vel: (%f, %f), SpawnTime: %f", loc.x, loc.y, vel.x, vel.y, spawnTime);
    }
}

class SongMap {
    int SPS, formCount, spawnIndex;
    float finalIntegralValue, songDuration, defaultSpeed, dt;
    String songName;
    float[] velArr, integralArr, complexityArr;
    Enemy[] enemySpawns;
    ArrayList<Enemy> enemies;
    AudioPlayer song;
    PVector screenSize;

    void init(PVector screenSize) {
        this.screenSize = screenSize;

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
    SongMap(String songName, PVector screenSize) {
        init(screenSize);
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
    void addRecentEnemies(float currentTime) {
        while(spawnIndex < enemySpawns.length && enemySpawns[0].spawnTime < currentTime) {
            enemies.add(enemySpawns[spawnIndex]);
            spawnIndex++;
        }
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

        generateIntegral(generateVels(), screenSize);

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
                                            makeAlteredEnemy(
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
    void generateIntegral(float[] velArr, PVector screenSize) {
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
    Enemy makeAlteredEnemy(PVector loc, PVector vel, float time) {
        float currentTime = time * SPS;
        float currentVal = getIntegralVal(currentTime);

        float checkDist = distToRect(loc, PVector.mult(vel, -1), screenSize) / vel.mag();
        float checkLocation = currentVal - checkDist;
        float startTime = getIntegralTimeDelta(checkDist, checkLocation);

        float startVal = getIntegralVal(startTime);
        float timeDelta = (currentTime - startTime) / SPS;
        float positionDelta = currentVal - startVal;

        return new Enemy(this, PVector.sub(loc, PVector.mult(vel, positionDelta)), vel, time - timeDelta);

        // println(String.format("Border distance: %s (loc: %s)", borderDist, PVector.sub(loc, vel.setMag(null, 1.0).mult(borderDist))));
        // println(String.format("finalIntegralValue: %s, checkLocation: %s", finalIntegralValue, checkLocation));
        // float distanceTraveled = initalLoc.dist(loc);
        // float averageVelocity = positionDelta / timeDelta * mag;
        // println(String.format("Integral range: %s --> %s", startTime / SPS, currentTime / SPS));
        // println(String.format("(%s, %s) --> (%s, %s), (%s, %s), Distance Traveled: %s [%s], Spawn time offset: %ss, Average Velocity: %s", initalLoc.x, initalLoc.y, loc.x, loc.y, vel.x, vel.y, distanceTraveled, averageVelocity * timeDelta, timeDelta, averageVelocity));
    }
}