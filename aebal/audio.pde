import ddf.minim.Minim;
import ddf.minim.Playable;
import ddf.minim.AudioBuffer;
import ddf.minim.ugens.*;
import ddf.minim.UGen;
import ddf.minim.AudioPlayer;
import ddf.minim.spi.AudioRecordingStream;
import ddf.minim.AudioMetaData;
import ddf.minim.AudioOutput;
import ddf.minim.AudioSample;
import ddf.minim.ugens.TickRate;
import ddf.minim.ugens.FilePlayer;
import ddf.minim.ugens.Gain;

abstract class Sound {
    String soundName;
    float defaultVolume, volume;
    Sound(String soundName, float defaultVolume) {
        this.soundName = soundName;
        this.defaultVolume = defaultVolume;
        loadSound(soundName);
    }
    Sound(float defaultVolume) {
        this.defaultVolume = defaultVolume;
    }
    
    abstract boolean isPlaying();
    abstract boolean isLoaded();
    abstract void loadSound(String songName);
    abstract void setVol(float volume);
    abstract void skip(int i);
    abstract void cue(int i);
    abstract void play();
    abstract void stop();
    abstract void pause();
    abstract int position();
    abstract int length();
    String toString() {
        return soundName;
    }
}

class SFX extends Sound {
    AudioSample sound;
    int endPlayTime = -1;
    SFX(String soundName, float defaultVolume) {
        super(soundName, defaultVolume);
    }
    SFX(float defaultVolume) {
        super(defaultVolume);
    }
    boolean isLoaded() {
        return sound != null;
    }
    void loadSound(String soundName) {
        this.sound = minim.loadSample(soundName, 512);
        setVol(volume);
    }
    void setVol(float volume) {
        this.volume = volume;
        if(isLoaded()) sound.setGain(defaultVolume + volume);
    }
    void play() {
        endPlayTime = millis() + length();
        sound.trigger();
    }
    void stop() {
        sound.stop();
        endPlayTime = -1;
    }
    int length() {
        return sound.length();
    }
    boolean isPlaying() {
        return millis() < endPlayTime;
    }
    int position() { return -1; }
    void pause() {}
    void cue(int i) {}
    void skip(int i) {}
}

class Music extends Sound {
    int previousSongPosition = -1, previousTime = -1;
    AudioPlayer sound;
    Music(String soundName, float defaultVolume) {
        super(soundName, defaultVolume);
    }
    Music(float defaultVolume) {
        super(defaultVolume);
    }
    boolean isLoaded() {
        return sound != null;
    }
    void loadSound(String soundName) {
        this.sound = minim.loadFile(soundName, 1024);
        setVol(volume);
    }
    void setVol(float volume) {
        this.volume = volume;
        if(isLoaded()) sound.setGain(defaultVolume + volume);
    }
    void play() {
        sound.play();
        sound.rewind();
    }
    void stop() {
        sound.pause();
        sound.rewind();
    }
    int length() {
        return sound.length();
    }
    int position() {
        return sound.position();
    }
    int getPositionAdjusted() {
        int pos = sound.position();
        if(pos != previousSongPosition) {
            previousSongPosition = pos;
            previousTime = int(millis());
            return pos;
        }else{
            return previousSongPosition + int(millis()) - previousTime;
        }
    }
    float getAdjustedTime() {
        return float(getPositionAdjusted()) / 1000.0;
    }
    void pause() {
        sound.pause();
    }
    void unpause() {
        sound.play();
        previousSongPosition = position();
        previousTime = int(millis());
    }
    void cue(int i) {
        sound.cue(i);
    }
    void skip(int i) {
        sound.skip(i);
    }
    boolean isPlaying() {
        return sound.isPlaying();
    }
    AudioBuffer getMix() {
        return sound.mix;
    }
    float getTime() {
        return float(position()) / 1000;
    }
    float getTimeFraction() {
        return float(position()) / length();
    }
}