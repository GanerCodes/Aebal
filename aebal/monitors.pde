import com.jogamp.nativewindow.util.RectangleImmutable;
import com.jogamp.newt.opengl.GLWindow;
import com.jogamp.newt.MonitorDevice;

StringList getMonitors() {
    StringList result = new StringList();
    int i = 0;
    for(MonitorDevice monitor : ((GLWindow)surface.getNative()).getScreen().getMonitorDevices()) {
        RectangleImmutable vp = monitor.getViewport();
        result.append(++i + ": " + vp.getWidth() + 'x' + vp.getHeight() + " ("+vp.getX()+", "+vp.getY()+")");
    }
    return result;
}