// import com.jogamp.nativewindow.util.RectangleImmutable;
// import com.jogamp.newt.opengl.GLWindow;
// import com.jogamp.newt.MonitorDevice;
import java.awt.GraphicsEnvironment;
import java.awt.GraphicsDevice;
import java.awt.DisplayMode;
import java.awt.Rectangle;

StringList getMonitors() {
    StringList result = new StringList();
    int i = 0;
    for(GraphicsDevice d : GraphicsEnvironment.getLocalGraphicsEnvironment().getScreenDevices()) {
        DisplayMode display = d.getDisplayMode();
        Rectangle bounds = d.getDefaultConfiguration().getBounds();
        result.append(++i + ": " + display.getWidth() + 'x' + display.getHeight() + " (" + (int)bounds.getX() + ", " + (int)bounds.getY() + ')');
    }
    return result;
}