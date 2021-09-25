import ddf.minim.Minim;
import ddf.minim.AudioPlayer;
import ddf.minim.AudioSample;

int SAMPLES_PER_SECOND = 1024;
float GAME_MARGIN_SIZE = 10;
float DEFAULT_SPEED = 2;
boolean SHOW_GUI = true;

GameMap gameMap;
Minim minim; 
PGraphics viz;

void setup() {
    size(1280, 720, P2D);

    new PatternSpawner("patterns.json");

    minim = new Minim(this);

    int startMillis = millis();
    gameMap = new GameMap("song4.mp3", new PVector(width, height));
    println(String.format("Map generation took %s", (millis() - startMillis) / 1000.0));
    
    viz = createGraphics(width, height, P2D);
    viz.beginDraw();
    viz.stroke(255);
    viz.strokeWeight(1);
    for(int i = 0; i < gameMap.complexityArr.length; i++) {
        float x = map(i, 0, gameMap.complexityArr.length, 0, width);
        viz.line(x, height, x, height - gameMap.complexityArr[i] * height / 10.0);
    }
    viz.endDraw();

    gameMap.song.play();
    gameMap.song.setGain(-20);

    strokeCap(PROJECT);
    frameRate(1000);
}
void draw() {
    float time = gameMap.song.position() / 1000.0;
    gameMap.updateEnemies(time);

    int audioIndex = int(map(gameMap.song.position(), 0, gameMap.song.length(), 0, gameMap.complexityArr.length));
    float c = gameMap.complexityArr[audioIndex];

    background(c * 100);
    if(SHOW_GUI) {
        image(viz, 0, 0);
        stroke(255);
        strokeWeight(1);
        int r = int(SAMPLES_PER_SECOND);
        for(int i = max(0, audioIndex - r); i < audioIndex; i++) {
            float x = width / 2.0 + width / 3.0 * map(i, audioIndex - r, audioIndex, -1, 1);
            line(x, 0, x, height / 8.0 * gameMap.complexityArr[i]);
        }   
        
        float redLineX = map(gameMap.song.position(), 0, gameMap.song.length(), 0, width);
        stroke(255, 0, 0);
        strokeWeight(2);
        line(redLineX, 0, redLineX, height);
    }

    fill(255);
    noStroke();
    pushMatrix();
    // translate(-gameMap.marginSize, -gameMap.marginSize);
    for(Enemy e : gameMap.enemies) {
        PVector pos = e.getLoc(time);
        circle(pos.x, pos.y, 20);
    }
    popMatrix();
    textAlign(LEFT, TOP);
    text(frameRate+"\n"+time+"\n"+gameMap.enemies.size(), 0, 0);
}
void mouseClicked() {
    gameMap.song.cue((int)map(mouseX, 0, width, 0, gameMap.song.length()));
    gameMap.resetEnemies();
}
void keyPressed() {
    SHOW_GUI = !SHOW_GUI;
}