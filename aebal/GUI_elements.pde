int MOUSE_OVER    = 0;
int MOUSE_PRESS   = 1;
int MOUSE_RELEASE = 2;

class button {
    float x, y, w, h, r;
    boolean active, state;
    color norm_0, norm_1, over_0, over_1, down_0, down_1;
    String txt;
    PImage overlay;
    // keyword parameters don't exist in Java for """simplicity""" reasons
    void init(float x, float y, float w, float h, float r, PImage overlay, String txt, color norm_0, color over_0, color down_0, color norm_1, color over_1, color down_1) {
        this.x = x;
        this.y = y;
        this.w = w;
        this.h = h;
        this.r = r;
        if(overlay != null) {
            this.overlay = overlay.copy();
            this.overlay.resize(int(w / 1.15), int(h / 1.15));
        }
        this.txt = txt;
        this.norm_0 = norm_0;
        this.norm_1 = norm_1;
        this.over_0 = over_0;
        this.over_1 = over_1;
        this.down_0 = down_0;
        this.down_1 = down_1;
        state = true;
        active = false;
    }
    button(float x, float y, float w, float h, float r, PImage overlay, color norm_0, color over_0, color down_0) {
        init(x, y, w, h, r, overlay, null, norm_0, over_0, down_0, -1, -1, -1);
    }
    button(float x, float y, float w, float h, float r                , color norm_0, color over_0, color down_0) {
        init(x, y, w, h, r, null   , null, norm_0, over_0, down_0, -1, -1, -1);
    }
    button(float x, float y, float w, float h, float r, PImage overlay, color norm_0, color over_0, color down_0, color norm_1, color over_1, color down_1) {
        init(x, y, w, h, r, overlay, null, norm_0, over_0, down_0, norm_1, over_1, down_1);
    }
    button(float x, float y, float w, float h, float r                , color norm_0, color over_0, color down_0, color norm_1, color over_1, color down_1) {
        init(x, y, w, h, r, null   , null, norm_0, over_0, down_0, norm_1, over_1, down_1);
    }
    button(float x, float y, float w, float h, float r, PImage overlay, String txt, color norm_0, color over_0, color down_0) {
        init(x, y, w, h, r, overlay, txt , norm_0, over_0, down_0, -1, -1, -1);
    }
    button(float x, float y, float w, float h, float r, String txt                , color norm_0, color over_0, color down_0) {
        init(x, y, w, h, r, null   , txt , norm_0, over_0, down_0, -1, -1, -1);
    }
    button(float x, float y, float w, float h, float r, PImage overlay, String txt, color norm_0, color over_0, color down_0, color norm_1, color over_1, color down_1) {
        init(x, y, w, h, r, overlay, txt , norm_0, over_0, down_0, norm_1, over_1, down_1);
    }
    button(float x, float y, float w, float h, float r, String txt                , color norm_0, color over_0, color down_0, color norm_1, color over_1, color down_1) {
        init(x, y, w, h, r, null   , txt , norm_0, over_0, down_0, norm_1, over_1, down_1);
    }
    void stateChanged() {}
    boolean checkMouse(int type) {
        boolean over = curX > x - w/2 && curX < x + w/2 && curY > y - h/2 && curY < y + h/2;
        if(over && active && type == MOUSE_RELEASE && over_1 != -1) {
            state = !state;
            stateChanged();
        }
        if(type > 0) {
            active = type == MOUSE_PRESS && over;
            if(over && type == MOUSE_RELEASE) buttonSFX.play();
        }
        return over;
    }
    void draw() {
        rectMode(CENTER);
        imageMode(CENTER);
        boolean mouseOver = checkMouse(MOUSE_OVER);
        if(mouseOver) activeCursor = HAND; 
        
        fill(state ? (active ? down_0 : (mouseOver ? over_0 : norm_0)) : (active ? down_1 : (mouseOver ? over_1 : norm_1))); //lol
        drawBackground();
        if(overlay != null) image(overlay, x, y);
        drawLabel();
    }
    void drawBackground() {
        rect(x, y, w, h, r);
    }
    void drawLabel() {
        if(txt != null) text(txt, x + (w / 2.0 + g.textSize / 2.5) * (g.textAlign == LEFT ? 1 : -1), y - 4.5); //THIS STUPID LINE TOOK HOURS TO FIGURE OUT, NOWHERE ANYWHERE DOES IT MENTION 'g' AS A VARIABLE TO ACCESS THE PAPPLET's PGRAPHICS, I SCROLLED THROUGH SO MANY DOCS TO FIND THIS
    }
}

class settingButton extends button {
    settingButton(float x, float y, float w, float h, float r, PImage overlay, color norm_0, color over_0, color down_0) {
        super(x, y, w, h, r, overlay, null, norm_0, over_0, down_0, -1, -1, -1);
    }
    settingButton(float x, float y, float w, float h, float r                , color norm_0, color over_0, color down_0) {
        super(x, y, w, h, r, null   , null, norm_0, over_0, down_0, -1, -1, -1);
    }
    settingButton(float x, float y, float w, float h, float r, PImage overlay, color norm_0, color over_0, color down_0, color norm_1, color over_1, color down_1) {
        super(x, y, w, h, r, overlay, null, norm_0, over_0, down_0, norm_1, over_1, down_1);
    }
    settingButton(float x, float y, float w, float h, float r                , color norm_0, color over_0, color down_0, color norm_1, color over_1, color down_1) {
        super(x, y, w, h, r, null   , null, norm_0, over_0, down_0, norm_1, over_1, down_1);
    }
    settingButton(float x, float y, float w, float h, float r, PImage overlay, String txt, color norm_0, color over_0, color down_0) {
        super(x, y, w, h, r, overlay, txt , norm_0, over_0, down_0, -1, -1, -1);
    }
    settingButton(float x, float y, float w, float h, float r, String txt                , color norm_0, color over_0, color down_0) {
        super(x, y, w, h, r, null   , txt , norm_0, over_0, down_0, -1, -1, -1);
    }
    settingButton(float x, float y, float w, float h, float r, PImage overlay, String txt, color norm_0, color over_0, color down_0, color norm_1, color over_1, color down_1) {
        super(x, y, w, h, r, overlay, txt , norm_0, over_0, down_0, norm_1, over_1, down_1);
    }
    settingButton(float x, float y, float w, float h, float r, String txt                , color norm_0, color over_0, color down_0, color norm_1, color over_1, color down_1) {
        super(x, y, w, h, r, null   , txt , norm_0, over_0, down_0, norm_1, over_1, down_1);
    }
    void stateChanged() {
        menuSettings.setBoolean(txt, state);
        saveJSONObject(menuSettings, settingsFileLoc);
    }
}

class slider {
    float x, y, w, h, val, val_min, val_max, ballHfactor;
    color clr_line, clr_ball, clr_line_hover, clr_ball_hover, clr_line_active, clr_ball_active;
    boolean active;
    String txt;
    void init(float x, float y, float w, float h, float val, float val_min, float val_max, String txt, color clr_line, color clr_ball, color clr_line_hover, color clr_ball_hover, color clr_line_active, color clr_ball_active) {
        this.x = x;
        this.y = y;
        this.w = w;
        this.h = h;
        this.val = val;
        this.val_min = val_min;
        this.val_max = val_max;
        this.txt = txt;
        this.clr_line = clr_line;
        this.clr_ball = clr_ball;
        this.clr_line_hover = clr_line_hover;
        this.clr_ball_hover = clr_ball_hover;
        this.clr_line_active = clr_line_active;
        this.clr_ball_active = clr_ball_active;
        this.ballHfactor = 1.3;
        active = false;
        onChange();
    }
    slider(float x, float y, float w, float h, float val, float val_min, float val_max, color clr_line, color clr_ball, color clr_line_hover, color clr_ball_hover, color clr_line_active, color clr_ball_active) {
        init(x, y, w, h, val, val_min, val_max, null, clr_line, clr_ball, clr_line_hover, clr_ball_hover, clr_line_active, clr_ball_active);
    }
    slider(float x, float y, float w, float h, float val, float val_min, float val_max, color clr, color clr_hover, color clr_active) {
        init(x, y, w, h, val, val_min, val_max, null, clr, clr, clr_hover, clr_hover, clr_hover, clr_active);
    }
    slider(float x, float y, float w, float h, float val, float val_min, float val_max, String txt, color clr_line, color clr_ball, color clr_line_hover, color clr_ball_hover, color clr_line_active, color clr_ball_active) {
        init(x, y, w, h, val, val_min, val_max, txt , clr_line, clr_ball, clr_line_hover, clr_ball_hover, clr_line_active, clr_ball_active);
    }
    slider(float x, float y, float w, float h, float val, float val_min, float val_max, String txt, color clr, color clr_hover, color clr_active) {
        init(x, y, w, h, val, val_min, val_max, txt , clr, clr, clr_hover, clr_hover, clr_hover, clr_active);
    }
    float getMappedVal() {
        return map(val, val_min, val_max, x - w / 2.05, x + w / 2.05);
    }
    float getNormVal() {
        return norm(val, val_min, val_max);
    }
    void onRelease() {}
    void onChange() {}
    void onScroll() {}
    void checkScroll(float e) {
        float pVal = val;
        val = clamp(val + e * (val_max - val_min) / 35, val_min, val_max);
        if(val != pVal) onChange();
        onScroll();
    }
    boolean checkMouse(int type) {
        float offsetX = w / 2 - h / 2;
        boolean over = (curX > x - offsetX && curX < x + offsetX && curY > y - h / 2 && curY < y + h / 2) || dist(curX, curY, getMappedVal(), y) < h / 2 * ballHfactor || dist(curX, curY, x - offsetX, y) < h / 2 || dist(curX, curY, x + offsetX, y) < h / 2;
        boolean pre_active = active;
        if(type > 0) active = type == MOUSE_PRESS && over; //this line is sex
        if(pre_active && !active) {
            onRelease();
        }
        return over;
    }
    void draw() {
        float pVal = val;
        if(active) {
            val = constrain(map(curX, x - w / 2, x + w / 2, val_min, val_max), min(val_min, val_max), max(val_min, val_max));
            if(val != pVal) onChange();
        }
        boolean mouseOver = checkMouse(MOUSE_OVER);
        if(mouseOver) activeCursor = HAND;
        rectMode(CENTER);
        fill(active ? clr_line_active : (mouseOver ? clr_line_hover : clr_line));
        rect(x, y, w, h, h / 2);
        fill(active ? clr_ball_active : (mouseOver ? clr_ball_hover : clr_ball));
        circle(getMappedVal(), y, h * ballHfactor);
        if(txt != null) {
            text(txt, x, y + g.textSize / 1.5 * (g.textAlignY == BOTTOM ? -1 : 1));
        }
    }
}

class vol_slider extends slider {
    int nextVolumeSFXplay = -1;
    vol_slider(float x, float y, float w, float h, float val, float val_min, float val_max, String txt, color clr_line, color clr_ball, color clr_line_hover, color clr_ball_hover, color clr_line_active, color clr_ball_active) {
        super(x, y, w, h, val, val_min, val_max, txt , clr_line, clr_ball, clr_line_hover, clr_ball_hover, clr_line_active, clr_ball_active);
    }
    void onRelease() {
        activate();
        volChangeSFX.setVol(val);
        volChangeSFX.play();
    }
    void onScroll()  { nextVolumeSFXplay = millis() + 100; }
    void activate()  { setSFXvol(val); }
}
class music_slider extends slider {
    int nextVolumeSFXplay = -1;
    music_slider(float x, float y, float w, float h, float val, float val_min, float val_max, String txt, color clr_line, color clr_ball, color clr_line_hover, color clr_ball_hover, color clr_line_active, color clr_ball_active) {
        super(x, y, w, h, val, val_min, val_max, txt , clr_line, clr_ball, clr_line_hover, clr_ball_hover, clr_line_active, clr_ball_active);
    }
    void onRelease() {
        activate();
        volChangeSFX.setVol(val);
        volChangeSFX.play();
    }
    void onScroll()  { nextVolumeSFXplay = millis() + 100; }
    void activate()  { setMusicvol(val); }
}

class difficulty_slider extends slider {
    difficulty_slider(float x, float y, float w, float h, float val, float val_min, float val_max, color clr_line, color clr_ball, color clr_line_hover, color clr_ball_hover, color clr_line_active, color clr_ball_active) {
        super(x, y, w, h, val, val_min, val_max, null, clr_line, clr_ball, clr_line_hover, clr_ball_hover, clr_line_active, clr_ball_active);
    }
    difficulty_slider(float x, float y, float w, float h, float val, float val_min, float val_max, color clr, color clr_hover, color clr_active) {
        super(x, y, w, h, val, val_min, val_max, null, clr, clr, clr_hover, clr_hover, clr_hover, clr_active);
    }
    difficulty_slider(float x, float y, float w, float h, float val, float val_min, float val_max, String txt, color clr_line, color clr_ball, color clr_line_hover, color clr_ball_hover, color clr_line_active, color clr_ball_active) {
        super(x, y, w, h, val, val_min, val_max, txt , clr_line, clr_ball, clr_line_hover, clr_ball_hover, clr_line_active, clr_ball_active);
    }
    difficulty_slider(float x, float y, float w, float h, float val, float val_min, float val_max, String txt, color clr, color clr_hover, color clr_active) {
        super(x, y, w, h, val, val_min, val_max, txt , clr, clr, clr_hover, clr_hover, clr_hover, clr_active);
    }
    void onChange() {
        val = float(nf(val, 0, 2).replace(",", "."));
        songComplexity = val;
        float n = getNormVal();
        color newCol = lerpColors(n, #00FF00, #2222FF, #FF0000);
        clr_line        = mulColor(newCol, vec3(0.8));
        clr_line_hover  = mulColor(newCol, vec3(0.9));
        clr_line_active = newCol;
        clr_ball        = mulColor(clr_line       , vec3(0.65));
        clr_ball_hover  = mulColor(clr_line_hover , vec3(0.65));
        clr_ball_active = mulColor(clr_line_active, vec3(0.65));
        int displayVal = int(n * 100);
        txt = "Difficulty\n";
        if(displayVal < 25) {
            txt += "Easy";
        }else if(displayVal < 50) {
            txt += "Medium";
        }else if(displayVal < 85) {
            txt += "Hard";
        }else{
            txt += "Impossible";
        }
        txt += " ("+displayVal+"%)";
    }
    void onRelease() {
        onChange();
    }
}

class buttonMenu {
    ArrayList<dropdownButton> buttons;
    float x, y, itemWidth, itemHeight;
    int selectedIndex;
    color norm_0, over_0, down_0, norm_1, over_1, down_1;
    buttonMenu(float x, float y, float itemWidth, float itemHeight, color norm_0, color over_0, color down_0, color norm_1, color over_1, color down_1) {
        buttons = new ArrayList<dropdownButton>();
        this.x = x;
        this.y = y;
        this.itemWidth = itemWidth;
        this.itemHeight = itemHeight;
        this.norm_0 = norm_0;
        this.over_0 = over_0;
        this.down_0 = down_0;
        this.norm_1 = norm_1;
        this.over_1 = over_1;
        this.down_1 = down_1;
    }
    void addButton(String label) {
        buttons.add(new dropdownButton(x, y + buttons.size() * itemHeight, itemWidth, itemHeight, 1, label, norm_0, over_0, down_0, norm_1, over_1, down_1, this));
    }
    void draw() {
        int i = 0;
        for(dropdownButton b : buttons) {
            if(i == 0) {
                b.r1 = 10;
                b.r2 = 10;
                b.r3 = 0;
                b.r4 = 0;
            }else if(i == buttons.size() - 1) {
                b.r1 = 0;
                b.r2 = 0;
                b.r3 = 10;
                b.r4 = 10;
            }else{
                b.r1 = 0;
                b.r2 = 0;
                b.r3 = 0;
                b.r4 = 0;
            }
            b.draw();
            i++;
        }
    }
    void checkMouse(int type) {
        for(dropdownButton b : buttons) {
            b.checkMouse(type);
        }
    }
    void setState() {
        buttons.get(buttons.size() - 1).state = true;
        selectedIndex = buttons.size() - 1;
    }
}

class dropdownButton extends button {
    buttonMenu menu;
    float r1, r2, r3, r4;
    dropdownButton(float x, float y, float w, float h, float r, String txt, color norm_0, color over_0, color down_0, color norm_1, color over_1, color down_1, buttonMenu menu) {
        super(x, y, w, h, r, null, txt , norm_0, over_0, down_0, norm_1, over_1, down_1);
        this.menu = menu;
        this.state = false;
    }
    void stateChanged() {
        for(dropdownButton b : menu.buttons) {
            if(b == this) {
                b.state = true;
                menu.selectedIndex = menu.buttons.indexOf(this);
            }else{
                b.state = false;
            }
        }
    }
    void drawBackground() {
        rect(x, y, w, h, r1, r2, r3, r4);
    }
    void drawLabel() {
        if(txt == null) return;
        textAlign(LEFT, CENTER);
        textSize(w / 16);
        fill(state ? 0 : 255);
        text(txt, x - w / 2 + 5, y);
    }
}