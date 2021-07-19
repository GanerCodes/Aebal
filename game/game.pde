import java.io.File;
import java.awt.AWTException;
import java.awt.MouseInfo;
import java.awt.Point;
import java.awt.Robot;
import ddf.minim.*;
import ddf.minim.analysis.*;

float FPS = 240;
float songComplexity = 0.2; //How "Complex" the current song is, aka make this higher if your song is really loud/bassy
float targetComplexity = 0.26; //Magic number leave it be
float GAIN = -15;
float titleScroll = 0;

String gameState = "gameSelect";

void resetToCenter() {
  mm.mouseMove(width / 2, height / 2);
  posX = width / 2;
  posY = height / 2;
}

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

int rSign() {
  return random(0, 1) > 0.5 ? 1 : -1;
}

int getOnScreenObjCount() {
  int i = 0;
  for(obj o : objs) {
    if(o.x > -15 && o.x < width + 15 && o.y > -15 && o.y < height + 15) {
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

Float[] generateLoc(float d) {
  float largestAxisSize = max(width, height);
  float a = random(-PI, PI);
  float r = random(largestAxisSize + 12, largestAxisSize + d);
  float cosA = cos(a);
  float sinA = sin(a);
  float x = r / cosA * min(abs(cosA), abs(sinA));
  float y = r / sinA * min(abs(cosA), abs(sinA));

  return new Float[] {x, y};
}

class field {
  float size;
  field(float size) {
    this.size = size;
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
    float PX = posX;
    float PY = posY;
    posX = constrain(posX, max(width  / 2 - mn, 15), min(width  / 2 + mn, width  - 15));
    posY = constrain(posY, max(height / 2 - mn, 15), min(height / 2 + mn, height - 15));
    Point p = MouseInfo.getPointerInfo().getLocation(); 
    if (PX != posX || PY != posY) {
      mm.mouseMove(int(posX), int(posY));
    }
    if (p.x > width || p.x < 0) {
      mm.mouseMove(constrain(p.x, 1, width - 1), p.y);
    }
    if (p.y > height || p.y < 0) {
      mm.mouseMove(p.x, constrain(p.y, 1, height - 1));
    }
  }
}

class bubble {
  float x, y, vx, vy;
  int size = 1000;
  PGraphics effect;
  bubble(float x, float y) {
    effect = createGraphics(size, size, P2D);
    this.x = x;
    this.y = y;
    float a = random(0, 2 * PI);
    float d = random(1.5, 2.5);
    this.vx = rSign() * d * cos(a);
    this.vy = rSign() * d * sin(a);
  }
  void update() {
    float m = max(0.01, pow(2 * max(0.01, c - 0.08), 3));
    x += vx * m;
    y += vy * m;

    float advX = 0, advY = 0;
    for(bubble b : bubbles) {
      advX += b.x;
      advY += b.y;
    }
    advX /= bubbles.size();
    advY /= bubbles.size();
    float ang = atan2(advY - y, advX - x);
    float dis = dist(x, y, advX, advY);
    vx -= cos(ang) / 125;
    vy -= sin(ang) / 125;

    float adjSize = size / 2;
    if(x > width + adjSize) {
      x = -adjSize;
    }
    if(x < -adjSize) {
      x = width + adjSize;
    }
    if(y > height + adjSize) {
      y = -adjSize;
    }
    if(y < -adjSize) {
      y = height + adjSize;
    }
  }
  void draw() {
    effect.beginDraw();
    bubbleShader.set("clr", 1.2 * (pow(c, 0.33)));
    bubbleShader.set("mul", c / 5.0);
    bubbleShader.set("opacity", 0.001 + pow(c, 0.75) / 35.0);
    bubbleShader.set("u_time", millis() / 1000.0);
    effect.endDraw();
    effect.filter(bubbleShader);
    back.imageMode(CENTER);
    back.image(effect, x, y);
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
    oT += oTV;
    oT = constrain(oT, 0, 255);
    rot += 0.05 * (60 / frameRate);
    d1 = - mn - (sz) * (cos(rot) + 1);
    if(oT > 120 && dist(x + cos(a) * (d1 - 15), y + sin(a) * (d1 - 15), posX, posY) <= 30) {
      if(noScoreTimer <= 0) {
        score -= getOnScreenObjCount() * 2;
        noScoreTimer = 60;
        hitSound.play();
        hitSound.rewind();
        for (int i = objs.size() - 1; i > -1; i--) {
          objs.get(i).timer = 0;
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
      x + cos(a) * d1 + cos(a + PI / 5) * 30, 
      y + sin(a) * d1 + sin(a + PI / 5) * 30
    );
    base.line(
      x + cos(a) * d1, 
      y + sin(a) * d1, 
      x + cos(a) * d1 + cos(a - PI / 5) * 30, 
      y + sin(a) * d1 + sin(a - PI / 5) * 30
    );
    base.strokeCap(PROJECT);
  }
}

class obj {
  float x, y, vx, vy;
  int timer;
  obj(float x, float y, float vx, float vy) {
    this.x = x;
    this.y = y;
    this.vx = vx;
    this.vy = vy;
    timer = 1;
  }
  boolean onScreen() {
    return (x > -10 && x < width + 10 && y > -10 && y < height + 10);
  }
  void move() {
    float speed = int(c * 14.5) / 6.25 + 0.1;
    x += vx * speed * (60 / frameRate);
    y += vy * speed * (60 / frameRate);
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

    if (x > posX - 20 && x < posX + 20 && y > posY - 20 && y < posY + 20) {
      score -= getOnScreenObjCount();
      hitSound.play();
      hitSound.rewind();
      for (int i = objs.size() - 1; i > -1; i--) {
        objs.get(i).timer = 0;
      }
    }
  }
  void draw() {
    back.noStroke();
    if(intense) {
      // colorMode(HSB);
      back.colorMode(HSB);
      back.fill(globalObjHue, 128, 255);
      // colorMode(RGB);
    }else{
      back.fill(255, 0, 0);
    }
    back.ellipse(x, y, 20, 20);
  }
}



//General vars
boolean intense = false;
int score = 0;
float posX, posY, c, adv, count, objSpawnTimer, ang, noScoreTimer = 0;
String[] songList;
AudioPlayer song, hitSound;
Minim minim;
FFT fft;
PGraphics back, back2;
PShader bubbleShader;
ArrayList<obj> objs = new ArrayList();
ArrayList<bubble> bubbles = new ArrayList();
Robot mm;
field f;
arrow a;

//Vars to avoid recalculations
float globalObjHue;


void setup() {
  minim = new Minim(this);
  hitSound = minim.loadFile("hit.wav");
  hitSound.setGain(-3);
  
  delay(100);
  songList = new File(dataPath("songs")).list();

  fullScreen(P2D);
  smooth(4);
  frameRate(FPS);
  back  = createGraphics(width, height, P2D);
  back2 = createGraphics(width, height, P2D);
  strokeCap(PROJECT);
  textFont(createFont("font.ttf", 64));
  
  f = new field(max(width, height));

  try {
    mm = new Robot();
  } catch (AWTException e) {
    // Java moment
  }
  resetToCenter();
  randomSeed(0);
  
  a = new arrow(width / 2, height / 2, 0, 500, 1700);

  bubbleShader = loadShader("bubble.glsl");
  for(int i = 0; i < 4; i++) {
    bubbles.add(new bubble(random(0, width), random(0, height)));
  }
}

void draw() {
  switch(gameState) {
    case "gameSelect":
      cursor();
      rectMode(CORNER);
      textSize(14);
      background(0);
      float sc = width / 10.0;
      float dd = (width - (9 * sc + 100)) / 2;
      for(int i = 0; i < songList.length; i++) {
        int x = int((i % 10) * sc + dd);
        int y = int((i / 10) * sc + dd);
        boolean inside = mouseX > x && mouseX < x + 100 && mouseY > y + titleScroll && mouseY < y + titleScroll + 100;
        pushMatrix();
        translate(0, titleScroll);
        fill(inside ? 200 : 100);
        stroke(255);
        strokeWeight(4);
        rect(x, y, 100, 100, 15);
        fill(0);
        textAlign(CENTER);
        text(songList[i], x + 7.5, y + 7.5, 85, 85);
        if(mousePressed && inside) {
          gameState = "game";
          
          song =  minim.loadFile("songs/" + songList[i]);
          song.setGain(GAIN);
          song.play();
          fft = new FFT(song.bufferSize(), song.sampleRate());
          
          textAlign(LEFT);
          noCursor();
          rectMode(CENTER);
        }
        popMatrix();
      }
      break;
    case "game":
      fft.forward(song.mix);
      float preCalcC = findComplexity(song.mix.toArray());
      c = preCalcC * (targetComplexity / songComplexity) * (0.65 + song.mix.level());
      noScoreTimer -= (60 / frameRate);
      objSpawnTimer -= c * 2 * (60 / frameRate);
    
      float pX = posX, pY = posY;
      posX = lerp(posX, mouseX, 0.5);
      posY = lerp(posY, mouseY, 0.5);
    
      f.size -= constrain(pow(15 * (c - 0.25), 3), -100, 25) * (60 / frameRate);
      f.size = constrain(f.size, 500, max(width, height));
      f.update();
    
      color backColor;
      intense = false;
      if (f.size <= 505) {
        intense = true;
        colorMode(HSB);
        backColor = color((100 + (c * 500)) % 255, 255, (c - 0.25) * 200);
      } else {
        backColor = color(c * 200);
      }
    
      if(frameCount % 1 == 0) {
        if (objSpawnTimer <= 0) {
          float speed = random(5, 12) * (1 + 3.5 * c);
          
          if(random(0, 1) < min(0.15, (c - 0.25))) {
            float v = min(height, f.size * 1.5) / 2;
            Float[] loc = new Float[] {
              random(0, 1) <= 0.15 ? posX : width  / 2 + random(-v, v), 
              random(0, 1) <= 0.15 ? posY : height / 2 + random(-v, v)
            };
            float dis = 1.5 * sqrt(sq(width) + sq(height));
            float n = int(random(3, 3 + c * 4));
            if(random(0, 1) < 0.5) {
              float rad = random(0, 1) <= 0.5 ? 0 : random(0, 250);
              for(float a = 0; a < 2 * PI; a += (2 * PI) / n) {
                float adjA = a + PI / 4;
                float nX = loc[0] + cos(adjA) * dis + sin(adjA) * rad;
                float nY = loc[1] + sin(adjA) * dis + cos(adjA) * rad;
                objs.add(
                  new obj(
                    nX, nY, -speed * cos(adjA), -speed * sin(adjA)
                  )
                );
              }
            }else{
              float a = random(0, 2 * PI);
              n = 3 + c * 14;
              for(int l = -int(n); l <= n; l++) {
                float nX = 2 * dis * cos(a) + l * (dis / n) * cos(a + PI / 2);
                float nY = 2 * dis * sin(a) + l * (dis / n) * sin(a + PI / 2);
                objs.add(
                  new obj(
                    nX, nY, -speed * cos(a), -speed * sin(a)
                  )
                );
              }
            }
          }else{
            Float[] loc = generateLoc(300);
            float TLX = lerp(random(width  / 2 - f.size / 2, width  / 2 + f.size / 2), posX, random(0, 1));
            float TLY = lerp(random(height / 2 - f.size / 2, height / 2 + f.size / 2), posY, random(0, 1));
            float a = atan2(TLY - loc[1], TLX - loc[0]);
            objs.add(new obj(loc[0], loc[1], speed * cos(a), speed * sin(a)));
          }
          objSpawnTimer = 17.5;
        }
      
        for (int i = objs.size() - 1; i > -1; i--) {
          obj cc = objs.get(i);
          cc.move();
          if (cc.timer <= 0) {
            objs.remove(i);
          }
        }
        
        ang += 0.001 + constrain(c / 75, 0, 0.05);
        a.speed *= 1 + constrain((c - targetComplexity) / 100, -0.05, 0.05);
        a.speed = constrain(a.speed, 0.5, 1.75);
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

        for(bubble b : bubbles) {
          b.update();
        }
      }
      
      back.beginDraw();
      back.noStroke();
      back.colorMode(intense ? HSB : RGB);
      back.fill(backColor, 50 * (60 / frameRate) + 1);
      back.rect(-5, -5, width + 10, height + 10);
      back.colorMode(RGB);
      for(bubble b : bubbles) {
        b.draw();
      }
      back.fill(255);
      back.stroke(255);
      back.strokeWeight(5);
      back.line(posX, posY, pX, pY);
      globalObjHue = int((0.1 + c + 2 * pow(1.7 * c, 5.0)) *  225.0 * millis() / 500.0) % 255;
      for(obj o : objs) {
        o.draw();
      }
      a.drawHead(back, 128);
      back.endDraw();
      image(back, 0, 0);
      a.drawLine();
      stroke(255);
      back2.beginDraw();
      back2.clear();
      a.drawHead(back2, 0);
      back2.endDraw();
      image(back2, 0, 0);
      noStroke();
      fill(255);
      rect(posX, posY, 20, 20);
      pushMatrix();
      if (intense) { //Add physics tick conditional here?
        translate(random(10 * -c, 10 * c), random(10 * -c, 10 * c));
      }
      strokeWeight(10);
      stroke(255);
      f.draw();
      popMatrix();
    
      if (frameCount == 1) {
        resetToCenter();
      }
      
      textSize(50);
      colorMode(HSB);
      fill(200, 255, 255);
      score = max(0, score);
      text("Score: " + score, 115, 55);
      break;
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
      case UP:
        songComplexity *= 0.9;
        break;
      case DOWN:
        songComplexity *= 1.1;
        break;
      default:
      if(key == ' ') {
        song.skip(30 * 1000);
      }
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