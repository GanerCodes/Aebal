class debugMessage {
    String msg;
    float decayTime, fadeOutDuration;
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
        g.textSize(14);
        g.textAlign(RIGHT, TOP);
        for(int i = messages.size() - 1; i >= 0; i--) {
            debugMessage msg = messages.get(i);
            g.fill(255, clampMap(adjMillis(), msg.decayTime - msg.fadeOutDuration, msg.decayTime, 255, 0));
            g.text(msg.msg, x, y + (messages.size() - i) * 15);
            if(adjMillis() >= msg.decayTime) messages.remove(i);
        }
    }
}

void logmsg(String s) {
    println("["+millis()+"] " + s);
    msgList.addMessage(s.replace("\n", "\\n"));
}