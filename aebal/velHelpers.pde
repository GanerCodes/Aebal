PVector vec2(float x, float y) { return new PVector(x, y); }
PVector vec2(float x) { return new PVector(x, x); }
PVector vec2() { return new PVector(0, 0); }
PVector vec3(float x, float y, float z) { return new PVector(x, y, z); }
PVector vec3(float x, float y) { return new PVector(x, y, 0); }
PVector vec3(float x) { return new PVector(x, x, x); }
PVector vec3() { return new PVector(0, 0, 0); }

PVector mulVecCopy(PVector vec1, PVector vec2) {
    return new PVector(vec1.x * vec2.x, vec1.y * vec2.y);
}
PVector mulVec(PVector vec1, PVector vec2) {
    vec1.set(vec1.x * vec2.x, vec1.y * vec2.y);
    return vec1;
}

boolean lineIntersection(PVector a, PVector b, PVector c, PVector d) { //Yea, I wrote this, not to flex or anything 😎
    return (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x)>=0?(d.x-c.x)*(b.y-c.y)-(d.y-c.y)*(b.x-c.x)>=0&&(b.x-a.x)*(d.y-a.y)-(b.y-a.y)*(d.x-a.x)<=0&&(d.x-c.x)*(a.y-c.y)-(d.y-c.y)*(a.x-c.x)<=0:(d.x-c.x)*(b.y-c.y)-(d.y-c.y)*(b.x-c.x)<=0&&(b.x-a.x)*(d.y-a.y)-(b.y-a.y)*(d.x-a.x)>=0&&(d.x-c.x)*(a.y-c.y)-(d.y-c.y)*(a.x-c.x)>=0;
}
boolean inBounds(PVector loc, PVector boxLoc, PVector boxSize) {
    return loc.x >= boxLoc.x && loc.x <= boxLoc.x + boxSize.x && loc.y >= boxLoc.y && loc.y <= boxLoc.y + boxSize.y;
}
float distToRect(PVector p, PVector v, PVector rectSize, PVector rectLoc) {
    return v.mag() * min(
        abs((sgn(v.x) * (p.x - rectLoc.x) - 0.5 * rectSize.x) / v.x),
        abs((sgn(v.y) * (p.y - rectLoc.y) - 0.5 * rectSize.y) / v.y)
    );
}
boolean velRectIntersection(PVector p, PVector v, PVector rectSize, PVector rectLoc) {
    return 2 * abs((p.y - rectLoc.y) - v.y / v.x * ((p.x - rectLoc.x) - 0.5 * sgn(v.x) * rectSize.x)) <= rectSize.y || 2 * abs((p.x - rectLoc.x) - v.x / v.y * ((p.y - rectLoc.y) - 0.5 * sgn(v.y) * rectSize.y)) <= rectSize.x;
}
boolean rayRectIntersection(PVector p, PVector v, PVector rectSize, PVector rectLoc) {
    PVector t = PVector.add(p, PVector.mult(v, min(
        abs(0.5 * rectSize.x - sgn(v.x) * (p.x - rectLoc.x) / v.x),
        abs(0.5 * rectSize.y - sgn(v.y) * (p.y - rectLoc.y) / v.y)
    )));
    return max(abs(t.x - rectLoc.x) / rectSize.x, abs(t.y - rectLoc.y) / rectSize.y) <= 0.501;
}
PVector lineRectIntersectionPoint(PVector loc, PVector v, PVector rectSize, PVector rectLoc) {
    return PVector.add(loc, PVector.mult(v, min(
        abs((0.5 * rectSize.x - sgn(v.x) * (loc.x - rectLoc.x)) / v.x),
        abs((0.5 * rectSize.y - sgn(v.y) * (loc.y - rectLoc.y)) / v.y)
    )));
}
boolean squareIntersection(PVector loc, float s, PVector a, PVector b) { //This is center aligned, for some reason
    return
    lineIntersection(vec2(loc.x - s / 2, loc.y - s / 2), vec2(loc.x + s / 2, loc.y - s / 2), a, b) || 
    lineIntersection(vec2(loc.x + s / 2, loc.y - s / 2), vec2(loc.x + s / 2, loc.y + s / 2), a, b) || 
    lineIntersection(vec2(loc.x + s / 2, loc.y + s / 2), vec2(loc.x - s / 2, loc.y + s / 2), a, b) || 
    lineIntersection(vec2(loc.x - s / 2, loc.y + s / 2), vec2(loc.x - s / 2, loc.y - s / 2), a, b);
}
boolean rectIntersection(PVector loc, PVector s, PVector a, PVector b) { //Corner aligned as it should be
    return
    lineIntersection(new PVector(loc.x      , loc.y      ), new PVector(loc.x + s.x, loc.y      ), a, b) || 
    lineIntersection(new PVector(loc.x + s.x, loc.y      ), new PVector(loc.x + s.x, loc.y + s.y), a, b) || 
    lineIntersection(new PVector(loc.x + s.x, loc.y + s.y), new PVector(loc.x      , loc.y + s.y), a, b) || 
    lineIntersection(new PVector(loc.x      , loc.y + s.y), new PVector(loc.x      , loc.y      ), a, b);
}
boolean quadLineSquareIntersection(PVector a1, PVector a2, PVector b1, PVector b2, float s) { //1000% sure there is some fancy way to do this like I did with a bunch of the simpler stuff but I can't be asked rn
    if((a1.x == a2.x && a1.y == a2.y) || (b1.x == b2.x && b1.y == b2.y)) return false;
    
    s *= 0.5;
    PVector[] corners = new PVector[] {
        new PVector( s,  s),
        new PVector( s, -s),
        new PVector(-s,  s),
        new PVector(-s, -s)
    };
    for(PVector c1 : corners) {
        for(PVector c2 : corners) {
            if(lineIntersection(
                PVector.add(a1, c1), PVector.add(a2, c1),
                PVector.add(b1, c2), PVector.add(b2, c2)
            )) return true;
        }
    }
    return false;
}