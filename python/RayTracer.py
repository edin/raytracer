__author__ = 'Edin'

import math
import time
from PIL import Image

FAR_AWAY = math.pow(10,6)


class Vector:
    def __init__(self, x,y,z):
        self.x = x
        self.y = y
        self.z = z

    @staticmethod
    def times(k:float, v):
        return Vector(k * v.x, k * v.y, k * v.z)

    @staticmethod
    def times(k:float, v):
        return Vector(k * v.x, k * v.y, k * v.z)

    @staticmethod
    def minus(v1, v2):
        return Vector(v1.x - v2.x, v1.y - v2.y, v1.z - v2.z)

    @staticmethod
    def plus(v1, v2):
        return Vector(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z)

    @staticmethod
    def dot(v1, v2):
        return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z

    @staticmethod
    def mag(v):
        return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)

    @staticmethod
    def norm(v):
        mag = Vector.mag(v)
        div =  FAR_AWAY if (mag == 0) else  1.0 / mag
        return Vector.times(div, v)

    @staticmethod
    def cross(v1, v2):
        return Vector(v1.y * v2.z - v1.z * v2.y, v1.z * v2.x - v1.x * v2.z, v1.x * v2.y - v1.y * v2.x)


class Color:
    def __init__(self,r: float, g: float, b: float):
        self.r = r;
        self.g = g;
        self.b = b;

    @staticmethod
    def scale(k: float, v):
        return Color(k * v.r, k * v.g, k * v.b)

    @staticmethod
    def plus(v1, v2):
        return Color(v1.r + v2.r, v1.g + v2.g, v1.b + v2.b)

    @staticmethod
    def times(v1, v2):
        return Color(v1.r * v2.r, v1.g * v2.g, v1.b * v2.b)

    @staticmethod
    def toDrawingColor(c):
        legalize = lambda  d: 1 if(d > 1) else d
        r = math.floor(legalize(c.r)*255)
        g = math.floor(legalize(c.g)*255)
        b = math.floor(legalize(c.b)*255)
        return (r, g ,b)

Color_white     = Color(1.0, 1.0, 1.0)
Color_grey      = Color(0.5, 0.5, 0.5)
Color_black     = Color(0.0, 0.0, 0.0)
Color_background   = Color_black
Color_defaultColor = Color_black


class Camera:
    def __init__(self,pos: Vector, lookAt: Vector):
        down         = Vector(0.0, -1.0, 0.0)
        self.pos     = pos
        self.forward = Vector.norm(Vector.minus(lookAt, self.pos))
        self.right   = Vector.times(1.5, Vector.norm(Vector.cross(self.forward, down)))
        self.up      = Vector.times(1.5, Vector.norm(Vector.cross(self.forward, self.right)))

class Ray:
    def __init__(self,start:Vector, dir:Vector):
        self.start = start
        self.dir = dir

class Thing:pass

class Intersection:
    def __init__(self,thing: Thing, ray: Ray, dist: float):
        self.thing = thing
        self.ray =  ray
        self.dist = dist


class  Surface:
    def diffuse (self,pos: Vector):
        pass
    def specular(self,pos: Vector):
        pass
    def reflect (self,pos: Vector):
        pass
    def roughness(self):
        pass

class Thing:
    def intersect(self, ray: Ray):
        pass
    def normal(self, pos: Vector):
        pass
    def surface(self):
        pass

class Light:
    def __init__(self,pos: Vector, color: Color):
        self.pos = pos
        self.color = color


class Scene:
    def things(self):
        pass
    def lights(self):
        pass
    def camera(self):
        pass


class Sphere(Thing):
    def __init__(self,center: Vector,radius:float, surface:Surface):
        self.radius2 = radius*radius
        self._surface = surface
        self.center  = center

    def normal(self, pos: Vector):
        return Vector.norm(Vector.minus(pos, self.center))

    def surface(self):
        return self._surface

    def intersect(self, ray: Ray):
        eo = Vector.minus(self.center, ray.start)
        v = Vector.dot(eo, ray.dir)
        dist = 0;
        if (v >= 0):
            disc = self.radius2 - (Vector.dot(eo, eo) - v * v)
            if (disc >= 0):
                dist = v - math.sqrt(disc)
        if (dist == 0):
            return None
        return Intersection(self, ray, dist)

class Plane(Thing):
    def __init__(self,norm: Vector, offset:float, surface:Surface):
        self._norm    = norm
        self._surface = surface
        self.offset   = offset

    def normal(self, pos: Vector):
        return self._norm

    def intersect(self, ray: Ray):
        denom = Vector.dot(self._norm, ray.dir)
        if (denom > 0):
            return None
        dist = (Vector.dot(self._norm, ray.start) + self.offset) / (-denom);
        return Intersection(self, ray, dist)

    def surface(self):
        return self._surface

class ShinySurface(Surface):
    def diffuse(self,pos: Vector):
        return Color_white
    def specular(self,pos: Vector):
        return Color_grey
    def reflect(self,pos: Vector):
        return 0.7
    def roughness(self):
        return 250


class CheckerboardSurface(Surface):
    def diffuse(self,pos: Vector):
        if (math.floor(pos.z) + math.floor(pos.x)) % 2 != 0:
            return Color_white;
        return Color_black;
    def specular(self,pos: Vector):
        return Color_white

    def reflect(self,pos: Vector):
        if (math.floor(pos.z) + math.floor(pos.x)) % 2 != 0:
            return 0.1
        return 0.7

    def roughness(self):
        return 250

Surface_shiny = ShinySurface()
Surface_checkerboard = CheckerboardSurface()


class RayTracer:
    maxDepth = 5

    def intersections(self, ray: Ray, scene: Scene):
        closest = FAR_AWAY
        closestInter = None
        for item in scene.things():
            inter = item.intersect(ray)
            if inter != None and inter.dist < closest:
                closestInter = inter
                closest = inter.dist
        return closestInter

    def testRay(self, ray: Ray, scene: Scene):
        isect = self.intersections(ray, scene)
        if isect != None:
            return isect.dist
        return None

    def traceRay(self, ray: Ray, scene: Scene, depth: int):
        isect = self.intersections(ray, scene)
        if (isect == None):
            return Color_background
        return self.shade(isect, scene, depth)

    def shade(self,isect: Intersection, scene: Scene, depth: int):
        d = isect.ray.dir
        pos = Vector.plus(Vector.times(isect.dist, d), isect.ray.start)
        normal = isect.thing.normal(pos)
        reflectDir = Vector.minus(d, Vector.times(2, Vector.times(Vector.dot(normal, d), normal)))
        naturalColor = Color.plus(Color_background,self.getNaturalColor(isect.thing, pos, normal, reflectDir, scene))

        reflectedColor = Color_grey if (depth >= self.maxDepth) else self.getReflectionColor(isect.thing, pos, normal, reflectDir, scene, depth)
        return Color.plus(naturalColor, reflectedColor)

    def getReflectionColor(self, thing: Thing, pos: Vector, normal: Vector, rd: Vector, scene: Scene, depth: int):
        return Color.scale(thing.surface().reflect(pos), self.traceRay(Ray(pos, rd), scene, depth + 1))

    def getNaturalColor(self, thing: Thing, pos: Vector, norm: Vector, rd: Vector, scene: Scene):
        color = Color_defaultColor
        for light in scene.lights():
            color = self.addLight(color, light,pos, norm,scene,thing,rd)

        return color

    def addLight(self, col, light, pos, norm, scene, thing, rd):
        ldis  = Vector.minus(light.pos, pos)
        livec = Vector.norm(ldis)
        neatIsect = self.testRay(Ray( pos, livec), scene)
        isInShadow = False if(neatIsect == None ) else (neatIsect <= Vector.mag(ldis))
        if (isInShadow):
            return col
        illum    = Vector.dot(livec, norm)
        lcolor   = Color.scale(illum, light.color) if (illum > 0) else Color_defaultColor
        specular = Vector.dot(livec, Vector.norm(rd))

        scolor = Color.scale(math.pow(specular, thing.surface().roughness()), light.color) if (specular > 0) else Color_defaultColor

        return Color.plus(col, Color.plus(Color.times(thing.surface().diffuse(pos), lcolor), Color.times(thing.surface().specular(pos), scolor)))

    def getPoint(self, x, y, camera,screenWidth,screenHeight):
            recenterX = lambda x:  (x - (screenWidth  / 2.0)) / 2.0 / screenWidth
            recenterY = lambda y: -(y - (screenHeight / 2.0)) / 2.0 / screenHeight
            return Vector.norm(Vector.plus(camera.forward, Vector.plus(Vector.times(recenterX(x), camera.right), Vector.times(recenterY(y), camera.up))))

    def render(self, scene, image, screenWidth, screenHeight):
        for y in range(0,screenHeight):
            for x in range(0,screenWidth):
                color = self.traceRay(Ray(scene.camera().pos, self.getPoint(x, y, scene.camera(),screenWidth, screenHeight )) , scene, 0)
                c = Color.toDrawingColor(color)
                image.putpixel((x,y), c )
            print ("Y = %d" % y)


class DefaultScene(Scene):

    def __init__(self):
        self._things = [
            Plane (Vector(0.0, 1.0, 0.0)  ,0.0, Surface_checkerboard),
            Sphere(Vector(0.0, 1.0, -0.25),1.0, Surface_shiny),
            Sphere(Vector(-1.0, 0.5, 1.5) ,0.5, Surface_shiny)
        ]
        self._lights = [
             Light(Vector(-2.0, 2.5, 0.0), Color(0.49, 0.07, 0.07)),
             Light(Vector(1.5, 2.5, 1.5),  Color(0.07, 0.07, 0.49)),
             Light(Vector(1.5, 2.5, -1.5), Color(0.07, 0.49, 0.071)),
             Light(Vector(0.0, 3.5, 0.0),  Color(0.21, 0.21, 0.35))
        ]
        self._camera = Camera(Vector(3.0, 2.0, 4.0), Vector(-1.0, 0.5, 0.0))

    def things(self):
        return self._things

    def lights(self):
        return self._lights

    def camera(self):
        return self._camera


width  = 500
height = 500

image =  Image.new("RGB", (width, height), "white")


t1 = time.time()
rayTracer = RayTracer()
scene     = DefaultScene()
rayTracer.render(scene, image, width, height)
t2 = time.time()

t = t2 -t1
image.save("py-ray-tracer.png","png")

print ("Completed in %d sec" % t)