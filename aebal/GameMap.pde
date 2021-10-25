import java.util.Comparator;

void setLoadingText(String s) {
    mapGenerationText = s;
    logmsg("Map Generation: " + s);
}

class GameMap {
    int SPS, formCount, spawnIndex;
    float finalIntegralValue, songDuration, defaultSpeed, dt, marginSize;
    String songName, patternFileName;
    PVector gameDisplaySize, gameSize, gameCenter;
    float[] velArr, integralArr, complexityArr;
    
    RNG rng;
    Music song;
    Field field;
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
        this.field = new Field(gameDisplaySize);
        
        SPS = SAMPLES_PER_SECOND;
        dt = 1.0 / SPS;
        defaultSpeed = DEFAULT_SPEED;
    }

    void prepareSong(AudioSample songRaw) {
        setLoadingText("Calculating intensities");
        float[] leftSamples  = songRaw.getChannel(AudioSample.LEFT );
        float[] rightSamples = songRaw.getChannel(AudioSample.RIGHT);
        float[] samples = new float[rightSamples.length];
        for(int i = 0; i < leftSamples.length; i++) samples[i] = 0.001 + 0.5 * (leftSamples[i] + rightSamples[i]);

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
            complexityArr[i] = difficultySlider.val * variance(buffer) * (1 + rootMeanSquare(buffer)) / 2;
        }
    }
    void loadPatternFile() {
        setLoadingText("Loading patterns");
        spawner = new PatternSpawner(patternFileName);
    }
    void writeEnemiesToFile(String fileName) {
        PrintWriter writer = createWriter(fileName);
        writer.println(format("Random Seed: %s\nDifficulty: %s\nSong: %s\n\n\n", rng.seed, difficultySlider.val, song));
        for(Enemy e : enemySpawns) {
            writer.println(format("%s - %s", e.spawnInfo == null ? "Manual spawn" : e.spawnInfo, e));
        }
    }
    GameMap(String songName, String patternFileName, PVector gameSize, RNG rng) {
        init(gameSize);
        this.songName = songName;
        this.patternFileName = patternFileName;
        this.rng = rng;

        song = new Music(songName, DEFAULT_SONG_GAIN);
        setLoadingText("Loading song");
        prepareSong(minim.loadSample(songName));
        loadPatternFile();
        generateEnemies();
        score = 0;
    }
    void drawIntensityGraph(PGraphics base) {
        base.beginDraw();
        base.strokeCap(SQUARE);
        base.strokeWeight(1);
        base.stroke(255, 0, 0, 128);
        for(int i = 0; i < base.width; i++) {
            float v = 100 * complexityArr[int(map(i, 0, base.width + 1, 0, complexityArr.length))];
            base.line(i, base.height, i, base.height - v);
        }
        base.endDraw();
    }
    float[] generateVels() {
        float[] velArr = new float[SAMPLES_PER_SECOND * int(songDuration)];
        for(int i = 0; i < velArr.length; i++) {
            velArr[i] = defaultSpeed * (1 + difficultySlider.val) + 3 * difficultySlider.val * SPS * complexityArr[int(map(i, 0, velArr.length, 0, complexityArr.length))];
        }
        return velArr;
    }
    void createPattern(String category, float time, float intensity) {
        enemies.addAll(spawner.makePatternFromCategory(this, category , rng, time, intensity, difficultySlider.val));
    }
    void createPattern(String locEqName, String velEqName, float time, float intensity) {
        enemies.addAll(spawner.makePattern(this, locEqName , velEqName, rng, time, intensity, difficultySlider.val));
    }
    void addRecentEnemies(float time) {
        while(spawnIndex < enemySpawns.length && time >= enemySpawns[spawnIndex].spawnTime) {
            Enemy e = enemySpawns[spawnIndex];
            if(time < e.despawnTime && e.spawnTime > 0) {
                enemies.add(e);
                if(LOG_ENEMY_SPAWNS && allowDebugActions && e.spawnInfo != null) logmsg("Spawned Enemy: " + e.spawnInfo);
            }
            spawnIndex++;
        }
    }
    void removeExpiredEnemies(float time) {
        if(enemies.size() == 0) return;
        for(int i = enemies.size() - 1; i >= 0; i--) {
            if(time >= enemies.get(i).despawnTime) {
                enemies.remove(i);
                score++;
            }
        }
    }
    void updateEnemies(float time) {
        removeExpiredEnemies(time);
        addRecentEnemies(time);
    }
    int getIntensityIndex(float time) {
        return constrain(int(1000 * time * complexityArr.length / song.length()), 0, complexityArr.length - 1);
    }
    float getIntensity(float time) {
        return complexityArr[getIntensityIndex(time)];
    }
    void resetEnemiesWithIndex() {
        if(enemySpawns != null) {
            for(int i = 0; i < min(spawnIndex, enemySpawns.length); i++) {
                enemySpawns[i].locCalc = null;
            }
        }
        spawnIndex = 0;
        enemies = new ArrayList<Enemy>();
    }
    void convertEnemiesToArray() {
        enemies.sort(new enemySpawnTimeSorter());
        enemySpawns = enemies.toArray(new Enemy[enemies.size()]);
        resetEnemiesWithIndex();
    }
    void flattenComplexityArr() {
        for(int i = 0; i < complexityArr.length; i++) complexityArr[i] = 0.5;
    }
    void generateTestPattern(String locName, String velName, float time) {
        createPattern(locName, velName, time, 1.0);
    }
    void generateEnemies() {
        resetEnemiesWithIndex();

        setLoadingText("Adjusting intensity");
        float adv = average(complexityArr);
        for(int i = 0; i < complexityArr.length; i++) complexityArr[i] = pow(complexityArr[i] / (2.25 * adv), 1.5);

        float totalComplexity = variance(complexityArr);
        float adjDifficulty = map(difficultySlider.val, difficultySlider.val_min, difficultySlider.val_max, 0.1, 1);

        int iSec = int(complexityArr.length / songDuration);       //seconds -> intTime
        float sampSecFactor = songDuration / complexityArr.length; //intTime -> seconds

        float boost = 0;
        for(int i = 0; i < complexityArr.length; i++) {
            float c = complexityArr[i] + boost;
            if(c < adv) {
                boost = lerp(boost, adv / 1.5, sampSecFactor / 32.0);
            }else if(c > adv + 0.75 * totalComplexity) {
                boost = 0;
            }
            complexityArr[i] = c + boost;
        }

        setLoadingText("Generating position integral");
        generateIntegral(generateVels(), gameSize);
        IntList avoidTimings = new IntList();
        
        { setLoadingText("Adding random enemies");
            float spawnTime = 1;
            for(int i = 0; i < complexityArr.length; i++) {
                float c = complexityArr[i];
                float ct = i * sampSecFactor;
                if(ct >= spawnTime && c > adv - adjDifficulty * totalComplexity) {
                    if(rng.rand() + c > 0.5) {
                        createPattern("common", ct, c);
                    }
                    if(c > adv + totalComplexity && rng.randProp(pow(adjDifficulty, 1.5))) {
                        createPattern("default", ct, c);
                        spawnTime += 2.5 / (c * adjDifficulty);
                    }
                    spawnTime += c / pow(adjDifficulty, 1.75);
                    avoidTimings.append(i);
                }
            }
        }
        
        { setLoadingText("Performing beat detection");    
            int minSeg = iSec / 3;
            int maxSeg = 5 * iSec;
            int minConsecutiveBeats = 5;
            int maxBeatDrift = minSeg / 8;
            float spawnTimeDeltaRemoval = iSec / 6;
            float thres0 = adv + totalComplexity * 1.0;
            float thres1 = adv + totalComplexity * 2.5;

            IntList beatTimes = new IntList();
            for(int i = 0; i < complexityArr.length; i++) {
                for(int o = minSeg; o < maxSeg; o++) {
                    IntList beats = new IntList();
                    int t = o;
                    int beatLength = o;
                    int overallOffset = 0;
                    while(i + t < complexityArr.length - beatLength * 2 && complexityArr[i + t] > thres0) {
                        beats.append(i + t);
                        t += beatLength;
                        // int optimalLocOffset = findLocalMaxOffset(complexityArr, i + t + beatLength, maxBeatDrift);
                        // overallOffset += optimalLocOffset;
                        // if(overallOffset < maxBeatDrift && maxBeatDrift > -maxBeatDrift / 3) beatLength += optimalLocOffset;
                    }
                    if(beats.size() < minConsecutiveBeats) continue;
                    for(int beatTime : beats) {
                        boolean invalidSpawn = false;
                        for(int avoidTime : avoidTimings) {
                            if(abs(beatTime - avoidTime) < spawnTimeDeltaRemoval) {
                                invalidSpawn = true;
                                break;
                            }
                        }
                        avoidTimings.append(beatTime);
                        if(invalidSpawn) continue;
                        beatTimes.append(beatTime);
                    }
                    i += 1 + int(beatLength * 2.5);
                    break;
                }
            }
            
            beatTimes.sort();
            float r = -QUARTER_PI;
            float lastHeavySpawnTime = 0;
            for(int time : beatTimes) {
                if(complexityArr[time] > thres1 && time - lastHeavySpawnTime > 2.5 * iSec / adjDifficulty && rng.randProp(adjDifficulty)) {
                    createPattern("heavyBeat", time * sampSecFactor, complexityArr[time] * (1 + adjDifficulty));
                    lastHeavySpawnTime = time;
                }else{
                    enemies.add(createEnemy(vec2(gameDisplaySize.x / 2, gameDisplaySize.y / 2).add(rng.randVec((1 - adjDifficulty) * gameDisplaySize.y / 1.5)), vec2((1 + difficultySlider.val) / 2, 0).rotate(r), time * sampSecFactor));
                }
                r -= HALF_PI;
            }
        }
        
        convertEnemiesToArray();
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
            return integralArr[integralArr.length - 1] + (val - integralArr.length) * defaultSpeed * dt;
        }else if(val < 0) {
            return val * defaultSpeed * dt;
        }else{
            return integralArr[int(val)]; //lerp(integralArr[floor(val)], integralArr[ceil(val)], val - floor(val));
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
    
    void updateField(PVector playerPos, float time, int mouseX, int mouseY) {
        field.update(playerPos, getIntensity(time), mouseX, mouseY);
    }
    void drawPlayer(PGraphics base, PVector pos, int mouseX, int mouseY) {
        field.drawPlayer(base, pos, mouseX, mouseY);
    }
    void drawField(PGraphics base, PVector pos, int mouseX, int mouseY) {
        field.draw(base, pos, mouseX, mouseY);
    }
    void drawEnemies(PGraphics base, float time, PVector pos, PVector previousPos, color enemyColor, boolean fancy) {
        color green = color(0, 255, 0);
        if(fancy) {
            base.strokeCap(SQUARE);
            base.strokeWeight(20);
            base.stroke(enemyColor);
            base.noFill();
            base.beginShape(LINES);
        }
        for(Enemy e : enemies) {
            if(!e.isGift) e.update(base, time, pos, previousPos, enemyColor, fancy);
        }
        if(fancy) {
            base.endShape();
            base.stroke(green);
        }
        for(Enemy e : enemies) {
            if(e.isGift) e.update(base, time, pos, previousPos, enemyColor, fancy);
        }
        base.endShape();

        base.noStroke();
        for(Enemy e : enemies) {
            base.fill(e.isGift ? green : enemyColor);
            base.circle(e.locCalc.x, e.locCalc.y, 20);
        }
    }
}