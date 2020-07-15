import java.awt.AWTException;
import java.awt.MouseInfo;
import java.awt.Point;
import java.awt.Robot;
import ddf.minim.*;
import ddf.minim.analysis.*;

String songName = "default.mp3"; //You can change this to any mp3 file in the data directory.
float FPS = 240;
float songComplexity = 0.2; //How "Complex" the current song is, aka make this higher if your song is really loud/bassy
float targetComplexity = 0.26; //Magic number leave it be

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
    rot += 0.05 * (60 / FPS);
    d1 = - mn - (sz) * (cos(rot) + 1);
    if(oT > 120 && dist(x + cos(a) * (d1 - 15), y + sin(a) * (d1 - 15), posX, posY) <= 30) {
      preScore /= 2;
      noScoreTimer = 30;
      for (int i = objs.size() - 1; i > -1; i--) {
        objs.get(i).timer = 0;
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
    x += vx * speed * (60 / FPS);
    y += vy * speed * (60 / FPS);
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
      score /= 2;
      for (int i = objs.size() - 1; i > -1; i--) {
        objs.get(i).timer = 0;
      }
    }
  }
  void draw() {
    back.noStroke();
    back.fill(255, 0, 0);
    back.ellipse(x, y, 20, 20);
  }
}

float posX, posY, c, adv, count, objSpawnTimer, ang;
int score = 0;
ArrayList<obj> objs = new ArrayList();
PGraphics back, back2;
field f;
Robot mm;

//AudioInput song;
AudioPlayer song;
Minim minim;
FFT fft;

arrow a;
void setup() {
  minim = new Minim(this);
  song =  minim.loadFile(songName);
  //song = minim.getLineIn();
  song.setGain(0);
  song.play();
  fft = new FFT(song.bufferSize(), song.sampleRate());

  fullScreen(P2D);
  frameRate(FPS);
  back  = createGraphics(width, height, P2D);
  back2 = createGraphics(width, height, P2D);
  rectMode(CENTER);
  strokeCap(PROJECT);
  noCursor();

  f = new field(max(width, height));

  try {
    mm = new Robot();
  } catch (AWTException e) {}
  resetToCenter();
  randomSeed(0);
  
  a = new arrow(width / 2, height / 2, 0, 500, 1700);
}

float noScoreTimer = 0;
int preScore;

void draw() {
  fft.forward(song.mix);
  float preCalcC = findComplexity(song.mix.toArray());
  c = preCalcC * (targetComplexity / songComplexity) * (0.65 + song.mix.level());
  
  preScore = score;
  noScoreTimer -= (60 / FPS);

  float pX = posX, pY = posY;
  posX = lerp(posX, mouseX, 0.5);
  posY = lerp(posY, mouseY, 0.5);

  f.size -= constrain(pow(15 * (c - 0.25), 3), -100, 25) * (60 / FPS);
  f.size = constrain(f.size, 500, max(width, height));
  f.update();

  color backColor;
  boolean H = false;

  if (f.size <= 505) {
    H = true;
    colorMode(HSB);
    backColor = color((100 + (c * 500)) % 255, 255, (c - 0.25) * 200);
  } else {
    backColor = color(c * 200);
  }

  if (objSpawnTimer <= 0) {
    Float[] loc = generateLoc(300);
    float TLX = lerp(random(width  / 2 - f.size / 2, width  / 2 + f.size / 2), posX, random(0, 1));
    float TLY = lerp(random(height / 2 - f.size / 2, height / 2 + f.size / 2), posY, random(0, 1));
    float a = atan2(TLY - loc[1], TLX - loc[0]);
    float speed = random(5, 15) * (1 + 5 * c);
    objs.add(new obj(loc[0], loc[1], speed * cos(a), speed * sin(a)));
    objSpawnTimer = 17.5;
  }

  objSpawnTimer -= c * 2 * (60 / FPS);

  back.beginDraw();
  back.noStroke();
  back.colorMode(H ? HSB : RGB);
  back.fill(backColor, 50 * (60 / FPS) + 1);
  back.rect(-5, -5, width + 10, height + 10);
  back.colorMode(RGB);
  for (int i = objs.size() - 1; i > -1; i--) {
    obj cc = objs.get(i);
    cc.move();
    cc.draw();
    if (cc.timer <= 0) {
      objs.remove(i);
    }
  }
  back.fill(255);
  back.stroke(255);
  back.strokeWeight(5);
  back.line(posX, posY, pX, pY);
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
  if (H) {
    translate(random(10 * -c, 10 * c), random(10 * -c, 10 * c));
  }
  strokeWeight(10);
  stroke(255);
  f.draw();
  popMatrix();

  if (frameCount == 1) {
    resetToCenter();
  }
  
  if(noScoreTimer > 0) {
    score = preScore;
  }
  
  textSize(50);
  colorMode(HSB);
  fill(200, 255, 255);
  text("Score: "+score, 15, 55);
}

void keyPressed() {
  if(key == ' ') {
    song.skip(30 * 1000);
  }
}
