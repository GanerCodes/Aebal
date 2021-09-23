import ddf.minim.*;

int SAMPLES_PER_SECOND = 1024;
float DEFAULT_SPEED = 2;
boolean SHOW_GUI = true;


int sgn(float f) { return f > 0 ? 1 : (f < 0 ? -1 : 0); }
boolean GTLT (float a, float b, float c) { return a >  b && a <  c; }
boolean LTGT (float a, float b, float c) { return a <  c && a >  b; }
boolean GTLTE(float a, float b, float c) { return a >= b && a <= c; }
boolean LTGTE(float a, float b, float c) { return a <= c && a >= b; }
boolean GTLT (int   a, int   b, int   c) { return a >  b && a <  c; }
boolean LTGT (int   a, int   b, int   c) { return a <  c && a >  b; }
boolean GTLTE(int   a, int   b, int   c) { return a >= b && a <= c; }
boolean LTGTE(int   a, int   b, int   c) { return a <= c && a >= b; }

SongMap songMap;
Minim minim; 
PGraphics viz;

void setup() {
    size(1280, 720, P2D);

    minim = new Minim(this);

    int startMillis = millis();
    songMap = new SongMap("song4.mp3", new PVector(1920, 1080));
    println(String.format("Map generation took %s", (millis() - startMillis) / 1000.0));
    
    viz = createGraphics(width, height, P2D);
    viz.beginDraw();
    viz.stroke(255);
    viz.strokeWeight(1);
    for(int i = 0; i < songMap.complexityArr.length; i++) {
        float x = map(i, 0, songMap.complexityArr.length, 0, width);
        viz.line(x, height, x, height - songMap.complexityArr[i] * height / 10.0);
    }
    viz.endDraw();

    songMap.song.play();
    songMap.song.setGain(-20);

    frameRate(1000);
}
void draw() {
    strokeCap(PROJECT);
    float time = songMap.song.position() / 1000.0;
    songMap.addRecentEnemies(time);

    int audioIndex = int(map(songMap.song.position(), 0, songMap.song.length(), 0, songMap.complexityArr.length));
    float c = songMap.complexityArr[audioIndex];

    colorMode(HSB);
    background(c * 100, 150, c * 100);
    colorMode(RGB);

    if(SHOW_GUI) {
        image(viz, 0, 0);
        stroke(255);
        strokeWeight(1);
        int r = int(SAMPLES_PER_SECOND);
        for(int i = max(0, audioIndex - r); i < audioIndex; i++) {
            float x = width / 2.0 + width / 3.0 * map(i, audioIndex - r, audioIndex, -1, 1);
            line(x, 0, x, height / 8.0 * songMap.complexityArr[i]);
        }   
        
        float redLineX = map(songMap.song.position(), 0, songMap.song.length(), 0, width);
        stroke(255, 0, 0);
        strokeWeight(2);
        line(redLineX, 0, redLineX, height);
    }

    fill(255);
    noStroke();
    for(Enemy e : songMap.enemies) {
        if(time > e.spawnTime) {
            PVector pos = e.getLoc(time);
            ellipse(pos.x, pos.y, 20, 20);
        }
    }
    textAlign(LEFT, TOP);
    text(time, 0, 0);
}
void mouseClicked() {
    songMap.song.cue((int)map(mouseX, 0, width, 0, songMap.song.length()));
}
void keyPressed() {
    SHOW_GUI = !SHOW_GUI;
}