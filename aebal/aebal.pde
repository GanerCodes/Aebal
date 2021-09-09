import com.jogamp.newt.event.MouseEvent;
import ch.bildspur.postfx.builder.*;
import ch.bildspur.postfx.pass.*;
import ch.bildspur.postfx.*;
import org.apache.commons.text.WordUtils;
import ddf.minim.analysis.*;
import ddf.minim.*;
import java.lang.Math;
import java.util.Map;
import java.io.File;

import java.io.IOException;
import java.nio.file.CopyOption;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;

boolean REFRESH_SONG_METADATA = true; //Recheck song metadata, even if found in cache
boolean DO_ENEMY_SPAWNING     = true;
float TIMER_UPDATE_FREQUENCY = 500; //Debug timer update rate (millis)
float BACKGROUND_COLOR_FADE = 0.275; //Lerp value
float songComplexity = 1.2;
float FPS = 1000; //Wish I could uncap this
int GAMESELECT_SONGDISPLAYCOUNT = 10; //How many songs in the Song Selector to display up and down
int MAX_SIMULTANEOUS_DAMAGE = 100; //Mono got mad at the circles
int gameWidth = 1920, gameHeight = 1080; //xdd

boolean intense, allowDebugActions, cancerMode, keydown_SHIFT, checkTimes, textSFXPlaying, songEndScreenSkippable, mouseOverSong, paused, show_fade_in = true;
int curX, curY, monitorID, cancerCount, score, hitCount, gameFrameCount, durationInto, song_intensity_count, levelSummary_timer, activeCursor = ARROW, deltaMillisStart, gameSelect_songSelect_actual, previousCursor = -1, nextVolumeSFXplay = -1;
float gameFrameRateTotal, scrollWait, fps_tracker, gameSelect_songSelect, sceneOffsetMillis, c, adv, count, objSpawnTimer, ang, noScoreTimer, song_total_intensity, millisDelta, fadeDuration = 5000, fadeOpacityStart = 400, fadeOpacityEnd = 0, grayScaleTimer = 100;
String settingsFileLoc, songDataFileLoc, previousScene, gameState = "title";
int[] cancerKeys = {UP, UP, DOWN, DOWN, LEFT, RIGHT, LEFT, RIGHT, 66, 65, ENTER};
PVector pos, randTrans, chroma_r, chroma_g, chroma_b;
PVector[] previousPos;
Sound song, hitSound, buttonSFX, textSFX, volChangeSFX, songSelChange, gainScore;
Sound[] soundList;
Minim minim;
FFT fft;
color backColor, globalObjColor;
PGraphics back;
PImage screen, text_logo, image_gear, image_back, image_settings, image_paused;
PFont defaultFont, songFont;
PShader bubbleShader, chroma, reduceOpacity, grayScale, bloom;
DecimalFormat timerFormat;
ArrayList<obj> objs = new ArrayList();
ArrayList<bubble> bubbles = new ArrayList();
ArrayList<songElement> songList = new ArrayList();
ArrayList<floatingText> floatingPrompts = new ArrayList();
HashMap<String, Long> timingList;
HashMap<String, String> timingDisplay;
field f;
arrow a;
settingButton[] settings, settings_left, settings_right;
settingButton DEBUG_TIMINGS, DYNAMIC_BACKGROUND_COLOR, DO_POST_PROCESSING, BACKGROUND_BLOBS, BACKGROUND_FADE, DO_HIT_PROMPTS, NO_DAMAGE, RGB_ENEMIES, DO_CHROMA, DO_SHAKE, SHOW_FPS;
button settings_button, back_button;
buttonMenu monitorOptions;
vol_slider volSlider;
difficulty_slider difficultySlider;
JSONObject menuSettings, songCache;
songElement songP;

//Math related constants
float FIFTH_PI = 0.62831853071;

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

int getOnScreenObjCount() {
  int i = 0;
  for(obj o : objs) {
    if(o.onScreen()) {
      i++;
    }
  }
  return i;
}

boolean lineIntersection(PVector a, PVector b, PVector c, PVector d) {
  return (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x)>=0?(d.x-c.x)*(b.y-c.y)-(d.y-c.y)*(b.x-c.x)>=0&&(b.x-a.x)*(d.y-a.y)-(b.y-a.y)*(d.x-a.x)<=0&&(d.x-c.x)*(a.y-c.y)-(d.y-c.y)*(a.x-c.x)<=0:(d.x-c.x)*(b.y-c.y)-(d.y-c.y)*(b.x-c.x)<=0&&(b.x-a.x)*(d.y-a.y)-(b.y-a.y)*(d.x-a.x)>=0&&(d.x-c.x)*(a.y-c.y)-(d.y-c.y)*(a.x-c.x)>=0;
}

boolean rectIntersection(PVector loc, float s, PVector a, PVector b) {
  return lineIntersection(vec2(loc.x - s / 2, loc.y - s / 2), vec2(loc.x + s / 2, loc.y - s / 2), a, b) || 
  lineIntersection(vec2(loc.x + s / 2, loc.y - s / 2), vec2(loc.x + s / 2, loc.y + s / 2), a, b) || 
  lineIntersection(vec2(loc.x + s / 2, loc.y + s / 2), vec2(loc.x - s / 2, loc.y + s / 2), a, b) || 
  lineIntersection(vec2(loc.x - s / 2, loc.y + s / 2), vec2(loc.x - s / 2, loc.y - s / 2), a, b);
}

void moveSongSel(int a) {
  gameSelect_songSelect_actual += a;
  songSelChange.playR();
}

PVector generateLoc(float d) {
  float largestAxisSize = max(gameWidth, gameHeight);
  float a = random(-PI, PI);
  float r = random(largestAxisSize + 12, largestAxisSize + d);
  float cosA = cos(a);
  float sinA = sin(a);
  return vec2(r / cosA * min(abs(cosA), abs(sinA)), r / sinA * min(abs(cosA), abs(sinA)));
}

void addEnemy(PVector loc, PVector vel) {
  objs.add(new obj(loc, vel));
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
}

void returnScene() {
  setScene(previousScene);
}

void gotoLevelSelect() {
  if(song.sound != null) song.sound.close();
  setScene("gameSelect");
  resetLevel();
  screenshot();
}

void transitionFromLevelSummary() {
  if(songEndScreenSkippable) {
    setScene("gameSelect");
    song.sound.close();
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
  for(String m : getMonitors()) {
    monitorOptions.addButton(m);
    if(++i == monitorID) monitorOptions.setState();
  }
}

void pause(boolean setFPS) {
  paused = true;
  if(gameState.equals("game")) { 
    if(song.sound.isPlaying()) {
      deltaMillisStart = millis();
      song.sound.pause();
      if(setFPS) frameRate(120);
    }
  }
  return;
}

void unpause(boolean setFPS) {
  paused = false;
  if(gameState.equals("game")) {
    if(!song.sound.isPlaying() && song.sound.position() < song.sound.length()) {
      millisDelta -= deltaMillisStart - millis(); //Subtract missed time from new adjMillis
      song.sound.play();
      if(setFPS) frameRate(FPS);
    }
  }
}

void setGlobalVolume(float vol) {
  if(vol == volSlider.val_min) vol = -10000;
  for(Sound s : soundList) {
    s.setVol(vol);
  }
}

void fadeBack(float mul, int opacity) {
  rectMode(CORNER);
  imageMode(CORNER);
  background(0);
  image(back, 0, 0);
  fill(0, constrain(durationInto * mul * 1.25, 0, opacity));
  rect(-5, -5, gameWidth + 10, gameHeight + 10);
}

void resetEnemies(int scoreDeduction) {
  for(obj o : objs) {
    o.timer = 0;
    boolean isInside = (scoreDeduction > 0) && o.inBox();
    if(isInside) score--;
    if(DO_HIT_PROMPTS.state) floatingPrompts.add(new floatingText(o.loc.x, o.loc.y, 1500, str(-scoreDeduction - (isInside ? 1 : 0))));
  }
}

void gotHit(int scoreDeduction, int timerDelay, boolean clearEnemies, int individualPointReduction) {
  grayScaleTimer = 0;
  if(!NO_DAMAGE.state) {
    hitCount++;
    score -= min(scoreDeduction, MAX_SIMULTANEOUS_DAMAGE);
    noScoreTimer = timerDelay;
    if(clearEnemies) resetEnemies(individualPointReduction);
    hitSound.playR();
  }
}

void resetLevel() {
  score = 0;
  hitCount = 0;
  levelSummary_timer = 0;
  song_total_intensity = 0;
  song_intensity_count = 0;
  textSFX.sound.pause();
  textSFX.sound.rewind();
  f = new field(max(gameWidth, gameHeight));
  a = new arrow(gameWidth / 2, gameHeight / 2, 0, 500, 1700);
  back.beginDraw();
  back.clear();
  back.endDraw();
}

String fileName(String path) {
  return new File(path).getName().replaceFirst("[.][^.]+$", "");
}

void loadSong() {
  song.setSound(minim.loadFile(songP.fileName));
  song.setDefaultVolume(-20);
  song.sound.play();
  fft = new FFT(song.sound.bufferSize(), song.sound.sampleRate());
  setScene("game");
}

void selectLevel(songElement song) {
  if(song.fileName.equals("///addSong")) {
    selectInput("Select a music file:", "songSelected");
    return;
  }
  songP = song;
  setScene("loading");
  resetEnemies(0);
  resetLevel();
  bubbles = new ArrayList();
  floatingPrompts = new ArrayList();
  bubbleLayer = createGraphics(gameWidth, gameHeight, P2D);
  for(int i = 0; i < 4; i++) {
    bubbles.add(new bubble(vec2(s_random(0, gameWidth), s_random(0, gameHeight))));
  }
  int randomSeed = song.title.hashCode();
  println("Random seed for \"" + song.title + "\": " + randomSeed);
  randomSeed(randomSeed);
  unimportantRandoms.setSeed(randomSeed);
  thread("loadSong");
}

void songSelected(File file) {
  if(file == null) return;
  songList.add(songList.size() - 1, new songElement(songCache, file.getAbsolutePath()));
  try {
    Files.copy(Paths.get(file.getAbsolutePath()), Paths.get(sketchPath("songs/"+file.getName())));
  }catch(IOException e) {
    e.printStackTrace();
  }
}

float adjMillis() {
  return millis() + millisDelta;
}

class Sound {
  AudioPlayer sound;
  float defaultVolume, vol;
  Sound(AudioPlayer sound, float defaultVolume) {
    this.sound = sound;
    this.defaultVolume = defaultVolume;
    this.vol = 1;
    sound.setGain(defaultVolume);
  }
  Sound(AudioPlayer sound) {
    this.sound = sound;
    this.defaultVolume = 0;
    this.vol = 1;
  }
  Sound(float defaultVolume) {
    this.defaultVolume = 0;
    this.vol = 1;
  }
  void setVol(float vol) {
    this.vol = vol;
    if(sound != null) sound.setGain(defaultVolume + vol);
  }
  void setDefaultVolume(float defaultVolume) {
    this.defaultVolume = defaultVolume;
    if(sound != null) sound.setGain(defaultVolume + vol);
  }
  void setSound(AudioPlayer sound) {
    this.sound = sound;
    this.setVol(vol);
  }
  void playR() {
    this.sound.play();
    this.sound.rewind();
  }
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
      Sound songTmp = new Sound(minim.loadFile(fileName), song.defaultVolume);
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

class field {
  float size;
  boolean isOutside;
  field(float size) {
    this.size = size;
    this.isOutside = false;
  }
  void draw() {
    rectMode(CENTER);
    noFill();
    strokeWeight(10);
    stroke(255);
    rect(gameWidth / 2, gameHeight / 2, min(size, gameWidth - 5), min(size, gameHeight - 5));
  }
  void update() {
    float mn = size / 2 - 10 - 5;
    pos.x = constrain(curX, max(gameWidth  / 2 - mn, 15), min(gameWidth  / 2 + mn, gameWidth  - 15));
    pos.y = constrain(curY, max(gameHeight / 2 - mn, 15), min(gameHeight / 2 + mn, gameHeight - 15));
    isOutside = curX != pos.x || curY != pos.y;
  }
}

class bubble {
  PVector loc, vel;
  float timer_offset;
  int size = 750;
  bubble(PVector loc) {
    this.loc = loc;
    float ang = s_random(0, TWO_PI);
    vel = mulVec(
      PVector.fromAngle(ang).mult(random(1.5, 2.5)),
      vec2(rSign(), rSign())
    );
    timer_offset = s_random(0, 1000000);
  }
  void update() {
    loc.add(PVector.mult(vel, max(0.01, pow(2 * max(0.01, c - 0.08), 3))));

    PVector adv = vec2();
    for(bubble b : bubbles) {
      adv.add(b.loc);
    }
    vel.sub(adv.div(bubbles.size()).sub(loc).normalize().div(125));

    float adjSize = size / 2;
    if(loc.x > gameWidth  + adjSize) { loc.x = -adjSize; } else if(loc.x < -adjSize) { loc.x = gameWidth  + adjSize; }
    if(loc.y > gameHeight + adjSize) { loc.y = -adjSize; } else if(loc.y < -adjSize) { loc.y = gameHeight + adjSize; }
  }
}

PGraphics bubbleLayer;
void drawBubbles(PGraphics base) {
  FloatList coord_x = new FloatList();
  FloatList coord_y = new FloatList();
  FloatList timeOff = new FloatList();
  float currentTime = adjMillis() / 1000.0;
  for(bubble b : bubbles) {
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
  void update() {
    oT += oTV * (200 / frameRate);
    oT = constrain(oT, 0, 255);
    rot += 0.05 * (60 / frameRate);
    d1 = -mn - (sz) * (cos(rot) + 1);
    PVector org = vec2(x + cos(a) * d1, y + sin(a) * d1);
    if(oT > 120 && (
      rectIntersection(pos, 20, org, PVector.add(org, PVector.fromAngle(a + FIFTH_PI).mult(30))) || 
      rectIntersection(pos, 20, org, PVector.add(org, PVector.fromAngle(a - FIFTH_PI).mult(30))) ||
      (cancerMode && (
        rectIntersection(pos, 22.5, org, vec2(x + cos(a) * d2, y + sin(a) * d2)) ||
        lineIntersection(org, vec2(x + cos(a) * d2, y + sin(a) * d2), previousPos[previousPos.length - 1], pos)
      ))
    )) {
      if(noScoreTimer <= 0) {
        int scorePer = cancerMode ? 4 : 2;
        gotHit(getOnScreenObjCount() * scorePer + 3, 60, true, scorePer);
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

class obj {
  PVector loc, ploc, vel;
  int timer;
  obj(PVector loc, PVector vel) {
    this.loc = loc;
    this.ploc = loc;
    this.vel = vel;
    timer = 1;
  }
  obj(float x, float y, float vx, float vy) {
    this.loc = new PVector(x, y);
    this.ploc = this.loc.copy();
    this.vel = new PVector(vx, vy);
    timer = 1;
  }
  
  boolean onScreen() {
    return (loc.x > -10 && loc.x < gameWidth + 10 && loc.y > -10 && loc.y < gameHeight + 10);
  }
  boolean inBox() {
    return (loc.x > gameWidth / 2 - (f.size / 2) - 2 && loc.x < gameWidth / 2 + (f.size / 2) + 2 && loc.y > gameHeight / 2 - (f.size / 2) - 2 && loc.y < gameHeight / 2 + (f.size / 2) + 2);
  }
  void move() {
    float speed = int(c * 14.5) / 6.25 + 0.1;

    ploc = loc.copy();
    loc.add(vel.copy().mult(speed * (60 / frameRate)));
    if (timer == 3) {
      score++;
      timer = 0;
    }
    if (timer == 2 && !onScreen()) {
      timer = 3;
    }
    if (timer == 1 && onScreen()) {
      timer = 2;
    }

    if (loc.x > pos.x - 20 && loc.x < pos.x + 20 && loc.y > pos.y - 20 && loc.y < pos.y + 20) {
      gotHit(getOnScreenObjCount(), 30, true, 1);
    }
  }
  void draw(PGraphics base) {
    if(BACKGROUND_FADE.state) {
      // base.noStroke();
      // base.circle(ploc.x, ploc.y, 20);
      base.strokeWeight(20);
      back.stroke(globalObjColor);
      back.strokeCap(SQUARE);
      base.line(ploc.x, ploc.y, loc.x, loc.y);
      base.noStroke();
      base.circle(loc.x, loc.y, 20);
    }else{
      base.circle(loc.x, loc.y, 20);
    }
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
  }catch(Throwable e) {
    println("Settings file not found or was corrupt: " + e);
    monitorID = 1;
    fullScreen(P2D, 1);
  }

  smooth(4);
  PJOGL.setIcon(sketchPath("assets/images/aebal.png"));
}

void setup() {
  frameRate(FPS);
  surface.setTitle("Aebal");
  surface.setResizable(true);

  monitorOptions = new buttonMenu(165, 65, 200, 30, color(225), color(220), color(215), color(30), color(40), color(50));
  monitorOptions.addButton("1");
  monitorOptions.setState();
  monitorOptions.addButton("asdf");
  monitorOptions.addButton("yo mama");


  if(args != null && args.length > 0) {
    for(int i = 0; i < args.length; i++) {
      if(args[i].trim().toLowerCase().equals("debug")) {
        allowDebugActions = true;
      }
    }
  }

  unimportantRandoms = new Random();
  timingList    = new HashMap();
  timingDisplay = new HashMap();
  timerFormat = new DecimalFormat("##.####");
  timerFormat.setMinimumIntegerDigits(2);
  timerFormat.setMinimumFractionDigits(4);


  minim = new Minim(this);
  soundList = new Sound[] {
    songSelChange = new Sound(minim.loadFile(sketchPath("assets/SFX/songSelChange.wav")), -15),
    volChangeSFX  = new Sound(minim.loadFile(sketchPath("assets/SFX/volChange.wav"    )), -12),
    buttonSFX     = new Sound(minim.loadFile(sketchPath("assets/SFX/button.wav"       )), -12),
    gainScore     = new Sound(minim.loadFile(sketchPath("assets/SFX/gainScore.wav"    )), -20),
    hitSound      = new Sound(minim.loadFile(sketchPath("assets/SFX/hit.wav"          )), -3 ),
    textSFX       = new Sound(minim.loadFile(sketchPath("assets/SFX/textSFX.wav"      )), -18),
    song          = new Sound(-20)
  };
  textSFX.sound.setLoopPoints(20, 500);

  color setting_default_t = #33D033;
  color setting_default_t_over = #00FF00;
  color setting_default_t_active = #99FF99;
  color setting_default_f = #D03333;
  color setting_default_f_over = #FF0000;
  color setting_default_f_active = #FF9999;

  volSlider        = new vol_slider       (gameWidth / 2, gameHeight / 1.175, 600, 35, 0             , -30 , 20, "Volume"    , #3333CC, #3355CC, #2222DD, #2266DD, #1111FF, #1177FF);
  difficultySlider = new difficulty_slider(1357, gameHeight * 4/5, 500, 35, songComplexity, 0.75, 2 , "Difficulty", #3333CC, #3355CC, #2222DD, #2266DD, #1111FF, #1177FF);
  settings = new settingButton[] {
    DYNAMIC_BACKGROUND_COLOR = new settingButton(0, 0, 75, 75, 5, "Dynamic Background"  , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
    DO_POST_PROCESSING       = new settingButton(0, 0, 75, 75, 5, "Color Shaders"       , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
    BACKGROUND_BLOBS         = new settingButton(0, 0, 75, 75, 5, "Background Blobs"    , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
    BACKGROUND_FADE          = new settingButton(0, 0, 75, 75, 5, "Background Fade"     , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
    DO_HIT_PROMPTS           = new settingButton(0, 0, 75, 75, 5, "Score Ticks"         , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
    DEBUG_TIMINGS            = new settingButton(0, 0, 75, 75, 5, "Timing Info"         , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
    RGB_ENEMIES              = new settingButton(0, 0, 75, 75, 5, "RGB Enemies"         , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
    NO_DAMAGE                = new settingButton(0, 0, 75, 75, 5, "Invincible"          , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
    DO_CHROMA                = new settingButton(0, 0, 75, 75, 5, "Chromatic Aberration", setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
    DO_SHAKE                 = new settingButton(0, 0, 75, 75, 5, "Shake"               , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active),
    SHOW_FPS                 = new settingButton(0, 0, 75, 75, 5, "FPS Tracker"         , setting_default_t, setting_default_t_over, setting_default_t_active, setting_default_f, setting_default_f_over, setting_default_f_active)
  };
  settings_left  = new settingButton[] {RGB_ENEMIES, DO_CHROMA, DO_SHAKE, BACKGROUND_FADE, DO_HIT_PROMPTS};
  settings_right = new settingButton[] {DYNAMIC_BACKGROUND_COLOR, DO_POST_PROCESSING, BACKGROUND_BLOBS, SHOW_FPS, DEBUG_TIMINGS};
  for(int i = 0; i < settings_left.length; i++) {
    settings_left[i].x = 100;
    settings_left[i].y = gameHeight / 1.65 - settings_left.length   * 50 + i * 100;
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
    for(settingButton b : settings) {
      if(!menuSettings.isNull(b.txt)) {
        b.state = menuSettings.getBoolean(b.txt);
      }
    }
    if(!menuSettings.isNull("volume")) {
      volSlider.val = menuSettings.getFloat("volume");
    }
  }catch(Throwable e) {
    println("Settings file not found or was corrupt: " + e);
    NO_DAMAGE.state     = false;
    DEBUG_TIMINGS.state = false;
    menuSettings = new JSONObject();
    for(settingButton b : settings) {
      menuSettings.setBoolean(b.txt, b.state);
    }
    menuSettings.setInt("monitorID", 1);
    saveJSONObject(menuSettings, settingsFileLoc);
  }


  image_back     = loadImage(sketchPath("assets/Images/backarrow.png" ));
  text_logo      = loadImage(sketchPath("assets/Images/aebal_text.png"));
  image_gear     = loadImage(sketchPath("assets/Images/gear.png"      ));
  image_settings = loadImage(sketchPath("assets/Images/settings.png"  ));
  image_paused   = loadImage(sketchPath("assets/Images/paused.png"    ));


  try {
    assert new File(sketchPath(songDataFileLoc)).isFile();
    songCache = loadJSONObject(songDataFileLoc);
  }catch(Throwable e) {
    println("Song data file not found or was corrupt: " + e);
    songCache = new JSONObject();
  }

  for(String songName : new File(sketchPath("Songs")).list()) {
    try {
      songElement songElm = new songElement(songCache, sketchPath("Songs/" + songName));
      songList.add(songElm);
    }catch(Throwable e) {
      println("Song file unreadable: " + songName);
    }
  }
  saveJSONObject(songCache, songDataFileLoc);
  songList.add(new songElement("///addSong", "+ Add Song"));

  gameSelect_songSelect_actual = songList.size() / 2;
  gameSelect_songSelect = gameSelect_songSelect_actual;

  settings_button = new button(gameWidth - 65, gameHeight - 65, 85, 85, 5, image_gear, color(45), color(75), color(128));
  back_button     = new button(65, gameHeight - 65, 85, 85, 5, image_back, color(45), color(75), color(128));

  defaultFont = createFont(sketchPath("assets/fonts/defaultFont.ttf"), 128);
  songFont    = createFont(sketchPath("assets/fonts/songFont.ttf"   ), 64 );

  back  = createGraphics(gameWidth, gameHeight, P2D);
  strokeCap(PROJECT);

  f = new field(max(gameWidth, gameHeight));
  a = new arrow(gameWidth / 2, gameHeight / 2, 0, 500, 1700);
  chroma        = loadShader(sketchPath("assets/shaders/rgb_offset.glsl"   ));
  grayScale     = loadShader(sketchPath("assets/shaders/gray.glsl"         ));
  bubbleShader  = loadShader(sketchPath("assets/shaders/bubble.glsl"       ));
  reduceOpacity = loadShader(sketchPath("assets/shaders/reduceOpacity.glsl"));
  bloom         = loadShader(sketchPath("assets/shaders/bloom.glsl"        ));
  chroma_r = vec2();
  chroma_g = vec2();
  chroma_b = vec2();

  pos = vec2(gameWidth / 2, gameHeight / 2);
  previousPos = new PVector[1];
  for(int i = 0; i < previousPos.length; i++) {
    previousPos[i] = pos.copy();
  }

  updateMonitorOptions();
}

void draw() {
  if(focused || gameState.equals("title")) {
    if(paused) unpause(true);
  }else{
    if(!paused) pause(true);
    return;
  }

  float scaleFactW = float(width)  / gameWidth ;
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
  if(DEBUG_TIMINGS.state) {
    if(millis() > timerUpdateTime) {
      checkTimes = true;
      timerUpdateTime = millis() + TIMER_UPDATE_FREQUENCY;
    }else{
      checkTimes = false;
    }
  }
  
  durationInto = int(adjMillis() - sceneOffsetMillis);

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
    } break;
    case "gameSelect": {
      activeCursor = ARROW;
      background(0);
      stroke(128);
      strokeWeight(8);
      strokeCap(ROUND);
      line(gameWidth / 2, gameHeight * 1/4, gameWidth / 2, gameHeight * 8 / 9);
      strokeCap(PROJECT);
      imageMode(CENTER);
      noStroke();
      image(text_logo, gameWidth / 2, text_logo.height / 2);
      gameSelect_songSelect_actual = Math.floorMod(gameSelect_songSelect_actual, songList.size());
      gameSelect_songSelect = lerp(gameSelect_songSelect, gameSelect_songSelect_actual, 0.1);

      int min_s = gameSelect_songSelect_actual - GAMESELECT_SONGDISPLAYCOUNT;
      int max_s = min(gameSelect_songSelect_actual + GAMESELECT_SONGDISPLAYCOUNT, songList.size());
      textFont(defaultFont, 50);

      pushMatrix();
      float tx = -525, ty = 150;
      translate(tx, ty);
      float y_offset = 0;
      for(int i = min_s; i < max_s; i++) { //I tryharded this portion, give me money
        float v = 16;
        float fontSize = max(2, 50 - 7 * pow(abs(i - int(v * gameSelect_songSelect) / v), 0.9));
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
              for(int tmp = 0; tmp < newlineCountShort; tmp++) {newLines += '\n';}
              String detailsLeft = "Title:"+newLines;
              String detailsRight = songTitleShort;
              if(currentElement.author != null && currentElement.author.length() > 0) {
                detailsLeft += "\nArtist:";
                detailsRight += '\n' + currentElement.author;
              }
              if(currentElement.duration != null && currentElement.duration.length() > 0) {
                detailsLeft += "\nDuration:";
                detailsRight += '\n' + currentElement.duration;
              }

              text(detailsLeft , gameWidth / 2 + descSize / 2 - tx, gameHeight * 1/4 + 3 - ty);
              text(detailsRight, gameWidth / 2 + descSize / 2 + 10 * descSize - tx, gameHeight * 1/4 + 3 - ty);
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

    case "game": {
      TT("Physics");
      fft.forward(song.sound.mix);
      float tmp_intensity = findComplexity(song.sound.mix.toArray()) * (0.65 + (0.2 + song.sound.mix.level()) / 2.0);
      if(tmp_intensity < 0.1) {
        tmp_intensity = pow(tmp_intensity, 1.0 / 3) / 4.65;
      }
      c = tmp_intensity * songComplexity;
      song_total_intensity += tmp_intensity;
      song_intensity_count++;
      noScoreTimer -= (60 / frameRate);
      objSpawnTimer -= c * 2 * (60 / frameRate);

      for(int i = 0; i < previousPos.length - 1; i++) {
        previousPos[i] = previousPos[i + 1];
      }
      previousPos[previousPos.length - 1] = pos.copy();
      pos.set(curX, curY);
    
      f.size = constrain(f.size - constrain(pow(15 * (c - 0.25), 3), -100, 25) * (60 / frameRate), 500, max(gameWidth, gameHeight));
      f.update();
    
      intense = f.size <= 505;

      { //Physics
        if (objSpawnTimer <= 0 && DO_ENEMY_SPAWNING) { //Object spawning
          float speed = random(5, 12) * (1 + 3.5 * c);
          
          float v = min(gameHeight, f.size * 1.5) / 2;
          PVector loc = random(0, 1) <= 0.15 ? pos.copy() : vec2(gameWidth / 2 + random(-v, v), gameHeight / 2 + random(-v, v));
          float dis = 1.5 * sqrt(sq(gameWidth) + sq(gameHeight));
          float n = int(random(3, 3 + c * 4));
        
          float rng = random(c / 10, max(1, c * 2));
          if(cancerMode) rng = min(1, rng * 2.5);
          int SPAWN_PATTERN = 0;
          if(random(0, 1) < min(0.15, (c - 0.25))) {
            objSpawnTimer = max(objSpawnTimer, 0) + c * 15;
            if(rng < 0.3) {
              SPAWN_PATTERN = 1;
            }else if(rng < 0.5) {
              SPAWN_PATTERN = 2;
            }else if(rng < 0.7) {
              SPAWN_PATTERN = 3;
            }else if(rng < 0.875) {
              SPAWN_PATTERN = 4;
            }else{
              SPAWN_PATTERN = 5;
            }
          }

          switch(SPAWN_PATTERN) {
            case 0: { //Single

              loc = generateLoc(300);
              float TLX = lerp(random(gameWidth  / 2 - f.size / 2, gameWidth  / 2 + f.size / 2), pos.x, random(0, 1));
              float TLY = lerp(random(gameHeight / 2 - f.size / 2, gameHeight / 2 + f.size / 2), pos.y, random(0, 1));
              addEnemy(loc, PVector.fromAngle(atan2(TLY - loc.y, TLX - loc.x)).mult(speed));
            } break;
            case 1: { //star, circle, spiral

              boolean isSpiral = random(0, 1) < 0.2;
              if(isSpiral) {
                speed /= 2;
              }else{
                speed /= 1.2;
              }
              float isCircle = random(0, 1) < 0.33 ? random(450, 550) - c * 125 : 0;
              if(isCircle > 0) {
                n = n * 3 + int(c * 3.5);
              }
              float rad = random(0, 1) <= 0.5 ? 0 : random(0, 250);
              float adder = isSpiral ? (0.35 - min(c, 1.5) / 15) : (2 * PI) / n;
              for(float a = 0; a < TWO_PI; a += adder) {
                float adjA = a + QUARTER_PI;
                float adjDist = isSpiral ? dis + a * 700 : dis;

                PVector spawnLoc = loc.copy().add(PVector.fromAngle(adjA).mult(adjDist)).add(vec2(sin(adjA), cos(adjA)).mult(rad));
                if(isCircle > 0) spawnLoc.add(PVector.fromAngle(a + HALF_PI).mult(isCircle));
                addEnemy(spawnLoc, PVector.fromAngle(adjA).mult(-speed));
              }
            } break;
            case 2: { //Line

              float a = random(0, 2 * PI);
              speed /= 1.1;
              n = 3 + c * 14;
              for(int l = -int(n); l <= n; l++) {
                float nX = 2 * dis * cos(a) + l * (dis / n) * cos(a + HALF_PI);
                float nY = 2 * dis * sin(a) + l * (dis / n) * sin(a + HALF_PI);
                objs.add(
                  new obj(
                    nX, nY, -speed * cos(a), -speed * sin(a)
                  )
                );
              }
            } break;
            case 3: { //Square & Circle

              float sz = 50 + c * 80;
              float screenAngle = random(0, TWO_PI);
              float objRot = random(0, TWO_PI) + HALF_PI;
              boolean mode = random(0, 1) > 0.5;
              float density = max(0.2, 0.5 - c / 3) / (mode ? 1.4 : 1);
              speed /= 2;
              for(float x = -1; x < 1; x += density) {
                for(float y = -1; y < 1; y += density) {
                  if(mode && sq(x) + sq(y) > 1) continue;
                  objs.add(new obj(
                    loc.x + dis*cos(screenAngle) + sz*(x*cos(objRot) - y*sin(objRot)),
                    loc.y + dis*sin(screenAngle) + sz*(x*sin(objRot) + y*cos(objRot)),
                    -speed*cos(screenAngle), -speed*sin(screenAngle)
                  ));
                }
              }
            } break;
            case 4: { //Triangle
              
              float sz = 40 - c * 25;
              n = 2 * (n + int(c * 2.5)) + 1;
              float screenAngle = random(0, TWO_PI);
              float objRot = screenAngle + HALF_PI;
              speed /= 2;
              for(int i = 0; i < n; i++) {
                float x = (i - floor(n / 2));
                float y = (floor(n / 2 - abs(x)));
                objs.add(new obj(
                  loc.x + dis*cos(screenAngle) + sz*(x*cos(objRot) - y*sin(objRot)),
                  loc.y + dis*sin(screenAngle) + sz*(x*sin(objRot) + y*cos(objRot)),
                  -speed*cos(screenAngle), -speed*sin(screenAngle)
                ));
              }
            } break;
            case 5: { //Triangle, square, pentagon, hexagon

              n = int(random(3, 6.25));
              int d = 1 + int(c * 5);
              float sz = random(250, 750 - c * 250);
              float objRot = random(0, TWO_PI);
              loc.lerp(vec2(gameWidth / 2, gameHeight / 2), random(0, 1));
              for(float i = 0; i < TWO_PI; i += TWO_PI / (n * d)) {
                PVector objLoc = PVector.fromAngle(TWO_PI / n * floor(n * i / TWO_PI)).lerp(PVector.fromAngle(TWO_PI / n * ceil(n * i / TWO_PI)), (i * n / TWO_PI) % 1.0).rotate(objRot).mult(sz).add(loc);
                PVector objVel = PVector.sub(loc, objLoc).setMag(1).rotate(HALF_PI);
                objs.add(new obj(
                  PVector.add(objLoc, PVector.mult(objVel, -dis)),
                  objVel.setMag(speed / 2)
                ));
              }
            } break;
          }
          objSpawnTimer = max(objSpawnTimer, 0) + (30 - c * 10);
        }
      
        for (int i = objs.size() - 1; i > -1; i--) {
          obj cc = objs.get(i);
          if (cc.timer <= 0) {
            objs.remove(i);
            continue;
          }
          cc.move();
        }

        imageMode(CORNER);
        rectMode(CENTER);
        activeCursor = -1;

        randTrans = DO_SHAKE.state ? vec2(s_random(10 * -c, 10 * c), s_random(10 * -c, 10 * c)) : vec2();
        ang += (0.001 + constrain(c / 75, 0, 0.05)) * (200 / frameRate);
        a.speed = constrain(a.speed * (1 + constrain((c - 0.25) / 100, -0.05, 0.05)), 0.5, 1.75);
        float dfc = sqrt(sq(gameWidth) + sq(gameHeight));
        
        a.x = cos(ang) * dfc + gameWidth / 2;
        a.y = sin(ang) * dfc + gameHeight / 2;
        a.a = atan2(a.y - gameHeight / 2, a.x - gameWidth / 2);
        if(a.oT > 0) {
          a.update();
        }
        if(f.size <= 700) {
          a.spawn();
        }else{
          a.despawn();
        }

        if(BACKGROUND_BLOBS.state) {
          for(bubble b : bubbles) {
            b.update();
          }
        }
        score = max(0, score);
      }
      TT("Physics");
      
      if(DYNAMIC_BACKGROUND_COLOR.state) {
        colorMode(HSB);
        color updatedColor;
        updatedColor = intense ? color((100 + (c * 500)) % 255, 255, (c - 0.25) * 200) : color((c * 200) % 255);
        backColor = lerpColor(backColor, updatedColor, BACKGROUND_COLOR_FADE);
        background(hue(backColor), saturation(backColor), brightness(backColor) / 3.1);
        colorMode(RGB);
      }else{
        background(0);
      }

      if(BACKGROUND_FADE.state && frameCount % max(1, int(frameRate / 200)) == 0) {
        TT("Fade");
        back.filter(reduceOpacity);
        TT("Fade");
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
        back.fill(255);
        back.stroke(255);
        back.strokeWeight(5);
        back.line(previousPos[previousPos.length - 1].x, previousPos[previousPos.length - 1].y, pos.x, pos.y);
      }
      colorMode(HSB);
      globalObjColor = lerpColor(globalObjColor, (intense && RGB_ENEMIES.state) ? color((adjMillis() / 5.0) % 255, 164, 255) : color(0, 255, 255), 4.0 / frameRate);

      if(BACKGROUND_FADE.state) {
        back.stroke(globalObjColor);
      }else{
        back.noStroke();
      }
      back.fill(globalObjColor);
      TT("Enemies");
      for(obj o : objs) {
        o.draw(back);
      }
      TT("Enemies");
      a.drawHead(back, 128);
      back.endDraw();

      imageMode(CORNER);
      image(back, 0, 0);
      
      a.drawLine();
      stroke(255);
      a.drawHead(g, 0);
      noStroke();
      fill(255);
      rect(pos.x, pos.y, 20, 20);
      if(f.isOutside) {
        colorMode(RGB);
        fill(255, 0, 0);
        rect(curX, curY, 10, 10);
      }

      pushMatrix(); {
        if (intense) translate(randTrans.x, randTrans.y);
        strokeWeight(10);
        stroke(255);
        f.draw();
      } popMatrix();

      //post processing
      if(DO_POST_PROCESSING.state) {
        TT("PostProcessing");
        bloom.set("bloom_intensity", 2.0 * c / 81.0);
        if(intense) {
          bloom.set("saturation", 1 + c / 3.33);
        }else{
          bloom.set("saturation", 1.0);
        }
        filter(bloom);
        TT("PostProcessing");
      }
      if(DO_CHROMA.state) {
        TT("ChromaAbbr");
        float prec = 0.75;
        PVector nextChroma_r, nextChroma_g, nextChroma_b;
        PVector zeroVector = vec2();
        if(intense) {
          if(c >= songComplexity) {
            float offset = (2 * ((2 * c + 0.5) % 1) - 1) / 5;
            float offset_y = s_random(-c / 6, c / 6);
            if(s_random(0, 1) < 0.5) {
              nextChroma_r = vec2( offset, s_random(-offset_y, offset_y));
              nextChroma_g = vec2(-offset, s_random(-offset_y, offset_y));
              nextChroma_b = vec2(s_random(-offset, offset), s_random(-offset_y, offset_y));
            }else{
              nextChroma_r = vec2(s_random(-offset_y, offset_y), offset);
              nextChroma_g = vec2(s_random(-offset_y, offset_y), -offset);
              nextChroma_b = vec2(s_random(-offset_y, offset_y), s_random(-offset, offset));
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
        chroma_r = chroma_r.mult(prec).add(nextChroma_r.mult(1 - prec));
        chroma_g = chroma_g.mult(prec).add(nextChroma_g.mult(1 - prec));
        chroma_b = chroma_b.mult(prec).add(nextChroma_b.mult(1 - prec));
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

      colorMode(RGB);
      fill(144, 227, 154);
      textSize(50);
      textAlign(LEFT, TOP);
      text("Score: " + score, 10, 0);

      fill(255, 200);
      textFont(songFont, 48);
      textAlign(LEFT, BOTTOM);
      text(songP.title, 10, gameHeight - 10);
      float durationComplete = ((float)song.sound.position()) / song.sound.length();
      rectMode(CORNERS);
      noStroke();
      fill(255);
      rect(0, gameHeight - 4, gameWidth * durationComplete, gameHeight);
      fill(64);
      rect(gameWidth * durationComplete, gameHeight - 4, gameWidth, gameHeight);

      textFont(defaultFont);

      if(DO_POST_PROCESSING.state) {
        grayScaleTimer += 4 / frameRate;
        float adjustedGrayScale = -0.8 * sq(grayScaleTimer) + 2.4 * grayScaleTimer;
        if(adjustedGrayScale > 0.0) {
          grayScale.set("power", min(adjustedGrayScale, 0.75));
          filter(grayScale);
        }
      }

      if(!song.sound.isPlaying()) {
        if(levelSummary_timer == 0) {
          if(objs.size() > 0 && DO_HIT_PROMPTS.state) {
            gainScore.playR();
            for(int i = objs.size() - 1; i > -1; i--) {
              obj o = objs.get(i);
              floatingPrompts.add(new floatingText(o.loc.x, o.loc.y, 1500, "+1"));
              objs.remove(i);
              score++;
            }
            levelSummary_timer = int(adjMillis() + 2000);
          }else{
            levelSummary_timer = 1;
          }
        }else if(adjMillis() > levelSummary_timer) {
          levelSummary_timer = 0;
          setScene("levelSummary");
          textSFXPlaying = false;
          screenshot();
          println("Average calculated intensity: " + song_total_intensity / song_intensity_count);
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
      for(settingButton b : settings_left) {
        b.draw();
      }
      textAlign(RIGHT, CENTER);
      for(settingButton b : settings_right) {
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
    case "loading": {
      background(0);
      fill(255);
      textFont(songFont, 60);
      textAlign(CENTER, CENTER);
      text("Loading...", gameWidth / 2, gameHeight / 2);
    } break;
    case "levelSummary": {
      int adjustedScoreDuration    = min(1500, 100 * score   );
      int adjustedHitCountDuration = min(1500, 100 * hitCount);
      int scoreTickStart = 2000;
      int scoreTickEnd   = scoreTickStart + adjustedScoreDuration;
      int hitCountStart  = scoreTickEnd + 1000;
      int hitCountEnd    = hitCountStart + adjustedHitCountDuration;
      int adjustedScore    = int(cNorm(durationInto, scoreTickStart, scoreTickEnd) * score   );
      int adjustedHitCount = int(cNorm(durationInto, hitCountStart , hitCountEnd ) * hitCount);

      boolean playSound = (score > 0 && durationInto > scoreTickStart && durationInto < scoreTickEnd) || (hitCount > 0 && durationInto > hitCountStart && durationInto < hitCountEnd);
      if(!textSFXPlaying && playSound) { //Because .isPlaying() returns false for a second after it loops
        textSFXPlaying = true;
        textSFX.sound.loop();
      }
      if(textSFXPlaying && !playSound) {
        textSFXPlaying = false;
        textSFX.sound.pause();
        textSFX.sound.rewind();
      }

      activeCursor = ARROW;
      background(0);
      if(frameCount % max(1, int(frameRate / 50)) == 0) {
        back.filter(reduceOpacity);
      }
      image(back, 0, 0);
      textAlign(CENTER, CENTER);
      textFont(songFont, 72);
      fill(255);
      text(songP.title, gameWidth / 2, gameHeight / 4.5);
      textAlign(LEFT, CENTER);
      float titleWidth = textWidth(songP.title) / 2;
      textFont(songFont, 40);
      float calculatedScore = float(score) / (1 + sqrt(float(hitCount))) * pow(1.4 * (songComplexity), 3);
      text("Score:\t\t " + adjustedScore + "\nHit Count:\t\t " + adjustedHitCount+"\nGrade:\t\t " + calculatedScore, gameWidth / 2 - titleWidth, gameHeight / 2.33);

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

  if(DEBUG_TIMINGS.state) {
    fill(0, 64);
    noStroke();
    rectMode(CORNER);
    float rectWidth           = 400;
    float textFontSize        = 18;
    float topPadding          = 75;
    float rightPadding        = 2;
    float textPaddingSides    = 5;
    float textPaddingVertical = 2;

    float adjTextHeight = textFontSize + textPaddingVertical;
    float rectHeight = timingDisplay.size() * adjTextHeight + textPaddingVertical * 3;
    rect(gameWidth - rectWidth - rightPadding, topPadding, rectWidth, rectHeight);
    textFont(defaultFont, textFontSize);
    fill(255);
    int i = 0;
    for(Map.Entry<String, String> entry : timingDisplay.entrySet()) {
      textAlign(LEFT, TOP);
      text(entry.getKey()  , gameWidth - rightPadding + textPaddingSides - rectWidth, textPaddingVertical + topPadding + i * adjTextHeight);
      textAlign(RIGHT, TOP); 
      text(entry.getValue(), gameWidth - rightPadding - textPaddingSides            , textPaddingVertical + topPadding + i * adjTextHeight);
      i++;
    }
  }
  if(SHOW_FPS.state) { //FPS Tracker
    rectMode(CORNER);
    noStroke();
    fill(25, 128);
    rect(gameWidth - 72, 2, 70, 35, 3);
    fill(255);
    textAlign(LEFT, BOTTOM);
    textSize(15);
    textLeading(15);
    gameFrameCount++;
    gameFrameRateTotal += frameRate;
    text("FPS: " + nf(min(999, round(fps_tracker)), 3) + "\nAdv: " + nf(min(999, round(gameFrameRateTotal / gameFrameCount)), 3), gameWidth - 70, 35);
    fps_tracker = lerp(fps_tracker, frameRate, 1 / frameRate);
  }

  if(activeCursor != previousCursor) {
    if(activeCursor == -1) {
      noCursor();
    }else{
      cursor(activeCursor);
    }
  }

  if(timerUpdateTime == -1) timerUpdateTime = millis() + TIMER_UPDATE_FREQUENCY;

  popMatrix();
}

void exit() {
  println("Exiting, saving settings.");
  menuSettings.setFloat("volume", volSlider.val);
  if(monitorID != monitorOptions.selectedIndex + 1) {
    monitorID = monitorOptions.selectedIndex + 1;
    println("Monitor ID: " + monitorID);
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
    if(gameState.equals("levelSummary") || ((gameState.equals("game") || gameState.equals("pause") || gameState.equals("settings")) && keydown_SHIFT)) {
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
        if(allowDebugActions) {
          switch(keyCode) {
            case UP: {
              songComplexity += 0.1;
            } break;
            case DOWN: {
              songComplexity -= 0.1;
            } break;
            default: {
              if(key == ' ') {
                song.sound.skip(30 * 1000);
              }
            } break;
          }
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
    for(settingButton b : settings) {
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
      for(settingButton b : settings) {
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
  float e = ((com.jogamp.newt.event.MouseEvent)event.getNative()).getRotation()[1]; //JAVA MOMENT
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