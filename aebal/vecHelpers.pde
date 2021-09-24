PVector vec2(float x, float y) { return new PVector(x, y); }
PVector vec2(float x) { return new PVector(x, x); }
PVector vec2() { return new PVector(0, 0); }
PVector vec3(float x, float y, float z) { return new PVector(x, y, z); }
PVector vec3(float x, float y) { return new PVector(x, y, 0); }
PVector vec3(float x) { return new PVector(x, x, x); }
PVector vec3() { return new PVector(0, 0, 0); }

PVector mulVec(PVector vec1, PVector vec2) {
    return new PVector(vec1.x * vec2.x, vec1.y * vec2.y);
}
PVector mulVecStatic(PVector vec1, PVector vec2) {
    return vec1.set(vec1.x * vec2.x, vec1.y * vec2.y);
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