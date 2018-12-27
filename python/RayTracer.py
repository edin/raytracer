import math
import time
from PIL import Image

FarAway = 1000000

class Vector:
    def __init__(self, x,y,z):
        self.x = x
        self.y = y
        self.z = z

    def times(self, k):
        return Vector(self.x * k, self.y  * k, self.z * k)

    def minus(self, v):
        return Vector(self.x - v.x, self.y - v.y, self.z - v.z)

    def plus(self, v):
        return Vector(self.x + v.x, self.y + v.y, self.z + v.z)

    def dot(self, v):
        return self.x * v.x + self.y * v.y + self.z * v.z

    def mag(self):
        return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)

    def norm(self):
        mag = self.mag()
        div = FarAway if (mag == 0) else  1.0 / mag
        return self.times(div)

    def cross(self, v):
        return Vector(self.y * v.z - self.z * v.y, self.z * v.x - self.x * v.z, self.x * v.y - self.y * v.x)

class Color:
    def __init__(self,r: float, g: float, b: float):
        self.r = r
        self.g = g
        self.b = b

    def scale(self, k: float):
        return Color(self.r * k, self.g * k, self.b * k)

    def plus(self, v):
        return Color(self.r + v.r, self.g + v.g, self.b + v.b)

    def times(self, v):
        return Color(self.r * v.r, self.g * v.g, self.b * v.b)

    def toDrawingColor(self):
        legalize = lambda  d: 1 if(d > 1) else d
        r = math.floor(legalize(self.r)*255)
        g = math.floor(legalize(self.g)*255)
        b = math.floor(legalize(self.b)*255)
        return (r, g ,b)

ColorWhite = Color(1.0, 1.0, 1.0)
ColorGrey  = Color(0.5, 0.5, 0.5)
ColorBlack = Color(0.0, 0.0, 0.0)
ColorBackground   = ColorBlack
ColorDefaultColor = ColorBlack

class Camera:
    def __init__(self, pos: Vector, lookAt: Vector):
        down         = Vector(0.0, -1.0, 0.0)
        self.pos     = pos
        self.forward = lookAt.minus(self.pos).norm()
        self.right   = self.forward.cross(down).norm().times(1.5)
        self.up      = self.forward.cross(self.right).norm().times(1.5)

class Ray:
    def __init__(self, start: Vector, dir: Vector):
        self.start = start
        self.dir = dir

class Intersection:
    def __init__(self, thing, ray: Ray, dist: float):
        self.thing = thing
        self.ray =  ray
        self.dist = dist

class Light:
    def __init__(self, pos: Vector, color: Color):
        self.pos = pos
        self.color = color

class Sphere:
    def __init__(self, center: Vector, radius: float, surface):
        self.radius2 = radius*radius
        self._surface = surface
        self.center  = center

    def normal(self, pos: Vector):
        return pos.minus(self.center).norm()

    def surface(self):
        return self._surface

    def intersect(self, ray: Ray):
        eo = self.center.minus(ray.start)
        v = eo.dot(ray.dir)
        dist = 0
        if (v >= 0):
            disc = self.radius2 - (eo.dot(eo) - v * v)
            if (disc >= 0):
                dist = v - math.sqrt(disc)
        if (dist == 0):
            return None
        return Intersection(self, ray, dist)

class Plane:
    def __init__(self, norm: Vector, offset: float, surface):
        self._norm    = norm
        self._surface = surface
        self.offset   = offset

    def normal(self, pos: Vector):
        return self._norm

    def intersect(self, ray: Ray):
        denom = self._norm.dot(ray.dir)
        if (denom > 0):
            return None
        dist = (self._norm.dot(ray.start) + self.offset) / (-denom)
        return Intersection(self, ray, dist)

    def surface(self):
        return self._surface

class ShinySurface:
    def diffuse(self, pos: Vector):
        return ColorWhite

    def specular(self, pos: Vector):
        return ColorGrey

    def reflect(self, pos: Vector):
        return 0.7

    def roughness(self):
        return 250

class CheckerboardSurface:
    def diffuse(self, pos: Vector):
        if (math.floor(pos.z) + math.floor(pos.x)) % 2 != 0:
            return ColorWhite
        return ColorBlack

    def specular(self, pos: Vector):
        return ColorWhite

    def reflect(self, pos: Vector):
        if (math.floor(pos.z) + math.floor(pos.x)) % 2 != 0:
            return 0.1
        return 0.7

    def roughness(self):
        return 250

SurfaceShiny        = ShinySurface()
SurfaceCheckerboard = CheckerboardSurface()

class RayTracer:
    maxDepth = 5

    def intersections(self, ray: Ray):
        closest = FarAway
        closestInter = None
        for item in self.scene.things:
            inter = item.intersect(ray)
            if inter != None and inter.dist < closest:
                closestInter = inter
                closest = inter.dist
        return closestInter

    def testRay(self, ray: Ray):
        isect = self.intersections(ray)
        if isect != None:
            return isect.dist
        return None

    def traceRay(self, ray: Ray, depth: int):
        isect = self.intersections(ray)
        if (isect == None):
            return ColorBackground
        return self.shade(isect, depth)

    def shade(self, isect: Intersection, depth: int):
        d = isect.ray.dir
        pos = d.times(isect.dist).plus(isect.ray.start)
        normal = isect.thing.normal(pos)
        reflectDir = d.minus(normal.times(normal.dot(d)).times(2))

        naturalColor = ColorBackground.plus(self.getNaturalColor(isect.thing, pos, normal, reflectDir))
        reflectedColor = ColorGrey if (depth >= self.maxDepth) else self.getReflectionColor(isect.thing, pos, normal, reflectDir, depth)
        return naturalColor.plus(reflectedColor)

    def getReflectionColor(self, thing, pos: Vector, normal: Vector, rd: Vector, depth: int):
        return self.traceRay(Ray(pos, rd), depth + 1).scale(thing.surface().reflect(pos))

    def getNaturalColor(self, thing, pos: Vector, norm: Vector, rd: Vector):
        color = ColorDefaultColor
        for light in self.scene.lights:
            color = self.addLight(color, light, pos, norm, thing, rd)
        return color

    def addLight(self, col, light, pos, norm, thing, rd):
        ldis  = light.pos.minus(pos)
        livec = ldis.norm()
        ray = Ray(pos, livec)

        neatIsect = self.testRay(ray)

        isInShadow = False if(neatIsect == None) else (neatIsect <= ldis.mag())
        if (isInShadow):
            return col

        illum    = livec.dot(norm)
        specular = livec.dot(rd.norm())

        surface = thing.surface()

        lcolor = light.color.scale(illum) if (illum > 0) else ColorDefaultColor
        scolor = light.color.scale(math.pow(specular, surface.roughness())) if (specular > 0) else ColorDefaultColor

        surfaceDiffuse  = surface.diffuse(pos)
        surfaceSpecular = surface.specular(pos)

        return col.plus(lcolor.times(surfaceDiffuse)).plus(scolor.times(surfaceSpecular))

    def getPoint(self, x, y, camera, screenWidth, screenHeight):
        cx =  (x - (screenWidth  / 2.0)) / 2.0 / screenWidth
        cy = -(y - (screenHeight / 2.0)) / 2.0 / screenHeight
        return camera.right.times(cx).plus(camera.up.times(cy)).plus(camera.forward).norm()

    def render(self, scene, image, screenWidth, screenHeight):
        self.scene = scene
        for y in range(0,screenHeight):
            for x in range(0,screenWidth):
                ray = Ray(self.scene.camera.pos, self.getPoint(x, y, self.scene.camera, screenWidth, screenHeight))
                color = self.traceRay(ray, 0)
                image.putpixel((x,y), color.toDrawingColor())
class Scene:
    def __init__(self):
        self.things = [
            Plane (Vector(0.0, 1.0, 0.0)  ,0.0, SurfaceCheckerboard),
            Sphere(Vector(0.0, 1.0,-0.25),1.0, SurfaceShiny),
            Sphere(Vector(-1.0, 0.5, 1.5) ,0.5, SurfaceShiny)
        ]
        self.lights = [
            Light(Vector(-2.0, 2.5, 0.0), Color(0.49, 0.07, 0.07)),
            Light(Vector(1.5, 2.5, 1.5),  Color(0.07, 0.07, 0.49)),
            Light(Vector(1.5, 2.5, -1.5), Color(0.07, 0.49, 0.071)),
            Light(Vector(0.0, 3.5, 0.0),  Color(0.21, 0.21, 0.35))
        ]
        self.camera = Camera(Vector(3.0, 2.0, 4.0), Vector(-1.0, 0.5, 0.0))

def run():
    width  = 500
    height = 500
    image =  Image.new("RGB", (width, height), "white")

    t1 = time.time()
    rayTracer = RayTracer()
    scene     = Scene()
    rayTracer.render(scene, image, width, height)
    t2 = time.time()
    t = t2 -t1

    image.save("py-ray-tracer.png","png")
    print ("Completed in %d sec" % t)

run()