import java.io.*;
import java.awt.*;
import java.nio.charset.StandardCharsets;
import org.apache.commons.io.IOUtils;
import java.awt.datatransfer.*;
import java.lang.System;

String subprocess(String cmd) {
    Process proc = launch(cmd);
    try {
        return IOUtils.toString(proc.getInputStream(), StandardCharsets.UTF_8);
    } catch(Throwable t) {
        return "Failed to execute.";
    }
}

class asyncSubprocess extends Thread {
    volatile String output, error, directory;
    volatile String[] cmd;
    volatile boolean finished = false;
    volatile int code = -1;
    asyncSubprocess(String[] cmd){
        this.cmd = cmd;
        this.directory = "/";
    }
    asyncSubprocess(String[] cmd, String directory){
        this.cmd = cmd;
        this.directory = directory;
    }
    void run() {
        try {
            ProcessBuilder pb = new ProcessBuilder(cmd);
            pb.directory(new File(directory));
            Process proc = pb.start();
            output = IOUtils.toString(proc.getInputStream(), StandardCharsets.UTF_8);
            error  = IOUtils.toString(proc.getErrorStream(), StandardCharsets.UTF_8);
            code   = proc.exitValue();
        } catch (Throwable t) {
            logmsg(t.toString());
        }
        finished = true;
    }

    String toString() {
        return String.format("Code: %s, Output: \"%s\", Error: \"%s\"", code, output, error);
    }
}

asyncSubprocess subprocessAsync(String[] cmd) {
    asyncSubprocess proc = new asyncSubprocess(cmd);
    proc.start();
    return proc;
}
asyncSubprocess subprocessAsync(String[] cmd, String directory) {
    asyncSubprocess proc = new asyncSubprocess(cmd, directory);
    proc.start();
    return proc;
}

asyncSubprocess tryDownloadFromClipboard() {
    try {
        asyncSubprocess p = subprocessAsync(new String[] {"youtube-dl", "-h"});
        while(!p.finished) {}
        if(p.output.length() > 100) { //Janky way to check if user has youtube-dl installed
            try {
                String URL = (String) Toolkit.getDefaultToolkit().getSystemClipboard().getData(DataFlavor.stringFlavor);
                if(URL == null || URL.length() < 5) return null;
                logmsg(String.format("Downloading URL \"%s\"", URL));
                p = subprocessAsync(new String[] {"youtube-dl", "--add-metadata", "--extract-audio", "--embed-thumbnail", "--no-playlist", "--audio-format", "mp3", "--output", "%(title)s.%(ext)s", URL}, sketchPath("songs"));
                return p;
            } catch(Throwable t) {
                return null;
            }
        }else{
            return null;
        }
    }catch(Throwable t) {
        return null;
    }
}