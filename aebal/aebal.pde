import com.jogamp.newt.event.MouseEvent;
import org.apache.commons.text.WordUtils;
import java.lang.Math;
import java.util.Map;
import java.nio.file.Files;
import java.nio.file.Paths;

boolean REFRESH_SONG_METADATA = false; //Recheck song metadata, even if found in cache
boolean DO_ENEMY_SPAWNING = true;
float TIMER_UPDATE_FREQUENCY = 500; //Debug timer update rate (millis)
float BACKGROUND_COLOR_FADE = 0.275; //Lerp value
float songComplexity = 0.5;
float FPS = 1000; //Wish I could uncap this
float GAME_MARGIN_SIZE = 25;
float DEFAULT_SPEED = 7.5;
int GAMESELECT_SONGDISPLAYCOUNT = 10; //How many songs in the Song Selector to display up and down
int MAX_SIMULTANEOUS_DAMAGE = 100; //Mono got mad at the circles
int SAMPLES_PER_SECOND = 1024;
int gameWidth = 1920, gameHeight = 1080; //xdd

GameMap gameMap;
SFX hitSound, buttonSFX, textSFX, volChangeSFX, songSelChange, gainScore;
PFont defaultFont, songFont;
PGraphics back, loading_animation_buffer;
boolean intense, allowDebugActions, cancerMode, keydown_SHIFT, checkTimes, songEndScreenSkippable, mouseOverSong, paused, show_fade_in = true;
int patternTestLocIndex, patternTestVelIndex, curX, curY, monitorID, cancerCount, score, hitCount, gameFrameCount, durationInto, levelSummary_timer, activeCursor = ARROW, deltaMillisStart, gameSelect_songSelect_actual, previousCursor = -1, nextVolumeSFXplay = -1, delayedSceneTimer = -1, clearEnemies = -1;
float gameFrameRateTotal, nextFadeTime, scrollWait, fps_tracker, gameSelect_songSelect, gameSelectExtraYOffset, sceneOffsetMillis, c, adv, count, objSpawnTimer, ang, noScoreTimer, millisDelta, fadeDuration = 5000, fadeOpacityStart = 400, fadeOpacityEnd = 0, grayScaleTimer = 100, trailingAngle = 0, trailStrokeWeight = 4.5;
String mapGenerationText, delayedSceneScene, settingsFileLoc, songDataFileLoc, previousScene, gameState = "title";
RNG GFX_R, GAME_R;
PVector pos, previousPos, randTrans, zeroVector, prevTrailLoc, screenSize, trailLoc, chroma_r, chroma_g, chroma_b;
SFX[] soundList;
Minim minim;
color backColor, globalObjColor, trailColor;
PImage screen, text_logo, image_gear, image_back, image_settings, image_paused;
PShader loading_animation, bubbleShader, chroma, reduceOpacity, grayScale, bloom;
DecimalFormat timerFormat;
ArrayList<bubble> bubbles = new ArrayList();
ArrayList<songElement> songList = new ArrayList();
ArrayList<floatingText> floatingPrompts = new ArrayList();
ArrayList<timingDisplayElement> orderedTimingDisplay = new ArrayList(); 
HashMap<String, Long> timingList;
HashMap<String, timingDisplayElement> timingDisplay;
arrow a;
debugList msgList;
settingButton[] settings, settings_left, settings_right;
settingButton DEBUG_INFO, TIMING_INFO, SHOW_SONG_GRAPH, DYNAMIC_BACKGROUND_COLOR, DO_COLORFUL_TRAILS, DO_POST_PROCESSING, DO_FANCY_TRAILS, BACKGROUND_BLOBS, BACKGROUND_FADE, SHOW_SONG_NAME, DO_HIT_PROMPTS, NO_DAMAGE, RGB_ENEMIES, DO_CHROMA, DO_SHAKE, SHOW_FPS;
button settings_button, back_button;
buttonMenu monitorOptions;
vol_slider volSlider;
difficulty_slider difficultySlider;
JSONObject menuSettings, songCache;
asyncSubprocess songDownloadProcess;
songElement songP;

//Constants
final String SFX_PATH_PREFIX = "assets/SFX/";
final float FIFTH_PI = 0.62831853071;
final int[] cancerKeys = {UP, UP, DOWN, DOWN, LEFT, RIGHT, LEFT, RIGHT, 66, 65, ENTER};

float findComplexity(float[] k) { //Variance calculation
    float adv = 0;
    for(int i = 0; i < k.length; i++) {
        adv += k[i];
    }
    adv /= k.length;
    float complexity = 0;
    for(int i = 0; i < k.length; i++) {
        complexity += abs(k[i] - adv);
    }
    complexity /= k.length;
    return complexity;
}

int getOnScreenObjCount() {
    return gameMap.enemies.size();
}

void moveSongSel(int a) {
    gameSelect_songSelect_actual += a;
    songSelChange.play();
}

void screenshot() {
    screen = get(); //I can't figure out how to use just the back buffer because I'm tired and dumb so I'm doing this
    back.beginDraw();
    back.imageMode(CORNER);
    back.image(screen, 0, 0, back.width, back.height);
    back.endDraw();
}

void setScene(String scene) {
    previousScene = gameState;
    gameState = scene;
    sceneOffsetMillis = adjMillis();
    gameFrameCount = 0;
    gameFrameRateTotal = 0;
    logmsg(String.format("Setting scene (%s --> %s)", previousScene, scene));
}

void setSceneDelay(String scene, int delay) {
    delayedSceneScene = scene;
    delayedSceneTimer = millis() + delay;
    logmsg(String.format("Setting scene to %s in %sms", scene, delay));
}

void returnScene() {
    setScene(previousScene);
}

void gotoLevelSelect() {
    gameMap.song.stop();
    setScene("gameSelect");
    resetLevel();
    screenshot();
}

void transitionFromLevelSummary() {
    if(songEndScreenSkippable) {
        setScene("gameSelect");
        gameMap.song.stop();
        resetLevel();
        songEndScreenSkippable = false;
    }
}

void setKeys(boolean state) {
    if(keyCode == SHIFT) {
        keydown_SHIFT = state;
    }
}

void updateMonitorOptions() {
    monitorOptions.buttons = new ArrayList();
    int i = 0;
    for(String m: getMonitors()) {
        monitorOptions.addButton(m);
        if(++i == monitorID) monitorOptions.setState();
    }
}

void pause(boolean setFPS) {
    paused = true;
    if(gameState.equals("game")) {
        if(gameMap.song.isPlaying()) {
            deltaMillisStart = millis();
            gameMap.song.pause();
            if(setFPS) frameRate(120);
        }
    }
    return;
}

void unpause(boolean setFPS) {
    paused = false;
    if(gameState.equals("game")) {
        if(!gameMap.song.isPlaying() && gameMap.song.position() < gameMap.song.length()) {
            millisDelta -= deltaMillisStart - millis(); //Subtract missed time from new adjMillis
            gameMap.song.unpause();
            if(setFPS) frameRate(FPS);
        }
    }
}

void loadSong() {
    int loadSongStartTime = millis();
    mapGenerationText = "Loading";
    logmsg("Song complexity: " + str(songComplexity));
    try {
        gameMap = new GameMap(songP.fileName, sketchPath("patterns.json"), screenSize, GAME_R);
    }catch(Throwable t) {
        logf("Error in song load! \"%s\"", t);
        mapGenerationText = "";
        setSceneDelay("gameSelect", 3500);
        fadeOpacityStart = 255;
        fadeDuration = 500;
    }
    resetLevelBuffers();
    gameMap.song.setVol(volSlider.val);
    logmsg(String.format("Song arr length: %s; SPS: %s", gameMap.complexityArr.length, gameMap.complexityArr.length / (gameMap.song.length() / 1000.0)));
    logf("Level Load and Generation took %ss.", (millis() - loadSongStartTime) / 1000.0);
    
    gameMap.song.play();
    setScene("performSongRenderings");
}

SFX makeSFX(String name, float defaultVol) {
    return new SFX(sketchPath(SFX_PATH_PREFIX + name), defaultVol);
}

void setGlobalVolume(float vol) {
    if(vol == volSlider.val_min) vol = -10000;
    for(SFX s: soundList) s.setVol(vol);
    if(gameMap != null && gameMap.song.isLoaded()) gameMap.song.setVol(vol);
}

void fadeBack(float mul, int opacity) {
    rectMode(CORNER);
    imageMode(CORNER);
    background(0);
    image(back, 0, 0);
    fill(0, constrain(durationInto * mul * 1.25, 0, opacity));
    rect(-5, -5, gameWidth + 10, gameHeight + 10);
}

void resetEnemies(int scoreDeduction, float time, boolean isHit) {
    for(int i = gameMap.enemies.size() - 1; i >= 0; i--) {
        Enemy e = gameMap.enemies.remove(i);
        if(isHit) {
            boolean isInside = (scoreDeduction > 0) && e.inField(gameMap, time);
            if(isInside) score--;
            if(DO_HIT_PROMPTS.state) {
                floatingPrompts.add(new floatingText(e.locCalc.x, e.locCalc.y, 1500, str(-scoreDeduction - (isInside ? 1 : 0))));
            }
        }
    }
}

void gotHit(int scoreDeduction, int timerDelay, int individualPointReduction, float time) {
    if(clearEnemies != -1) return;
    
    grayScaleTimer = 0;
    if(!NO_DAMAGE.state) {
        hitCount++;
        score -= min(scoreDeduction, MAX_SIMULTANEOUS_DAMAGE);
        noScoreTimer = timerDelay;
        clearEnemies = individualPointReduction;
        hitSound.play();
    }
}

void resetLevelBuffers() {
    pos = vec2(curX, curY);
    previousPos = pos.copy();
    prevTrailLoc = pos.copy();
    back.beginDraw();
    back.clear();
    back.endDraw();
}

void resetLevel() {
    score = 0;
    hitCount = 0;
    levelSummary_timer = 0;
    nextFadeTime = 0;
    textSFX.stop();
    a = new arrow(gameWidth / 2, gameHeight / 2, 0, 500, 1700);
    resetLevelBuffers();
}

String fileName(String path) {
    return new File(path).getName().replaceFirst("[.][^.]+$", "");
}

void selectLevel(songElement song) {
    switch(song.fileName) {
        case "///addSong": {
            selectInput("Select a music file:", "songSelected");
        } break;
        case "///download": {
            setScene("load_download");
            fadeOpacityStart = 128;
            fadeDuration = 128;
            songDownloadProcess = tryDownloadFromClipboard();
        } break;
        default: {
            songP = song;
            setScene("load_song");
            resetLevel();
            bubbles = new ArrayList();
            floatingPrompts = new ArrayList();
            bubbleLayer = createGraphics(gameWidth, gameHeight, P2D);
            for(int i = 0; i < 4; i++) {
                bubbles.add(new bubble(vec2(GFX_R.rand(0, gameWidth), GFX_R.rand(0, gameHeight))));
            }
            logmsg("Random seed for \"" + song.title + "\": " + GAME_R.setSeed(song.title.hashCode()));
            thread("loadSong");
        } break;
    }
}

void songSelected(File file) {
    if(file == null) return;
    songList.add(songList.size() - 1, new songElement(songCache, file.getAbsolutePath()));
    try {
        Files.copy(Paths.get(file.getAbsolutePath()), Paths.get(sketchPath("songs/" + file.getName())));
    } catch (IOException e) {
        e.printStackTrace();
    }
}

float adjMillis() {
    return millis() + millisDelta;
}

class songElement {
    String author, duration, title, fileName;
    JSONObject songCacheDir;
    songElement(String fileName, String title) {
        this.fileName = fileName;
        this.title = title;
    }
    songElement(JSONObject songCacheDir, String fileName) {
        this.songCacheDir = songCacheDir;
        this.fileName = fileName;
        this.title = fileName(fileName);
        if(songCacheDir.isNull(title) || REFRESH_SONG_METADATA) {
            Music songTmp = new Music(fileName, 0);
            AudioMetaData metadata = songTmp.sound.getMetaData();
            JSONObject songData = new JSONObject();
            if(metadata.author() != null) {
                author = metadata.author();
                songData.setString("author", author);
            }
            if(metadata.length() > 0) {
                duration = durToString(metadata.length());
                songData.setString("duration", duration);
            }
            songCacheDir.setJSONObject(title, songData);
        }else{
            JSONObject songMeta = songCacheDir.getJSONObject(title);
            if(!songMeta.isNull("author")) this.author = songMeta.getString("author");
            if(!songMeta.isNull("duration")) this.duration = songMeta.getString("duration");
        }
    }
    String durToString(int dur) {
        return dur / (60 * 1000) + ":" + nf((dur / 1000) % 60, 2);
    }
    String toString() {
        return (author != null && author.length() > 0 ? author + ": " : "") + songP.title + " (" + songP.duration + ")";
    }
}

void initializeSongs() {
    songList = new ArrayList();
    try {
        assert new File(sketchPath(songDataFileLoc)).isFile();
        songCache = loadJSONObject(songDataFileLoc);
    } catch (Throwable e) {
        logmsg("Song data file not found or was corrupt: " + e);
        songCache = new JSONObject();
    }

    for(String songName: new File(sketchPath("Songs")).list()) {
        try {
            songElement songElm = new songElement(songCache, sketchPath("Songs/" + songName));
            songList.add(songElm);
        } catch (Throwable e) {
            logmsg("Song unreadable: " + songName);
        }
    }
    saveJSONObject(songCache, songDataFileLoc);
    songList.add(new songElement("///addSong", "+ Add Song"));
    songList.add(new songElement("///download", "+ Youtube-dl [Clipboard]"));

    gameSelect_songSelect_actual = songList.size() / 2;
    gameSelect_songSelect = gameSelect_songSelect_actual;
}

class bubble {
    PVector loc, vel;
    float timer_offset;
    int size = 750;
    bubble(PVector loc) {
        this.loc = loc;
        float ang = GFX_R.rand(0, TWO_PI);
        vel = mulVec(
            PVector.fromAngle(ang).mult(GFX_R.random(1.5, 2.5)),
            vec2(GFX_R.rSign(), GFX_R.rSign())
        );
        timer_offset = GFX_R.rand(1000000);
    }
    void update() {
        loc.add(PVector.mult(vel, max(0.01, pow(2 * max(0.01, c - 0.08), 3))));

        PVector adv = vec2();
        for(bubble b: bubbles) {
            adv.add(b.loc);
        }
        vel.sub(adv.div(bubbles.size()).sub(loc).normalize().div(125));

        float adjSize = size / 2;
        if(loc.x > gameWidth + adjSize) {
            loc.x = -adjSize;
        }else if(loc.x < -adjSize) {
            loc.x = gameWidth + adjSize;
        }
        if(loc.y > gameHeight + adjSize) {
            loc.y = -adjSize;
        }else if(loc.y < -adjSize) {
            loc.y = gameHeight + adjSize;
        }
    }
}

PGraphics bubbleLayer;
void drawBubbles(PGraphics base) {
    FloatList coord_x = new FloatList();
    FloatList coord_y = new FloatList();
    FloatList timeOff = new FloatList();
    float currentTime = adjMillis() / 1000.0;
    for(bubble b: bubbles) {
        coord_x.append(b.loc.x / gameWidth);
        coord_y.append(1 - b.loc.y / height);
        timeOff.append(currentTime + b.timer_offset);
    }
    bubbleShader.set("clr", 1.2 * (pow(c, 0.33)));
    bubbleShader.set("mul", c / 5.0);
    bubbleShader.set("opacity", 0.001 + pow(c, 0.75) / 30.0);
    bubbleShader.set("coord_x", coord_x.array());
    bubbleShader.set("coord_y", coord_y.array());
    bubbleShader.set("timeOff", timeOff.array());
    bubbleLayer.filter(bubbleShader); //WHAT
}

class arrow {
    float x, y, d1, d2, a, sz, mn, rot = PI, speed = 1;
    float oT = 0, oTV = 0;
    arrow(float x, float y, float d2, float sz, float mn) {
        this.x = x;
        this.y = y;
        this.d2 = d2;
        this.sz = sz;
        this.mn = mn;
    }
    void spawn() {
        oTV = 1;
        oT++;
        oT = constrain(oT, 0, 255);
    }
    void despawn() {
        oTV = -1;
        oT--;
        oT = constrain(oT, 0, 255);
    }
    void update(float time) {
        oT += oTV * (200 / frameRate);
        oT = constrain(oT, 0, 255);
        rot += 0.05 * (60 / frameRate);
        d1 = -mn - (sz) * (cos(rot) + 1);
        PVector org = vec2(x + cos(a) * d1, y + sin(a) * d1);
        if(oT > 120 && (
                squareIntersection(pos, 20, org, PVector.add(org, PVector.fromAngle(a + FIFTH_PI).mult(30))) ||
                squareIntersection(pos, 20, org, PVector.add(org, PVector.fromAngle(a - FIFTH_PI).mult(30))) ||
                (cancerMode && (
                    squareIntersection(pos, 22.5, org, vec2(x + cos(a) * d2, y + sin(a) * d2)) ||
                    lineIntersection(org, vec2(x + cos(a) * d2, y + sin(a) * d2), previousPos, pos)
                ))
            )) {
            if(noScoreTimer <= 0) {
                int scorePer = cancerMode ? 4 : 2;
                gotHit(getOnScreenObjCount() * scorePer + 3, 60, scorePer, time);
                if(!NO_DAMAGE.state) floatingPrompts.add(new floatingText(x + cos(a) * d1, y + sin(a) * d1, 2250, "-3"));
            }
        }
    }
    void drawLine() {
        strokeWeight(cancerMode ? 5 : 2);
        colorMode(RGB);
        stroke(cancerMode ? color(255, 0, 0, oT) : color(255, oT));
        line(x + cos(a) * d1, y + sin(a) * d1, x + cos(a) * d2, y + sin(a) * d2);
    }
    void drawHead(PGraphics base, int sub) {
        base.colorMode(RGB);
        base.strokeCap(ROUND);
        base.strokeWeight(5);
        base.stroke(255, 0, 0, oT - sub);
        base.line(
            x + cos(a) * d1,
            y + sin(a) * d1,
            x + cos(a) * d1 + cos(a + FIFTH_PI) * 30,
            y + sin(a) * d1 + sin(a + FIFTH_PI) * 30
        );
        base.line(
            x + cos(a) * d1,
            y + sin(a) * d1,
            x + cos(a) * d1 + cos(a - FIFTH_PI) * 30,
            y + sin(a) * d1 + sin(a - FIFTH_PI) * 30
        );
        base.strokeCap(PROJECT);
    }
}

class floatingText {
    String txt;
    float x, y, startTime, delTime;
    floatingText(float x, float y, int duration, String txt) {
        this.x = x;
        this.y = y;
        this.txt = txt;
        this.startTime = adjMillis();
        delTime = startTime + duration;
    }
    void draw() {
        if(delTime - adjMillis() > 1000) {
            fill(255);
        }else{
            fill(255, ((delTime - adjMillis()) / 1000.0) * 255.0);
        }
        text(txt, x, y - 75 * sqrt(map(adjMillis(), startTime, delTime, 0, 1)));
    }
}

void settings() {
    settingsFileLoc = sketchPath("settings.json");
    try {
        assert sketchFile(settingsFileLoc).isFile();
        menuSettings = loadJSONObject(settingsFileLoc);
        monitorID = menuSettings.getInt("monitorID");
        fullScreen(P2D, monitorID);
    } catch (Throwable e) {
        logmsg("Settings file not found or was corrupt: " + e);
        monitorID = 1;
        fullScreen(P2D, 1);
    }

    smooth(4);
    PJOGL.setIcon(sketchPath("assets/images/aebal.png"));
}

PGraphics intensityGraph;
void setup() {
    frameRate(FPS);
    surface.setTitle("Aebal");

    if(args != null && args.length > 0) {
        for(int i = 0; i < args.length; i++) {
            if(args[i].trim().toLowerCase().equals("debug")) {
                allowDebugActions = true;
            }
        }
    }

    screenSize = new PVector(gameWidth, gameHeight);
    GFX_R = new RNG();
    GAME_R = new RNG();
    timingList = new HashMap();
    timingDisplay = new HashMap();
    timerFormat = new DecimalFormat("##.####");
    timerFormat.setMinimumIntegerDigits(2);
    timerFormat.setMinimumFractionDigits(4);
    msgList = new debugList(0, 0, 10000, 3000);
    

    minim = new Minim(this);
    soundList = new SFX[] {
        songSelChange = makeSFX("songSelChange.wav", -15),
        volChangeSFX = makeSFX("volChange.wav", -12),
        buttonSFX = makeSFX("button.wav", -12),
        gainScore = makeSFX("gainScore.wav", -20),
        hitSound = makeSFX("hit.wav", -3),
        textSFX = makeSFX("textSFX.wav", -18)
    };

    color setting_default_t = #33D033;
    color setting_default_t_over = #00FF00;
    color setting_default_t_active = #99FF99;
    color setting_default_f = #D03333;
    color setting_default_f_over = #FF0000;
    color setting_default_f_active = #FF9999;

    volSlider = new vol_slider(gameWidth / 2, gameHeight / 1.175, 600, 35, 0, -30, 20, "Volume", #3333CC, #3355CC, #2222DD, #2266DD, #1111FF, #1177FF);
    difficultySlider = new difficulty_slider(1357, gameHeight * 4 / 5, 500, 35, songComplexity, 0.5, 1.1, "Difficulty", #3333CC, #3355CC, #2222DD, #2266DD, #1111FF, #1177FF);
    monitorOptions = new buttonMenu(165, 65, 200, 30, color(225), color(220), color(215), color(30), color(40), color(50));
    settings = new settingButton[] {
        DYNAMIC_BACKGROUND_COLOR = new settingButton(0, 0, 75, 75, 5, "Dynamic Background"  , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
        DO_POST_PROCESSING       = new settingButton(0, 0, 75, 75, 5, "Color Shaders"       , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
        BACKGROUND_BLOBS         = new settingButton(0, 0, 75, 75, 5, "Background Blobs"    , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
        SHOW_SONG_GRAPH          = new settingButton(0, 0, 75, 75, 5, "Show Intensity Graph", setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
        DO_FANCY_TRAILS          = new settingButton(0, 0, 75, 75, 5, "Fancy Trails"        , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
        DO_COLORFUL_TRAILS       = new settingButton(0, 0, 75, 75, 5, "Colorful Trails"     , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
        BACKGROUND_FADE          = new settingButton(0, 0, 75, 75, 5, "Background Fade"     , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
        SHOW_SONG_NAME           = new settingButton(0, 0, 75, 75, 5, "Show Song Name"      , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
        DO_HIT_PROMPTS           = new settingButton(0, 0, 75, 75, 5, "Score Ticks"         , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
        DEBUG_INFO               = new settingButton(0, 0, 75, 75, 5, "Debug Info"          , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
        TIMING_INFO              = new settingButton(0, 0, 75, 75, 5, "Timing Info"         , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
        RGB_ENEMIES              = new settingButton(0, 0, 75, 75, 5, "RGB Enemies"         , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
        NO_DAMAGE                = new settingButton(0, 0, 75, 75, 5, "Invincible"          , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
        DO_CHROMA                = new settingButton(0, 0, 75, 75, 5, "Chromatic Aberration", setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
        DO_SHAKE                 = new settingButton(0, 0, 75, 75, 5, "Shake"               , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
        SHOW_FPS                 = new settingButton(0, 0, 75, 75, 5, "FPS Tracker"         , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active)
    };
    settings_left = new settingButton[] {
        RGB_ENEMIES,
        DO_CHROMA,
        DYNAMIC_BACKGROUND_COLOR,
        DO_SHAKE,
        SHOW_SONG_NAME,
        BACKGROUND_FADE,
        BACKGROUND_BLOBS
    };
    settings_right = new settingButton[] {
        DO_POST_PROCESSING,
        DO_FANCY_TRAILS,
        DO_COLORFUL_TRAILS,
        DO_HIT_PROMPTS,
        SHOW_FPS,
        TIMING_INFO,
        DEBUG_INFO
    };
    for(int i = 0; i < settings_left.length; i++) {
        settings_left[i].x = 100;
        settings_left[i].y = gameHeight / 1.65 - settings_left.length * 50 + i * 100;
    }
    for(int i = 0; i < settings_right.length; i++) {
        settings_right[i].x = gameWidth - 100;
        settings_right[i].y = gameHeight / 1.65 - settings_right.length * 50 + i * 100;
    }

    settingsFileLoc = sketchPath("settings.json");
    songDataFileLoc = sketchPath("songData.json");
    try {
        assert sketchFile(settingsFileLoc).isFile();
        menuSettings = loadJSONObject(settingsFileLoc);
        for(settingButton b: settings) {
            if(!menuSettings.isNull(b.txt)) {
                b.state = menuSettings.getBoolean(b.txt);
            }
        }
        if(!menuSettings.isNull("volume")) volSlider.val = menuSettings.getFloat("volume");
        if(!menuSettings.isNull("intensity")) {
            difficultySlider.val = menuSettings.getFloat("intensity");
            difficultySlider.onChange();
        }
    } catch (Throwable e) {
        logmsg("Settings file not found or was corrupt: " + e);
        NO_DAMAGE.state = false;
        DEBUG_INFO.state = false;
        TIMING_INFO.state = false;
        SHOW_SONG_GRAPH.state = false;
        menuSettings = new JSONObject();
        for(settingButton b: settings) {
            menuSettings.setBoolean(b.txt, b.state);
        }
        menuSettings.setInt("monitorID", 1);
        saveJSONObject(menuSettings, settingsFileLoc);
    }

    image_back = loadImage(sketchPath("assets/Images/backarrow.png"));
    text_logo = loadImage(sketchPath("assets/Images/aebal_text.png"));
    image_gear = loadImage(sketchPath("assets/Images/gear.png"));
    image_settings = loadImage(sketchPath("assets/Images/settings.png"));
    image_paused = loadImage(sketchPath("assets/Images/paused.png"));

    initializeSongs();
    setGlobalVolume(volSlider.val);

    settings_button = new button(gameWidth - 65, gameHeight - 65, 85, 85, 5, image_gear, color(45), color(75), color(128));
    back_button = new button(65, gameHeight - 65, 85, 85, 5, image_back, color(45), color(75), color(128));

    defaultFont = createFont(sketchPath("assets/fonts/defaultFont.ttf"), 128);
    songFont = createFont(sketchPath("assets/fonts/songFont.ttf"), 64);

    a = new arrow(gameWidth / 2, gameHeight / 2, 0, 500, 1700);
    back = createGraphics(gameWidth, gameHeight, P2D);

    chroma = loadShader(sketchPath("assets/shaders/rgb_offset.glsl"));
    grayScale = loadShader(sketchPath("assets/shaders/gray.glsl"));
    bubbleShader = loadShader(sketchPath("assets/shaders/bubble.glsl"));
    loading_animation = loadShader(sketchPath("assets/shaders/loading_animation.glsl"));
    reduceOpacity = loadShader(sketchPath("assets/shaders/reduceOpacity.glsl"));
    bloom = loadShader(sketchPath("assets/shaders/bloom.glsl"));
    loading_animation_buffer = createGraphics(750, 750, P2D);
    
    zeroVector = vec2();
    chroma_r = vec2();
    chroma_g = vec2();
    chroma_b = vec2();

    pos = vec2(gameWidth / 2, gameHeight / 2);
    previousPos = pos.copy();
    prevTrailLoc = pos.copy();
    trailLoc = pos.copy();

    updateMonitorOptions();
    strokeCap(PROJECT);
    
    intensityGraph = createGraphics(gameWidth, gameHeight, P2D);
}

void draw() {
    if(focused || gameState.equals("title")) {
        if(paused) unpause(true);
    }else{
        if(!paused) pause(true);
        return;
    }

    durationInto = int(adjMillis() - sceneOffsetMillis);

    //Scale to monitor size
    float scaleFactW = float(width) / gameWidth;
    float scaleFactH = float(height) / gameHeight;
    float scaleFact = min(scaleFactW, scaleFactH);
    
    pushMatrix();
    if(scaleFact == scaleFactH) {
        float t = (width - gameWidth * scaleFact) / 2.0;
        translate(t, 0);
        curX = int(map(mouseX, t, (width + gameWidth * scaleFact) / 2.0, 0, gameWidth));
        curY = int(map(mouseY, 0, height, 0, gameHeight));
    }else{
        float t = (height - gameHeight * scaleFact) / 2.0;
        translate(0, t);
        curX = int(map(mouseX, 0, width, 0, gameWidth));
        curY = int(map(mouseY, t, (height + gameHeight * scaleFact) / 2.0, 0, gameHeight));
    }
    scale(scaleFact);
    
    previousCursor = activeCursor;
    if(TIMING_INFO.state) {
        if(millis() > timerUpdateTime) {
            checkTimes = true;
            timerUpdateTime = millis() + TIMER_UPDATE_FREQUENCY;
        }else{
            checkTimes = false;
        }
    }
    
    switch(gameState) {
        case "title": {
            background(0);
            imageMode(CENTER);
            pushMatrix();
            translate(gameWidth / 2, text_logo.height * (1 + 0.07 * sin(durationInto / 800.0)));
            rotate(sin(0.2 + durationInto / 500.0) / 40.0);
            image(text_logo, 0, 0);
            popMatrix();
            if(durationInto > 5000) {
                textFont(songFont, 48);
                textAlign(CENTER, CENTER);
                text("<Press any key to begin>", gameWidth / 2, 0.8 * gameHeight);
            }
            if(durationInto > 1800000) {
                loading_animation.set("u_time", millis() / 1000.0);
                loading_animation_buffer.filter(loading_animation);
                image(loading_animation_buffer, 0, 0);
                image(loading_animation_buffer, gameWidth, 0);
                image(loading_animation_buffer, 0, gameHeight);
                image(loading_animation_buffer, gameWidth, gameHeight);
            }
        } break;
        case "gameSelect": { //This isn't over engineered or stupid whatsoever
            activeCursor = ARROW;
            background(0);
            stroke(128);
            strokeWeight(8);
            strokeCap(ROUND);
            line(gameWidth / 2, gameHeight * 1 / 4, gameWidth / 2, gameHeight * 8 / 9);
            strokeCap(PROJECT);
            imageMode(CENTER);
            image(text_logo, gameWidth / 2, text_logo.height / 2);
            noStroke();
            textFont(defaultFont, 50);
            float lerpAmount = 60.0 / frameRate;
            float fontRounder = 16.0;
            gameSelect_songSelect_actual = Math.floorMod(gameSelect_songSelect_actual, songList.size());
            gameSelect_songSelect = lerp(gameSelect_songSelect, gameSelect_songSelect_actual, lerpAmount);

            int min_s = gameSelect_songSelect_actual - GAMESELECT_SONGDISPLAYCOUNT;
            int max_s = min(gameSelect_songSelect_actual + GAMESELECT_SONGDISPLAYCOUNT, songList.size());

            float extraYoffset = 0;
            for(int i = max(0, min_s); i < gameSelect_songSelect_actual; i++) {
                float fontSize = max(2, 50 - 7 * pow(abs(i - int(fontRounder * gameSelect_songSelect) / fontRounder), 0.9));
                String songTitle = WordUtils.wrap(songList.get(i).title, 32, "\n", true);
                extraYoffset += fontSize * (songTitle.length() - songTitle.replace("\n", "").length());
            }
            gameSelectExtraYOffset = lerp(gameSelectExtraYOffset, extraYoffset, lerpAmount);
            float tx = -500, ty = 150 - gameSelectExtraYOffset, y_offset = 0;

            pushMatrix();
            translate(tx, ty);
            for(int i = min_s; i < max_s; i++) {
                float fontSize = max(2, 50 - 7 * pow(abs(i - int(fontRounder * gameSelect_songSelect) / fontRounder), 0.9));
                String songTitle = "";
                int newlineCount = 0;
                float offset_y_tmp = 0;
                if(i >= 0) {
                    fill(255);
                    textAlign(CENTER, CENTER);
                    textSize(fontSize);
                    textLeading(fontSize);
                    songElement currentElement = songList.get(i);
                    songTitle = WordUtils.wrap(currentElement.title, 32, "\n", true);
                    newlineCount = songTitle.length() - songTitle.replace("\n", "").length();
                    offset_y_tmp = newlineCount * fontSize / 2.0;
                    y_offset += offset_y_tmp;
                    if(fontSize > 2) {
                        text(songTitle, gameWidth / 2, 250 + y_offset);
                        if(i == gameSelect_songSelect_actual) {
                            float txtWid = textWidth(songTitle);
                            float sw = txtWid / 2;
                            float border_expand_y = 27.5 * (newlineCount + 1);
                            if(curX - tx > gameWidth / 2 - (60 + sw) && curX - tx < gameWidth / 2 + (60 + sw) && curY - ty > 250 + y_offset + 6.75 - border_expand_y && curY - ty < 250 + y_offset + 6.75 + border_expand_y) {
                                mouseOverSong = true;
                                if(mousePressed) {
                                    fill(255, 128, 128);
                                    activeCursor = MOVE;
                                }else{
                                    fill(255, 200, 200);
                                    activeCursor = HAND;
                                }
                            }else{
                                mouseOverSong = false;
                                fill(255);
                            }
                            triangle(
                                gameWidth / 2 + sw + 15, 250 + y_offset + 6.75,
                                gameWidth / 2 + sw + 55, 250 + y_offset + 6.75 - 20,
                                gameWidth / 2 + sw + 55, 250 + y_offset + 6.75 + 20);
                            triangle(
                                gameWidth / 2 - sw - 15, 250 + y_offset + 6.75,
                                gameWidth / 2 - sw - 55, 250 + y_offset + 6.75 - 20,
                                gameWidth / 2 - sw - 55, 250 + y_offset + 6.75 + 20);

                            if(i != songList.size() - 1) {
                                float descSize = 40;
                                textSize(descSize);
                                textLeading(descSize + 5);
                                textAlign(LEFT, TOP);
                                fill(255);

                                String songTitleShort = WordUtils.wrap(currentElement.title, 16, "\n", true);
                                int newlineCountShort = songTitleShort.length() - songTitleShort.replace("\n", "").length();

                                String newLines = "";
                                for(int tmp = 0; tmp < newlineCountShort; tmp++) {
                                    newLines += '\n';
                                }
                                String detailsLeft = "Title:" + newLines;
                                String detailsRight = songTitleShort;
                                if(currentElement.author != null && currentElement.author.length() > 0) {
                                    detailsLeft += "\nArtist:";
                                    detailsRight += '\n' + currentElement.author;
                                }
                                if(currentElement.duration != null && currentElement.duration.length() > 0) {
                                    detailsLeft += "\nDuration:";
                                    detailsRight += '\n' + currentElement.duration;
                                }

                                text(detailsLeft, gameWidth / 2 + descSize / 2 - tx, gameHeight * 1 / 4 + 3 - ty);
                                text(detailsRight, gameWidth / 2 + descSize / 2 + 10 * descSize - tx, gameHeight * 1 / 4 + 3 - ty);
                            }
                        }
                    }
                }
                y_offset += offset_y_tmp + fontSize + 5;
            }
            popMatrix();
            textFont(defaultFont, 60);
            textAlign(CENTER, BOTTOM);
            textLeading(64);
            difficultySlider.draw();
            settings_button.draw();
            back_button.draw();
        } break;

        case "performSongRenderings": {
            if(allowDebugActions) gameMap.drawIntensityGraph(intensityGraph);
            setScene("game");
        } break;
        
        case "game": {
            noScoreTimer -= (60 / frameRate);
            TT("Physics");
            float time = gameMap.song.getTime();
            float durationComplete = gameMap.song.getTimeFraction();
            
            previousPos.set(pos.x, pos.y);
            pos.set(curX, curY);
            
            gameMap.updateField(pos, time, curX, curY);
            gameMap.updateEnemies(time);
            
            c = gameMap.getIntensity(time);
            intense = gameMap.field.intense();
            
            imageMode(CORNER);
            rectMode(CENTER);
            activeCursor = -1;

            randTrans = DO_SHAKE.state ? vec2(GFX_R.rand(10 * -c, 10 * c), GFX_R.rand(10 * -c, 10 * c)) : vec2();
            ang += (0.001 + constrain(c / 75, 0, 0.05)) * (200 / frameRate);
            a.speed = constrain(a.speed * (1 + constrain((c - 0.25) / 100, -0.05, 0.05)), 0.5, 1.75);
            float dfc = sqrt(sq(gameWidth) + sq(gameHeight));

            a.x = cos(ang) * dfc + gameWidth / 2;
            a.y = sin(ang) * dfc + gameHeight / 2;
            a.a = atan2(a.y - gameHeight / 2, a.x - gameWidth / 2);
            if(a.oT > 0) {
                a.update(time);
            }
            if(gameMap.field.size <= gameMap.field.minCenterSize * 1.5) {
                a.spawn();
            }else{
                a.despawn();
            }

            if(BACKGROUND_BLOBS.state) {
                for(bubble b: bubbles) {
                    b.update();
                }
            }
            score = max(0, score);
            
            TT("Physics");

            if(DYNAMIC_BACKGROUND_COLOR.state) {
                colorMode(HSB);
                color updatedColor;
                float adjC = min(c, 1.2);
                updatedColor = intense ? color((100 + (c * 500)) % 255, 255, (adjC / 1.2 - 0.25) * 200) : color((c * 200) % 255);
                backColor = lerpColor(backColor, updatedColor, BACKGROUND_COLOR_FADE);
                background(hue(backColor), saturation(backColor), brightness(backColor) / 3);
                colorMode(RGB);
            }else{
                background(0);
            }

            if(BACKGROUND_FADE.state) {
                if(adjMillis() > nextFadeTime) {
                    TT("Fade");
                    back.filter(reduceOpacity);
                    TT("Fade");
                    nextFadeTime = max(adjMillis() - 50, nextFadeTime + 1000.0 / 200.0);
                }
            }else{
                back.beginDraw();
                back.background(0);
                back.endDraw();
            }

            if(BACKGROUND_BLOBS.state) {
                TT("Blobs");
                drawBubbles(back); //If you do this while back PGraphic is in "draw mode", the scaling gets messed up. Some processing related bug 
                TT("Blobs");
            }

            back.beginDraw();
            back.imageMode(CENTER);
            back.noStroke();

            if(!BACKGROUND_FADE.state) {
                back.background(backColor);
            }
            if(BACKGROUND_BLOBS.state) {
                back.imageMode(CORNER);
                back.image(bubbleLayer, 0, 0);
            }
            if(BACKGROUND_FADE.state) {
                if(DO_COLORFUL_TRAILS.state) {
                    trailColor = lerpColor(trailColor, color((adjMillis() / 5.0) % 255, 255 * c, 255), 2.0 / frameRate);
                }
                back.stroke(DO_COLORFUL_TRAILS.state ? trailColor : 255);
                if(DO_FANCY_TRAILS.state) {
                    back.noFill();
                    if(dist(previousPos.x, previousPos.y, pos.x, pos.y) > 0) {
                        prevTrailLoc = trailLoc;
                        trailLoc = new PVector(pos.x, pos.y);

                        float d = dist(prevTrailLoc.x, prevTrailLoc.y, trailLoc.x, trailLoc.y);
                        d /= (2.25 + max(0, (60 - d) / 60));
                        float a = atan2(trailLoc.y - prevTrailLoc.y, trailLoc.x - prevTrailLoc.x);

                        PVector newMiddle = PVector.add(prevTrailLoc, PVector.fromAngle(trailingAngle).mult(d));
                        PVector closeMargin = PVector.lerp(
                            PVector.lerp(
                                PVector.lerp(
                                    newMiddle, prevTrailLoc,
                                    min(1, 2 * pow(abs(trailingAngle - a), 2))
                                ),
                                trailLoc, 0.75
                            ),
                            newMiddle, 0.15
                        );
                        gameMap.field.constrainPosition(newMiddle);
                        gameMap.field.constrainPosition(closeMargin);

                        trailingAngle = atan2(
                            bezierTangent(prevTrailLoc.y, newMiddle.y, closeMargin.y, trailLoc.y, 1),
                            bezierTangent(prevTrailLoc.x, newMiddle.x, closeMargin.x, trailLoc.x, 1)
                        );
                        trailStrokeWeight = lerp(trailStrokeWeight, constrain(d / 2.0, 4.5, 10), 10 / frameRate);
                        back.strokeWeight(trailStrokeWeight);
                        back.strokeCap(SQUARE);
                        back.bezier(prevTrailLoc.x, prevTrailLoc.y, newMiddle.x, newMiddle.y, closeMargin.x, closeMargin.y, trailLoc.x, trailLoc.y);
                        back.strokeCap(PROJECT);
                    }
                }else{
                    back.strokeWeight(5);
                    back.line(previousPos.x, previousPos.y, pos.x, pos.y);
                }
            }
            colorMode(HSB);
            globalObjColor = lerpColor(globalObjColor, (intense && RGB_ENEMIES.state) ? color((adjMillis() / 5.0) % 255, 164, 255) : color(0, 255, 255), 4.0 / frameRate);

            if(BACKGROUND_FADE.state) {
                back.stroke(globalObjColor);
            }else{
                back.noStroke();
            }
            TT("Enemies");
            gameMap.drawEnemies(back, time, pos, previousPos, globalObjColor, BACKGROUND_FADE.state);
            TT("Enemies");
            a.drawHead(back, 128);
            back.endDraw();

            imageMode(CORNER);
            image(back, 0, 0);

            a.drawLine();
            stroke(255);
            a.drawHead(g, 0);
            noStroke();
            
            //draw field
            pushMatrix();
            if(intense) translate(randTrans.x, randTrans.y);
            gameMap.drawField(g, pos, curX, curY);
            popMatrix();

            //draw player
            gameMap.drawPlayer(g, pos, curX, curY);
            
            //post processing
            if(DO_POST_PROCESSING.state) {
                TT("PostProcessing");
                bloom.set("bloom_intensity", 1.5 * c / 81.0);
                if(intense) {
                    bloom.set("saturation", 1 + c / 5.0);
                }else{
                    bloom.set("saturation", 1.0);
                }
                filter(bloom);
                TT("PostProcessing");
            }
            if(DO_CHROMA.state) {
                TT("ChromaAbbr");
                float prec = 0.5;
                PVector nextChroma_r, nextChroma_g, nextChroma_b;
                if(intense) {
                    if(c >= 1.5) {
                        float offset = (2 * ((2 * c + 0.5) % 1) - 1) / 5;
                        float offset_y = GFX_R.rand(-c / 6, c / 6);
                        if(GFX_R.rand(0, 1) < 0.5) {
                            nextChroma_r = vec2(offset, GFX_R.rand(-offset_y, offset_y));
                            nextChroma_g = vec2(-offset, GFX_R.rand(-offset_y, offset_y));
                            nextChroma_b = vec2(GFX_R.rand(-offset, offset), GFX_R.rand(-offset_y, offset_y));
                        }else{
                            nextChroma_r = vec2(GFX_R.rand(-offset_y, offset_y), offset);
                            nextChroma_g = vec2(GFX_R.rand(-offset_y, offset_y), -offset);
                            nextChroma_b = vec2(GFX_R.rand(-offset_y, offset_y), GFX_R.rand(-offset, offset));
                        }
                    }else{
                        nextChroma_r = vec2(randTrans.x / 1200.0, 0.0);
                        nextChroma_g = vec2(0, 0);
                        nextChroma_b = vec2(0.0, randTrans.y / 1200.0);
                    }
                }else{
                    nextChroma_r = zeroVector;
                    nextChroma_g = zeroVector;
                    nextChroma_b = zeroVector;
                }
                chroma_r = chroma_r.mult(1 - prec).add(nextChroma_r.mult(prec));
                chroma_g = chroma_g.mult(1 - prec).add(nextChroma_g.mult(prec));
                chroma_b = chroma_b.mult(1 - prec).add(nextChroma_b.mult(prec));
                chroma.set("r", chroma_r.x, chroma_r.y);
                chroma.set("g", chroma_g.x, chroma_g.y);
                chroma.set("b", chroma_b.x, chroma_b.y);
                filter(chroma);
                TT("ChromaAbbr");
            }

            if(DO_HIT_PROMPTS.state) {
                textSize(24);
                for(int i = floatingPrompts.size() - 1; i > -1; i--) {
                    floatingText o = floatingPrompts.get(i);
                    o.draw();
                    if(adjMillis() > o.delTime) {
                        floatingPrompts.remove(i);
                    }
                }
            }

            if(DO_POST_PROCESSING.state) {
                grayScaleTimer += 4 / frameRate;
                float adjustedGrayScale = -0.8 * sq(grayScaleTimer) + 2.4 * grayScaleTimer;
                if(adjustedGrayScale > 0.0) {
                    grayScale.set("power", min(adjustedGrayScale, 0.75));
                    filter(grayScale);
                }
            }

            colorMode(RGB);
            fill(144, 200, 154);
            textSize(50);
            textAlign(LEFT, TOP);
            text("Score: " + score + "\n\n" + gameMap.enemies.size() + '\n' + time + '\n' + gameMap.getIntensityIndex(time) + '\n' + gameMap.getIntensity(time) + '\n' + gameMap.getIntegralVal(gameMap.SPS *  time), 10, 0);

            if(SHOW_SONG_NAME.state) {
                fill(255, 200);
                textFont(songFont, 48);
                textAlign(LEFT, BOTTOM);
                text(songP.title, 10, gameHeight - 10);
            }

            //Duration bar
            rectMode(CORNERS);
            noStroke();
            fill(255);
            rect(0, gameHeight - 4, gameWidth * durationComplete, gameHeight);
            fill(64);
            rect(gameWidth * durationComplete, gameHeight - 4, gameWidth, gameHeight);

            if(SHOW_SONG_GRAPH.state) image(intensityGraph, 0, -4);

            if(clearEnemies != -1) { //Used to avoid concurrentmodificationexception when clearing enemies when their drawn
                resetEnemies(clearEnemies, time, true);
                clearEnemies = -1;
            }

            if(!gameMap.song.isPlaying()) {
                if(levelSummary_timer == 0) {
                    if(gameMap.enemies.size() > 0 && DO_HIT_PROMPTS.state) {
                        gainScore.play();
                        for(int i = gameMap.enemies.size() - 1; i > -1; i--) {
                            Enemy enemy = gameMap.enemies.get(i);
                            floatingPrompts.add(new floatingText(enemy.locCalc.x, enemy.locCalc.y, 1500, "+1"));
                            gameMap.enemies.remove(i);
                            score++;
                        }
                        levelSummary_timer = int(adjMillis() + 2000);
                    }else{
                        levelSummary_timer = 1;
                    }
                }else if(adjMillis() > levelSummary_timer) {
                    levelSummary_timer = 0;
                    setScene("levelSummary");
                    screenshot();
                }
            }
        } break;
        case "pause": {
            activeCursor = ARROW;
            textAlign(CENTER, CENTER);
            fadeBack(1, 255);
            fill(255);
            imageMode(CENTER);
            image(image_paused, gameWidth / 2, 123, gameWidth / 2, gameWidth / 2 * (float(image_paused.height) / image_paused.width));
            textFont(songFont, 48);
            textAlign(CENTER, CENTER);
            text("<Press esc to return to game>", gameWidth / 2, gameHeight / 1.45);
            settings_button.draw();
            back_button.draw();

        } break;
        case "settings": {
            activeCursor = ARROW;
            textAlign(CENTER, CENTER);
            fadeBack(1, 255);
            fill(255);
            noStroke();
            imageMode(CENTER);
            image(image_settings, gameWidth / 2, 123, gameWidth / 2, gameWidth / 2 * (float(image_settings.height) / image_settings.width));

            textFont(defaultFont, 32);
            textAlign(LEFT, CENTER);
            for(settingButton b: settings_left) {
                b.draw();
            }
            textAlign(RIGHT, CENTER);
            for(settingButton b: settings_right) {
                b.draw();
            }
            textSize(60);
            textAlign(CENTER, BOTTOM);
            volSlider.txt = "Volume - " + int(map(volSlider.val, volSlider.val_min, volSlider.val_max, 0, 100)) + '%';
            volSlider.draw();
            back_button.draw();
            monitorOptions.draw();
            if(nextVolumeSFXplay > 0 && millis() > nextVolumeSFXplay) {
                volSlider.onRelease();
                nextVolumeSFXplay = -1;
            }
        } break;
        case "load_song": {
            activeCursor = ARROW;
            background(0);
            fill(255);
            textFont(songFont, 60);
            textAlign(CENTER, CENTER);
            String msg = (mapGenerationText.length() > 0 ? (mapGenerationText + ".....".substring(5 - (int(millis() / 500.0) % 5))) : "Error loading song!");
            
            text(msg, gameWidth / 2, gameHeight / 2);
        } break;
        case "load_download": {
            activeCursor = ARROW;
            background(0);
            loading_animation.set("u_time", millis() / 1000.0);
            loading_animation_buffer.filter(loading_animation);
            image(loading_animation_buffer, gameWidth / 2, 1.75 / 3.0 * gameHeight);
            String message;
            if(songDownloadProcess.finished) {
                if(delayedSceneTimer == -1) {
                    setSceneDelay("gameSelect", 2500);
                    fadeOpacityStart = 255;
                    fadeDuration = 500;
                    if(songDownloadProcess.code != 0) logmsg("Download error: " + songDownloadProcess.toString());
                }
                message = songDownloadProcess.code == 0 ? "Downloaded!" : "Error";
                initializeSongs();
            }else{
                message = "Downloading." + (".....".substring(5 - (int(millis() / 1000.0) % 5)));
            }
            fill(255);
            textAlign(CENTER, CENTER);
            textFont(songFont, 72);
            text(message, width / 2, gameHeight / 8);
        } break;
        case "levelSummary": {
            int adjustedScoreDuration = min(1500, 100 * score);
            int adjustedHitCountDuration = min(1500, 100 * hitCount);
            int scoreTickStart = 2000;
            int scoreTickEnd = scoreTickStart + adjustedScoreDuration;
            int hitCountStart = scoreTickEnd + 1000;
            int hitCountEnd = hitCountStart + adjustedHitCountDuration;
            int adjustedScore = int(cNorm(durationInto, scoreTickStart, scoreTickEnd) * score);
            int adjustedHitCount = int(cNorm(durationInto, hitCountStart, hitCountEnd) * hitCount);

            boolean playSound = (score > 0 && durationInto > scoreTickStart && durationInto < scoreTickEnd) || (hitCount > 0 && durationInto > hitCountStart && durationInto < hitCountEnd);
            if(playSound && !textSFX.isPlaying()) textSFX.play();

            activeCursor = ARROW;
            background(0);
            if(frameCount % max(1, int(frameRate / 50)) == 0) {
                back.filter(reduceOpacity);
            }
            image(back, 0, 0);
            textAlign(CENTER, CENTER);
            rectMode(CENTER);
            textFont(songFont, 72);
            fill(255);
            text(songP.title, gameWidth / 2, gameHeight / 4.5, 1111, gameHeight);
            textAlign(LEFT, CENTER);
            float titleWidth = min(1111, textWidth(songP.title)) / 2;
            textFont(songFont, 40);
            float calculatedScore = float(score) / (1 + sqrt(float(hitCount))) * pow(1.4 * (songComplexity), 3);
            text("Score:\t\t " + adjustedScore + "\nHit Count:\t\t " + adjustedHitCount + "\nGrade:\t\t " + calculatedScore, gameWidth / 2 - titleWidth, gameHeight / 2.33);

            if(durationInto > 500) songEndScreenSkippable = true;

            if(durationInto > hitCountEnd + 1000) {
                textFont(songFont, 48);
                textAlign(CENTER, CENTER);
                text("<Press any key to continue>", gameWidth / 2, gameHeight / 1.4);
            }

        } break;
    }

    if(show_fade_in) {
        if(durationInto < fadeDuration) {
            fill(0, clampMap(durationInto, 0, fadeDuration, fadeOpacityStart, fadeOpacityEnd));
            noStroke();
            rectMode(CORNER);
            rect(-5, -5, gameWidth + 10, gameHeight + 10);
        }
    }

    
    { //Overlays
        TT("Debug Overlays");
        
        if(checkTimes) {
            orderedTimingDisplay = new ArrayList<timingDisplayElement>(timingDisplay.values());
            orderedTimingDisplay.sort(new timingDisplaySorter());
        }
        
        float timing_rectWidth = 400;
        float timing_textFontSize = 18;
        float timing_topPadding = 75;
        float timing_rightPadding = 2;
        float timing_textPaddingSides = 5;
        float timing_textPaddingVertical = 2;
        float timing_adjTextHeight = timing_textFontSize + timing_textPaddingVertical;
        float timing_rectHeight = orderedTimingDisplay.size() * timing_adjTextHeight + timing_textPaddingVertical * 3;
        float timing_y = timing_textPaddingVertical + timing_topPadding;
        if(TIMING_INFO.state) { //Timing info
            fill(0, 64);
            noStroke();
            rectMode(CORNER);
            if(orderedTimingDisplay.size() > 0) {
                rect(gameWidth - timing_rectWidth - timing_rightPadding, timing_topPadding, timing_rectWidth, timing_rectHeight);
                textFont(defaultFont, timing_textFontSize);
                fill(255);
                int i = 0;
                for(timingDisplayElement e : orderedTimingDisplay) {
                    textAlign(LEFT, TOP);
                    text(e.name, gameWidth - timing_rightPadding + timing_textPaddingSides - timing_rectWidth, timing_y);
                    textAlign(RIGHT, TOP);
                    text(e.display, gameWidth - timing_rightPadding - timing_textPaddingSides, timing_y);
                    i++;
                    timing_y += timing_adjTextHeight;
                }
            }
        }
        
        textFont(defaultFont, 15);
        if(DEBUG_INFO.state) { //Debug log
            msgList.x = gameWidth - 8;
            msgList.y = timing_y;
            msgList.draw(g);
        }
        
        if(SHOW_FPS.state) { //FPS Tracker
            rectMode(CORNER);
            noStroke();
            fill(25, 128);
            rect(gameWidth - 73, 2, 67, 35, 3);
            float warnIntensity = clampMap(fps_tracker, 0, 120, 0, 255);
            fill(255, warnIntensity, warnIntensity);
            textAlign(LEFT, BOTTOM);
            textFont(defaultFont, 15);
            textLeading(15);
            gameFrameCount++;
            gameFrameRateTotal += frameRate;
            text("FPS: " + nf(min(999, round(fps_tracker)), 3) + "\nAdv: " + nf(min(999, round(gameFrameRateTotal / gameFrameCount)), 3), gameWidth - 70, 35);
            fps_tracker = lerp(fps_tracker, frameRate, 1 / frameRate);
        }
        TT("Debug Overlays");
    }
    popMatrix();

    if(scaleFact == scaleFactH) {
        rectMode(CORNER);
        fill(0);
        noStroke();
        float t = (width - gameWidth * scaleFact) / 2.0;
        rect(0, 0, t, height);
        rect(width - t, 0, t, height);
    }else{
        rectMode(CORNER);
        fill(0);
        noStroke();
        float t = (height - gameHeight * scaleFact) / 2.0;
        rect(0, 0, width, t);
        rect(0, height - t, width, t);
    }

    if(activeCursor != previousCursor) {
        if(activeCursor == -1) {
            noCursor();
        }else{
            cursor(activeCursor);
        }
    }
    if(timerUpdateTime == -1) timerUpdateTime = millis() + TIMER_UPDATE_FREQUENCY;
    if(delayedSceneTimer != -1 && millis() > delayedSceneTimer) {
        setScene(delayedSceneScene);
        delayedSceneTimer = -1;
    }
}

void exit() {
    logmsg("Exiting, saving settings.");
    menuSettings.setFloat("volume", volSlider.val);
    menuSettings.setFloat("intensity", difficultySlider.val);
    if(monitorID != monitorOptions.selectedIndex + 1) {
        monitorID = monitorOptions.selectedIndex + 1;
        logmsg("Monitor ID: " + monitorID);
    }
    menuSettings.setInt("monitorID", monitorID);
    saveJSONObject(menuSettings, settingsFileLoc);
    super.exit();
}

void keyPressed(KeyEvent e) {
    if(keyCode == 100 && e.isAltDown()) {
        exit();
    }
    setKeys(true);

    if(key == ESC) {
        key = 0;
        if(gameState.equals("levelSummary") || ((gameState.equals("game") || gameState.equals("pause") || gameState.equals("settings") || gameState.equals("load_download") || gameState.equals("load_song")) && keydown_SHIFT)) {
            gotoLevelSelect();
        }else{
            switch(gameState) {
                case "game": {
                    pause(false);
                    screenshot();
                    setScene("pause");
                } break;
                case "pause": {
                    setScene("game");
                    screenshot();
                    unpause(false);
                } break;
                case "settings": {
                    screenshot();
                    returnScene();
                    volSlider.activate();
                } break;
                case "gameSelect": {
                    exit();
                } break;
                case "title": {
                    if(durationInto > 4000) exit();
                } break;
            }
        }
    }else{
        if(keyCode == cancerKeys[cancerCount]) {
            cancerCount++;
            if(cancerCount == cancerKeys.length) {
                cancerMode = !cancerMode;
                cancerCount = 0;
            }
        }else{
            cancerCount = 0;
        }
        switch(gameState) {
            case "game": {
                if(!allowDebugActions) break;
                switch(keyCode) {
                    case LEFT: {
                        gameMap.song.skip(-15 * 1000);
                        gameMap.resetEnemiesWithIndex();
                        logmsg("Rewinded 15 seconds");
                    } break;
                    case RIGHT: {
                        gameMap.song.skip( 15 * 1000);
                        logmsg("Fowarded 15 seconds");
                    } break;
                    default: {
                        switch(key) {
                            case 'c': {
                                SHOW_SONG_GRAPH.state = !SHOW_SONG_GRAPH.state;
                            } break;
                            case 'i': {
                                NO_DAMAGE.state = !NO_DAMAGE.state;
                                logmsg(NO_DAMAGE.state ? "Enabled invincibility." : "Disabled invincibility");
                            } break;
                            case 'r': {
                                gameMap.spawner.disableNegativeSpawnTimeExclusion = true;
                                gameMap.resetEnemiesWithIndex();
                                gameMap.convertEnemiesToArray();
                                gameMap.loadPatternFile();
                                logmsg("Reset enemy spawns and reloaded pattern file.");
                            } break;
                            default: {
                                String[] currentIndices = new String[] {
                                    gameMap.spawner.locations.get (patternTestLocIndex).ID,
                                    gameMap.spawner.velocities.get(patternTestVelIndex).ID
                                };
                                if(keyCode >= 49 && keyCode <= 57) {
                                    gameMap.generateTestPattern(currentIndices[0], currentIndices[1], gameMap.song.getTime() + keyCode - 48);
                                    logf("Spawned pattern \"%s\"|\"%s\"", currentIndices[0], currentIndices[1]);
                                }else{
                                    if(key == 'l') {
                                        patternTestLocIndex++;
                                        patternTestVelIndex = 0;
                                    }else if(key == 'v') {
                                        patternTestVelIndex++;
                                    }else if(key == 'h') {
                                        patternTestLocIndex = int(random(0, 999999));
                                        patternTestVelIndex = int(random(0, 999999));
                                    }else{
                                        break;
                                    }
                                    String[] newIndices = new String[] {
                                        gameMap.spawner.locations.get (patternTestLocIndex %= gameMap.spawner.locations.size() ).ID,
                                        gameMap.spawner.velocities.get(patternTestVelIndex %= gameMap.spawner.velocities.size()).ID
                                    };
                                    logf("Changed Pattern \"%s\"|\"%s\" --> \"%s\"|\"%s\"", currentIndices[0], currentIndices[1], newIndices[0], newIndices[1]);
                                    if(key == 'h') {
                                        gameMap.generateTestPattern(newIndices[0], newIndices[1], gameMap.song.getTime() + 3);
                                        logf("Spawned pattern \"%s\"|\"%s\"", newIndices[0], newIndices[1]);
                                    }
                                }
                            } break;
                        }
                    } break;
                }
            } break;
            case "gameSelect": {
                if(keyCode == ENTER || keyCode == 32) {
                    selectLevel(songList.get(gameSelect_songSelect_actual));
                }else if(keyCode == UP || key == 'w') {
                    moveSongSel(-1);
                }else if(keyCode == DOWN || key == 's') {
                    moveSongSel(1);
                }
            } break;
            case "title": {
                if(durationInto > 1750 && keyCode != 127) { //For some reason `del` key is pressed automatically sometimes??
                    fadeOpacityStart = 128;
                    fadeDuration = 128;
                    setScene("gameSelect");
                }
            } break;
        }
    }
}

void keyReleased() {
    setKeys(false);
    if(gameState.equals("levelSummary")) transitionFromLevelSummary();
}

void mousePressed() {
    if(gameState.equals("settings")) {
        for(settingButton b: settings) {
            b.checkMouse(MOUSE_PRESS);
        }
        volSlider.checkMouse(MOUSE_PRESS);
        monitorOptions.checkMouse(MOUSE_PRESS);
    }else if(gameState.equals("gameSelect")) {
        difficultySlider.checkMouse(MOUSE_PRESS);
    }
    if(gameState.equals("pause") || gameState.equals("gameSelect") || gameState.equals("settings")) {
        back_button.checkMouse(MOUSE_PRESS);
        if(!gameState.equals("settings")) settings_button.checkMouse(MOUSE_PRESS);
    }
}

void mouseReleased() {
    if(gameState.equals("pause") || gameState.equals("gameSelect")) {
        if(settings_button.active && settings_button.checkMouse(MOUSE_RELEASE)) {
            screenshot();
            setScene("settings");
            updateMonitorOptions();
            unpause(false);
        }
    }
    switch(gameState) {
        case "settings": {
            for(settingButton b: settings) {
                b.checkMouse(MOUSE_RELEASE);
            }
            volSlider.checkMouse(MOUSE_RELEASE);
            monitorOptions.checkMouse(MOUSE_RELEASE);
            if(back_button.active && back_button.checkMouse(MOUSE_RELEASE)) {
                screenshot();
                returnScene();
                volSlider.activate();
            }
        } break;
        case "gameSelect": {
            if(back_button.active && back_button.checkMouse(MOUSE_RELEASE)) {
                exit();
            }
            difficultySlider.checkMouse(MOUSE_RELEASE);
        } break;
        case "pause": {
            if(back_button.active && back_button.checkMouse(MOUSE_RELEASE)) {
                gotoLevelSelect();
            }
        } break;
        case "levelSummary": {
            transitionFromLevelSummary();
        } break;
        case "title": {
            if(durationInto > 1750) {
                fadeOpacityStart = 128;
                fadeDuration = 128;
                setScene("gameSelect");
            }
        }
    }
}

void mouseClicked() {
    if(mouseOverSong) {
        mouseOverSong = false;
        selectLevel(songList.get(gameSelect_songSelect_actual));
    }
}

void mouseWheel(processing.event.MouseEvent event) {
    if(!focused) return;
    float e = ((com.jogamp.newt.event.MouseEvent) event.getNative()).getRotation()[1]; //JAVA MOMENT
    if(e == 0) return;
    if(gameState.equals("game") || (gameState.equals("settings") && volSlider.checkMouse(MOUSE_OVER))) {
        volSlider.checkScroll(e);
        volSlider.activate();
    }else if(gameState.equals("gameSelect")) {
        if(difficultySlider.checkMouse(MOUSE_OVER)) {
            difficultySlider.checkScroll(e);
        }else if(millis() > scrollWait) {
            scrollWait = millis() + max(5, map(sq(e), 0, 0.3, 150, 0));
            moveSongSel(-int(abs(e) >= 1 ? e : e / abs(e)));
        }
    }
}