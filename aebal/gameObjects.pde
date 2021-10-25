class Enemy {
    PVector loc, vel;
    PVector locCalc;
    float spawnTime, despawnTime, velOffset;
    String spawnInfo;
    GameMap gameMap;
    boolean isGift = false;
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
    PVector getLoc(float time) {
        float tt = time * gameMap.SPS;
        float calculatedDist = lerp(gameMap.getIntegralVal(floor(tt)), gameMap.getIntegralVal(ceil(tt)), tt - int(tt)) - velOffset;
        return PVector.add(loc, PVector.mult(vel, calculatedDist));
    }
    void resetEnemyTrail() {
        locCalc = null;
    }
    void touchAction(float time) {
        gotHit(getOnScreenObjCount(), 30, 1, time);
    }
    void update(PGraphics base, float time, PVector pos, PVector previousPos, color enemyColor, boolean fancy) {
        PVector currentLoc = getLoc(time);
        if(locCalc == null) {
            locCalc = currentLoc;
        }else if(fancy) {
            base.vertex(locCalc.x, locCalc.y);
            base.vertex(currentLoc.x, currentLoc.y);
        }
        
        if(clearEnemies == -1 && (
            currentLoc.x > pos.x - 17.5 && currentLoc.x < pos.x + 17.5 && currentLoc.y > pos.y - 17.5 && currentLoc.y < pos.y + 17.5 ||
            squareIntersection(currentLoc, 35, previousPos, pos   ) ||
            squareIntersection(pos       , 35, locCalc, currentLoc) ||
            quadLineSquareIntersection(previousPos, pos, locCalc, currentLoc, 17.5)
        )) {
            touchAction(time);
        }
        locCalc = currentLoc;
    }
    boolean inField(GameMap gameMap, float time) {
        PVector currentLoc = getLoc(time);
        return currentLoc.x >= gameMap.gameDisplaySize.x / 2 - gameMap.field.size / 2 && 
        currentLoc.x <= gameMap.gameDisplaySize.x / 2 + gameMap.field.size / 2 &&
        currentLoc.y >= gameMap.gameDisplaySize.y / 2 - gameMap.field.size / 2 &&
        currentLoc.y <= gameMap.gameDisplaySize.y / 2 + gameMap.field.size / 2;
    }
    String toString() {
        return String.format("Pos: (%f, %f), Vel: (%f, %f), ExistTime: [%fs - %fs]", loc.x, loc.y, vel.x, vel.y, spawnTime, despawnTime);
    }
}
class GiftEnemy extends Enemy {
    GiftEnemy(GameMap gameMap, PVector loc, PVector vel, float spawnTime, float despawnTime) {
        super(gameMap, loc, vel, spawnTime, despawnTime);
    }
    GiftEnemy(PVector loc, PVector vel) {
        super(loc, vel);
    }
    void touchAction(float time) {
        score += int(getOnScreenObjCount() / 4);
    }
}

class Field {
    int minCenterSize = 500;
    float size;
    boolean isOutside;
    PVector gameDisplaySize;
    Field(PVector gameDisplaySize) {
        this.gameDisplaySize = gameDisplaySize;
        size = max(gameDisplaySize.x, gameDisplaySize.y);
        isOutside = false;
    }
    void constrainPosition(PVector pos) {
        float mn = size / 2 - 10 - 5;
        pos.set(
            constrain(pos.x, max(gameDisplaySize.x / 2 - mn, 15), min(gameDisplaySize.x / 2 + mn, gameDisplaySize.x - 15)),
            constrain(pos.y, max(gameDisplaySize.y / 2 - mn, 15), min(gameDisplaySize.y / 2 + mn, gameDisplaySize.y - 15))
        );
    }
    void update(PVector playerPos, float c, int mouseX, int mouseY) {
        constrainPosition(playerPos);
        isOutside = mouseX != playerPos.x || mouseY != playerPos.y;
        size = constrain(size - constrain(pow(15 * (c - 0.25), 3), -100, 25) * (60 / frameRate), minCenterSize, max(gameDisplaySize.x, gameDisplaySize.y));
    }
    boolean intense() {
        return size < minCenterSize + 5;
    }
    void draw(PGraphics base, PVector pos, int mouseX, int mouseY) {
        base.strokeCap(PROJECT);
        base.rectMode(CENTER);
        base.colorMode(RGB);
        base.noFill();
        base.strokeWeight(10);
        base.stroke(255);
        base.rect(gameDisplaySize.x / 2, gameDisplaySize.y / 2, min(size, gameDisplaySize.x - 5), min(size, gameDisplaySize.y - 5));
    }
    void drawPlayer(PGraphics base, PVector pos, int mouseX, int mouseY) {
        base.noStroke();
        base.fill(255);
        base.square(pos.x, pos.y, 20);
        if(isOutside) {
            base.fill(255, 0, 0);
            base.square(mouseX, mouseY, 10);
        }
    }
}