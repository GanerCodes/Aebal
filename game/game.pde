import ch.bildspur.postfx.builder.*;
import ch.bildspur.postfx.pass.*;
import ch.bildspur.postfx.*;
import java.io.File;
import ddf.minim.*;
import ddf.minim.analysis.*;
import controlP5.*;

float FPS = 1000;
float songComplexity = 0.2; //How "Complex" the current song is, aka make this higher if your song is really loud/bassy
float targetComplexity = 0.26; //Magic number leave it be
float GAIN = -15;
float BACKGROUND_COLOR_FADE = 0.33;
boolean BACKGROUND_BLOBS         = true;
boolean RGB_ENEMIES              = true;
boolean DO_POST_PROCESSING       = true;
boolean BACKGROUND_FADE          = true;
boolean DYNAMIC_BACKGROUND_COLOR = true;
boolean DO_OBJ_RESET             = true;
boolean DO_SHAKE                 = true;

String gameState = "gameSelect";

float findComplexity(float[] k) {
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

float[] rectAngleMap(float a, float w, float h) {
  float cosA = cos(a);
  float sinA = sin(a);
  float div = 2 * max(abs(cosA), abs(sinA));
  return new float[] {
    (w * cosA) / div, 
    (h * sinA) / div
  };
}

PVector generateLoc(float d) {
  float largestAxisSize = max(width, height);
  float a = random(-PI, PI);
  float r = random(largestAxisSize + 12, largestAxisSize + d);
  float cosA = cos(a);
  float sinA = sin(a);
  return vec2(r / cosA * min(abs(cosA), abs(sinA)), r / sinA * min(abs(cosA), abs(sinA)));
}

void gotHit() {
  grayScaleTimer = 0;
}

void songSelected(File file) {
  songList.insert(songList.size() - 1, file.getAbsolutePath());
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
    rect(width / 2, height / 2, constrain(size, 5, width - 5), constrain(size, 5, height - 5));
  }
  void update() {
    float mn = size / 2 - 10 - 5;
    pos.x = constrain(mouseX, max(width  / 2 - mn, 15), min(width  / 2 + mn, width  - 15));
    pos.y = constrain(mouseY, max(height / 2 - mn, 15), min(height / 2 + mn, height - 15));
    isOutside = mouseX != pos.x || mouseY != pos.y;
  }
}

class bubble {
  PVector loc, vel;
  PGraphics effect;
  float timer_offset;
  int size = 1000;
  bubble(PVector loc) {
    effect = createGraphics(size, size, P2D);
    this.loc = loc;
    vel = mulVec(
      PVector.random2D().mult(random(1.5, 2.5)),
      vec2(rSign(), rSign())
    );
    timer_offset = random(0, 1000000);
  }
  void update() {
    loc.add(PVector.mult(vel, max(0.01, pow(2 * max(0.01, c - 0.08), 3))));

    PVector adv = vec2();
    for(bubble b : bubbles) {
      adv.add(b.loc);
    }
    vel.sub(adv.div(bubbles.size()).sub(loc).normalize().div(125));

    float adjSize = size / 2;
    if(loc.x > width  + adjSize) { loc.x = -adjSize; }
    if(loc.y > height + adjSize) { loc.y = -adjSize; }
    if(loc.x < -adjSize) { loc.x = width  + adjSize; }
    if(loc.y < -adjSize) { loc.y = height + adjSize; }
  }
  void draw(PGraphics base) {
    effect.beginDraw();
    effect.clear();
    bubbleShader.set("clr", 1.2 * (pow(c, 0.33)));
    bubbleShader.set("mul", c / 5.0);
    bubbleShader.set("opacity", 0.001 + pow(c, 0.75) / 30.0);
    bubbleShader.set("u_time", millis() / 1000.0 + timer_offset);
    effect.endDraw();
    effect.filter(bubbleShader);
    base.image(effect, loc.x, loc.y);
  }
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
    if(oT > 120 && dist(x + cos(a) * (d1 - 15), y + sin(a) * (d1 - 15), pos.x, pos.y) <= 30) {
      if(noScoreTimer <= 0) {
        score -= getOnScreenObjCount() * 2;
        noScoreTimer = 60;
        hitSound.play();
        hitSound.rewind();
        if(DO_OBJ_RESET) {
          for (obj o : objs) {
            o.timer = 0;
          }
          gotHit();
        }
      }
    }
  }
  void drawLine() {
    strokeWeight(2);
    stroke(255, oT);
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
  PVector loc, vel;
  int timer;
  obj(float x, float y, float vx, float vy) {
    this.loc = vec2(x, y);
    this.vel = vec2(vx, vy);
    timer = 1;
  }
  obj(PVector loc, PVector vel) {
    this.loc = loc;
    this.vel = vel;
    timer = 1;
  }
  
  boolean onScreen() {
    return (loc.x > -10 && loc.x < width + 10 && loc.y > -10 && loc.y < height + 10);
  }
  void move() {
    float speed = int(c * 14.5) / 6.25 + 0.1;

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
      score -= getOnScreenObjCount();
      noScoreTimer = 30;
      hitSound.play();
      hitSound.rewind();
      if(DO_OBJ_RESET) {
        for (obj o : objs) {
          o.timer = 0;
        }
        gotHit();
      }
    }
  }
  void draw(PGraphics base) {
    base.ellipse(loc.x, loc.y, 20, 20);
  }
}

//General vars
boolean intense = false;
int score = 0;
float c, adv, count, objSpawnTimer, ang, noScoreTimer = 0, titleScroll = 0, grayScaleTimer = 100;
PVector pos, randTrans, chroma_r, chroma_g, chroma_b;
StringList songList;
AudioPlayer song, hitSound;
Minim minim;
FFT fft;
color backColor;
PGraphics back, back2;
PShader bubbleShader, chroma, reduceOpacity, grayScale;
PostFX postProcessing;
ArrayList<obj> objs = new ArrayList();
ArrayList<bubble> bubbles = new ArrayList();
ControlP5 songSelect_GUI;
field f;
arrow a;

//Vars to save or avoid recalculations
color globalObjColor;

//Math related constants
float FIFTH_PI = 0.62831853071;

void settings() {
  fullScreen(P2D, 3);
  smooth(4);
  PJOGL.setIcon("aebal.png");
}

void setup() {
  frameRate(FPS);
  surface.setTitle("Aebal");
  pos = new PVector(width / 2, height / 2);

  minim = new Minim(this);
  hitSound = minim.loadFile("hit.wav");
  hitSound.setGain(-3);

  songList = new StringList(new File(dataPath("songs")).list());
  songList.append("Add Song");

  back  = createGraphics(width, height, P2D);
  back2 = createGraphics(width, height, P2D);

  strokeCap(PROJECT);
  textFont(createFont("font.ttf", 64));
  
  songSelect_GUI = new ControlP5(this);
  songSelect_GUI.addKnob("GAIN")
                .setRange(-25, 5)
                .setValue(-15)
                .setPosition(25, height - 125)
                .setRadius(50)
                .setDragDirection(Knob.VERTICAL);
  String[] s = new String[] {"BACKGROUND_BLOBS", "RGB_ENEMIES", "DO_POST_PROCESSING", "BACKGROUND_FADE", "DYNAMIC_BACKGROUND_COLOR", "DO_OBJ_RESET", "DO_SHAKE"};
  for(int i = 0; i < s.length; i++) {
    songSelect_GUI.addToggle(s[i])
                  .setPosition(35, height - 45 * i - 180)
                  .setSize(85, 25)
                  .setColorBackground(color(255, 0, 0))
                  .setColorForeground(color(255, 0, 0))
                  .setColorActive(color(0, 255, 0));
                  // .setValue(true)
                  // .setMode(ControlP5.SWITCH);
  }
  songSelect_GUI.hide();

  f = new field(max(width, height));
  a = new arrow(width / 2, height / 2, 0, 500, 1700);
  reduceOpacity = loadShader("reduceOpacity.glsl");
  bubbleShader = loadShader("bubble.glsl");
  grayScale = loadShader("gray.glsl");
  chroma = loadShader("rgb_offset.glsl");
  chroma_r = vec2();
  chroma_g = vec2();
  chroma_b = vec2();
  postProcessing = new PostFX(this);
  postProcessing.preload(BloomPass.class);
  postProcessing.preload(SaturationVibrancePass.class);
  for(int i = 0; i < 4; i++) {
    bubbles.add(new bubble(vec2(random(0, width), random(0, height))));
  }
}

void draw() {
  if(!focused) {
    return;
  }

  switch(gameState) {
    case "gameSelect": {
      songSelect_GUI.show();
      cursor();
      rectMode(CORNER);
      textSize(14);
      background(0);
      int expandSize = 150;
      float sc = width / 9.0;
      float dd = ((width - sc) - (9 * sc + 100)) / 2;
      for(int i = 0; i < songList.size(); i++) {
        int x = int((i % 10) * sc + dd);
        int y = int((i / 10) * sc + dd);
        boolean inside = mouseX > x && mouseX < x + expandSize && mouseY > y + titleScroll && mouseY < y + titleScroll + expandSize;
        pushMatrix();
          translate(0, titleScroll);
          fill(inside ? 200 : 100);
          stroke(255);
          strokeWeight(4);
          rect(x, y, expandSize, expandSize, 15);
          fill(0);
          textAlign(CENTER);
          text(songList.get(i), x + 5, y + 5, expandSize - 7, expandSize - 7);
          if(mousePressed && inside) {
            if(songList.get(i).equals("Add Song")) {
              selectInput("Select a music file:", "songSelected");
            }else{
              gameState = "game";
              String songPath;
              if(songList.get(i).indexOf('\\') > -1 || songList.get(i).indexOf('/') > -1) {
                songPath = songList.get(i);
              }else{
                songPath = "songs/" + songList.get(i);
              }
              String[] tmp = splitTokens(songList.get(i), "/\\");
              randomSeed(trim(tmp[tmp.length - 1]).hashCode());
              song = minim.loadFile(songPath);
            }
          }
        popMatrix();
      }
      if(gameState.equals("game")) {
        songSelect_GUI.hide();
        song.setGain(GAIN);
        song.play();
        fft = new FFT(song.bufferSize(), song.sampleRate());
        
        textAlign(LEFT);
        noCursor();
        rectMode(CENTER);
      }
    } break;

    case "game": {
      fft.forward(song.mix);
      c = findComplexity(song.mix.toArray()) * (targetComplexity / songComplexity) * (0.65 + song.mix.level());
      noScoreTimer -= (60 / frameRate);
      objSpawnTimer -= c * 2 * (60 / frameRate);
    
      PVector pre_pos = pos.copy();
      pos.set(lerp(pos.x, mouseX, 0.5), lerp(pos.y, mouseY, 0.5));
    
      f.size = constrain(f.size - constrain(pow(15 * (c - 0.25), 3), -100, 25) * (60 / frameRate), 500, max(width, height));
      f.update();
    
      intense = f.size <= 505;
      { //Physics
        if (objSpawnTimer <= 0) { //Object spawning
          float speed = random(5, 12) * (1 + 3.5 * c);
          
          float v = min(height, f.size * 1.5) / 2;
          PVector loc = random(0, 1) <= 0.15 ? pos.copy() : vec2(width / 2 + random(-v, v), height / 2 + random(-v, v));
          float dis = 1.5 * sqrt(sq(width) + sq(height));
          float n = int(random(3, 3 + c * 4));
        
          float rng = random(c / 10, max(1, c * 2));
          int SPAWN_PATTERN = 0;
          if(random(0, 1) < min(0.15, (c - 0.25))) {
            objSpawnTimer = max(objSpawnTimer, 0) + c * 15;
            if(rng < 0.3) {
              SPAWN_PATTERN = 1;
            }else if(rng < 0.5) {
              SPAWN_PATTERN = 2;
            }else if(rng < 0.7) {
              SPAWN_PATTERN = 3;
            }else if(rng < 0.85) {
              SPAWN_PATTERN = 4;
            }else{
              SPAWN_PATTERN = 5;
            }
          }

          switch(SPAWN_PATTERN) {
            case 0: { //Single

              loc = generateLoc(300);
              float TLX = lerp(random(width  / 2 - f.size / 2, width  / 2 + f.size / 2), pos.x, random(0, 1));
              float TLY = lerp(random(height / 2 - f.size / 2, height / 2 + f.size / 2), pos.y, random(0, 1));
              float a = atan2(TLY - loc.y, TLX - loc.x);
              objs.add(new obj(loc.x, loc.y, speed * cos(a), speed * sin(a)));
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
                float nX = loc.x + cos(adjA) * adjDist + sin(adjA) * rad + (isCircle > 0 ? cos(a + HALF_PI) * isCircle : 0);
                float nY = loc.y + sin(adjA) * adjDist + cos(adjA) * rad + (isCircle > 0 ? sin(a + HALF_PI) * isCircle : 0);
                objs.add(
                  new obj(
                    nX, nY, -speed * cos(adjA), -speed * sin(adjA)
                  )
                );
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
            case 3: { //Square

              float sz = 50 + c * 80;
              float screenAngle = random(0, TWO_PI);
              float objRot = random(0, TWO_PI) + HALF_PI;
              float density = random(0.15, 0.5);
              speed /= 2;
              for(float x = -1; x < 1; x += density) {
                for(float y = -1; y < 1; y += density) {
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
            case 5: {

              n = int(random(3, 6));
              int d = 2 + int(c * 8);
              float sz = random(200, 444 - c * 155);
              float objRot = random(0, TWO_PI);
              for(float i = 0; i < TWO_PI; i += TWO_PI / (n * d)) {
                PVector objLoc = PVector.fromAngle(TWO_PI / n * floor(n * i / TWO_PI)).lerp(PVector.fromAngle(TWO_PI / n * ceil(n * i / TWO_PI)), (i * n / TWO_PI) % 1.0).rotate(objRot).mult(c * sz).add(loc);
                PVector objVel = PVector.sub(loc, objLoc).setMag(1).rotate(HALF_PI);
                objs.add(new obj(
                  PVector.add(objLoc, PVector.mult(objVel, -dis)),
                  objVel.setMag(speed / 1.8)
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

        randTrans = DO_SHAKE ? vec2(random(10 * -c, 10 * c), random(10 * -c, 10 * c)) : vec2();
        ang += (0.001 + constrain(c / 75, 0, 0.05)) * (200 / frameRate);
        a.speed = constrain(a.speed * (1 + constrain((c - targetComplexity) / 100, -0.05, 0.05)), 0.5, 1.75);
        float dfc = sqrt(sq(width) + sq(height));
        a.x = cos(ang) * dfc + width / 2;
        a.y = sin(ang) * dfc + height / 2;
        a.a = atan2(a.y - height / 2, a.x - width / 2);
        if(a.oT > 0) {
          a.update();
        }
        if(f.size <= 700) {
          a.spawn();
        }else{
          a.despawn();
        }

        if(BACKGROUND_BLOBS) {
          for(bubble b : bubbles) {
            b.update();
          }
        }
      }
      
      if(DYNAMIC_BACKGROUND_COLOR) {
        colorMode(HSB);
        color updatedColor;
        updatedColor = intense ? color((100 + (c * 500)) % 255, 255, (c - 0.25) * 200) : color((c * 200) % 255);
        backColor = lerpColor(backColor, updatedColor, BACKGROUND_COLOR_FADE);
        background(hue(backColor), saturation(backColor), brightness(backColor) / 2.0);
        colorMode(RGB);
      }else{
        background(0);
      }
      if(BACKGROUND_FADE && frameCount % max(1, int(frameRate / 200)) == 0) {
        back.filter(reduceOpacity);
      }
      back.beginDraw();
      back.imageMode(CENTER);
      back.noStroke();

      if(!BACKGROUND_FADE) {
        back.background(backColor);
      }
      if(BACKGROUND_BLOBS) {
        for(bubble b : bubbles) {
          b.draw(back);
        }
      }

      back.fill(255);
      back.stroke(255);
      back.strokeWeight(5);
      back.line(pre_pos.x, pre_pos.y, pos.x, pos.y);
      
      colorMode(HSB);
      globalObjColor = lerpColor(globalObjColor, (intense && RGB_ENEMIES) ? color((millis() / 5.0) % 255, 164, 255) : color(0, 255, 255), 4.0 / frameRate);

      back.noStroke();
      back.fill(globalObjColor);
      for(obj o : objs) {
        o.draw(back);
      }
      a.drawHead(back, 128);
      back.endDraw();
      image(back, 0, 0);
      a.drawLine();
      back2.beginDraw();
        back2.clear();
        stroke(255);
        a.drawHead(back2, 0);
      back2.endDraw();
      image(back2, 0, 0);
      noStroke();
      fill(255);
      rect(pos.x, pos.y, 20, 20);
      if(f.isOutside) {
        colorMode(RGB);
        fill(255, 0, 0);
        rect(mouseX, mouseY, 10, 10);
      }
      pushMatrix(); {
        if (intense) { //Add physics tick conditional here?
          translate(randTrans.x, randTrans.y);
        }
        strokeWeight(10);
        stroke(255);
        f.draw();
      } popMatrix();

      //post processing
      if(DO_POST_PROCESSING) {
        PostFXBuilder builder = postProcessing.render().bloom(0.5, 20, 40);
        if(intense) {
          builder.saturationVibrance(0.4 + c / 3.0, 0.4 + c / 3.0);
        }
        builder.compose();

        float prec = 0.75;
        PVector nextChroma_r;
        PVector nextChroma_g;
        PVector nextChroma_b;
        PVector zeroVector = new PVector(0.0, 0.0);
        if(intense) {
          if(c >= 1) {
            float offset = (2 * ((2 * c + 0.5) % 1) - 1) / 5;
            float offset_y = random(-c / 6, c / 6);
            if(random(0, 1) < 0.5) {
              nextChroma_r = vec2( offset, random(-offset_y, offset_y));
              nextChroma_g = vec2(-offset, random(-offset_y, offset_y));
              nextChroma_b = vec2(random(-offset, offset), random(-offset_y, offset_y));
            }else{
              nextChroma_r = vec2(random(-offset_y, offset_y), offset);
              nextChroma_g = vec2(random(-offset_y, offset_y), -offset);
              nextChroma_b = vec2(random(-offset_y, offset_y), random(-offset, offset));
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
      }

      colorMode(HSB);
      fill(200, 255, 255);
      score = max(0, score);
      textSize(50);
      textAlign(LEFT, TOP);
      text("Score: " + score + "\nComplexity: " + songComplexity + "\nIntensity: " + round(c * 100) + "\nFPS: " + round(frameRate), 10, 10);

      if(DO_POST_PROCESSING) {
        grayScaleTimer += 4 / frameRate;
        float adjustedGrayScale = -0.8 * sq(grayScaleTimer) + 2.4 * grayScaleTimer;
        if(adjustedGrayScale > 0.0) {
          grayScale.set("power", min(adjustedGrayScale, 0.75));
          filter(grayScale);
        }
      }
    } break;
  }
}

void keyPressed() {
  if(key == ESC) {
    key = 0;
    if(gameState == "game") {
      gameState = "gameSelect";
      song.close();
      score = 0;
    }else if(gameState == "gameSelect") {
      exit();
    }
  }else if(gameState == "game") {
    switch(keyCode) {
      case UP: {
        songComplexity *= 0.9;
      } break;
      case DOWN: {
        songComplexity *= 1.1;
      } break;
      default: {
        if(key == ' ') {
          song.skip(30 * 1000);
        }
      } break;
    }
  }
}
void mouseWheel(MouseEvent event) {
  float e = event.getCount();
  if(gameState == "game") {
    GAIN -= e;
    song.setGain(GAIN);
    hitSound.setGain(GAIN + 12);
  }else if(gameState == "gameSelect"){
    titleScroll -= 25 * e;
    objs = new ArrayList();
  }
}