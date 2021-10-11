class debugMessage {
    String msg;
    float decayTime, fadeOutDuration;
    int count = 1;
    debugMessage(String msg, float decayTime, float fadeOutDuration) {
        this.msg = msg;
        this.decayTime = decayTime;
        this.fadeOutDuration = fadeOutDuration;
    }
}

class debugList {
    ArrayList<debugMessage> messages;
    float x, y, decayTime, fadeOutDuration;
    debugList(float x, float y, float decayTime, float fadeOutDuration) {
        this.x = x;
        this.y = y;
        this.decayTime = decayTime;
        this.fadeOutDuration = fadeOutDuration;
        messages = new ArrayList();
    }
    void addMessage(String msg) {
        messages.add(new debugMessage(msg, adjMillis() + decayTime, fadeOutDuration));
    }
    void draw(PGraphics g) {
        int textSize = 12;
        g.textSize(textSize);
        g.textAlign(RIGHT, TOP);
        for(int i = messages.size() - 1; i >= 0; i--) {
            debugMessage msg = messages.get(i);
            float opacity = clampMap(adjMillis(), msg.decayTime - msg.fadeOutDuration, msg.decayTime, 255, 0);
            String msgText = (msg.count > 1 ? "[x"+msg.count+"] " : "") + msg.msg;
            float msgWidth = textWidth(msgText) + 3;
            float yOffset = y + (messages.size() - i) * (textSize + 1);
            g.fill(0, opacity / 5.0);
            g.rect(x - msgWidth, yOffset, msgWidth + 2, textSize + 1);
            g.fill(255, opacity);
            g.text(msgText, x, yOffset);
            if(adjMillis() >= msg.decayTime) messages.remove(i);
        }
    }
}

void logmsg(String msg) {
    String msgPrint = "["+millis()+"] " + msg;
    println(msgPrint);
    if(DO_LOGGING) gameLogs.println(msgPrint);
    if(DEBUG_INFO == null || !DEBUG_INFO.state) return;
    String[] spl = msg.split("\n");
    for(int i = spl.length - 1; i >= 0; i--) {
        String s = spl[i];
        if(msgList.messages.size() > 0 && msgList.messages.get(msgList.messages.size() - 1).msg.equals(s)) {
            msgList.messages.get(msgList.messages.size() - 1).count++;
        }else{
            msgList.addMessage(s);
        }
    }
}
void logmsg(Object... params) {
    String s = "";
    for(int i = 0; i < params.length; i++) {
        s += params[i].toString() + (i < params.length - 1 ? " " : "");
    }
    logmsg(s);
}
void logf(String s, Object... params) {
    logmsg(format(s, params));
}


class timingDisplaySorter implements Comparator<timingDisplayElement> {
    @Override
    int compare(timingDisplayElement a, timingDisplayElement b) {
        return Float.compare(b.precent, a.precent);
    }
}

class timingDisplayElement {
    float precent;
    String display, name;
    timingDisplayElement(float precent, String display, String name) {
        this.precent = precent;
        this.display = display;
        this.name = name;
    }
}

void TT(String ID) {
    if(TIMING_INFO.state && checkTimes) {
        if(timingList.containsKey(ID)) {
            float t = (float)(System.nanoTime() - timingList.get(ID)) / 1000000000;
            float precent  = 100 * t * frameRate;
            String display = timerFormat.format(precent)+"% (" + timerFormat.format(t) + "s)";
            timingDisplay.put(ID, new timingDisplayElement(precent, display, ID));
            timingList.remove(ID);
        }else{
            timingList.put(ID, System.nanoTime());
        }
    }
}