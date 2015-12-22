# Following libs are required:
#   gem install imageruby
#   gem install imageruby-bmp

require "rubygems"
require "imageruby"

class Vector
    attr_accessor :x , :y , :z
    def initialize(x,y,z)
        @x = x
        @y = y
        @z = z
    end

    def self.times(k, v)
        return Vector.new(k * v.x, k * v.y, k * v.z)
    end

    def self.times(k, v)
        return Vector.new(k * v.x, k * v.y, k * v.z)
    end

    def self.minus(v1, v2)
        return Vector.new(v1.x - v2.x, v1.y - v2.y, v1.z - v2.z)
    end

    def self.plus(v1, v2)
        return Vector.new(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z)
    end

    def self.dot(v1, v2)
        return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
    end

    def self.mag(v)
        return Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    end

    def self.norm(v)
        mag = Vector.mag(v)
        if (mag == 0)
            div = Float::INFINITY
        else
            div = 1.0 / mag
        end
        return Vector.times(div, v)
    end

    def self.cross(v1, v2)
        return Vector.new(v1.y * v2.z - v1.z * v2.y, v1.z * v2.x - v1.x * v2.z, v1.x * v2.y - v1.y * v2.x)
    end
end

class Color
    attr_accessor :r, :g, :b

    def initialize(r,g,b)
        @r, @g, @b = r, g, b
    end

    def self.scale(k, v)
        return Color.new(k * v.r, k * v.g, k * v.b)
    end

    def self.plus(v1, v2)
        return Color.new(v1.r + v2.r, v1.g + v2.g, v1.b + v2.b)
    end

    def self.times(v1, v2)
        return Color.new(v1.r * v2.r, v1.g * v2.g, v1.b * v2.b)
    end

    def self.toDrawingColor(c)
        clamp = lambda do |d|
            return 1 if d > 1
            return 0 if d < 0
            return d
        end
        r = (clamp.(c.r)*255).floor
        g = (clamp.(c.g)*255).floor
        b = (clamp.(c.b)*255).floor
        return r, g ,b
    end
end

Color_white        = Color.new(1.0, 1.0, 1.0)
Color_grey         = Color.new(0.5, 0.5, 0.5)
Color_black        = Color.new(0.0, 0.0, 0.0)
Color_background   = Color_black
Color_defaultColor = Color_black


class Camera
    attr_accessor :pos, :forward, :right, :up
    def initialize(pos, lookAt)
        down     = Vector.new(0.0, -1.0, 0.0)
        @pos     = pos
        @forward = Vector.norm(Vector.minus(lookAt, @pos))
        @right   = Vector.times(1.5, Vector.norm(Vector.cross(@forward, down)))
        @up      = Vector.times(1.5, Vector.norm(Vector.cross(@forward, @right)))
    end
end

class Ray
    attr_accessor :start, :dir
    def initialize(start, dir)
        @start = start
        @dir   = dir
    end
end

class Thing
end

class Intersection
    attr_accessor :thing, :ray, :dist
    def initialize(thing, ray, dist)
        @thing = thing
        @ray   = ray
        @dist  = dist
    end
end

class Surface
    def diffuse(pos)
    end
    def specular(pos)
    end
    def reflect(pos)
    end
    def roughness()
    end
end

class Thing
    def intersect(ray)
    end
    def normal(pos)
    end
    def surface()
    end
end

class Light
    attr_accessor :pos, :color
    def initialize(pos, color)
        @pos   = pos
        @color = color
    end
end

class Scene
    def things()
    end
    def lights()
    end
    def camera()
    end
end


class Sphere < Thing
    def initialize(center, radius, surface)
        @radius2 = radius*radius
        @_surface = surface
        @center  = center
    end

    def normal(pos)
        return Vector.norm(Vector.minus(pos, @center))
    end

    def surface()
        return @_surface
    end

    def intersect(ray)
        eo = Vector.minus(@center, ray.start)
        v  = Vector.dot(eo, ray.dir)
        dist = 0
        if (v >= 0)
            disc = @radius2 - (Vector.dot(eo, eo) - v * v)
            if (disc >= 0)
                dist = v - Math.sqrt(disc)
            end
        end
        if (dist == 0)
            return nil
        end
        return Intersection.new(self, ray, dist)
    end
end

class Plane < Thing
    def initialize(norm, offset, surface)
        @_norm    = norm
        @_surface = surface
        @offset   = offset
    end

    def normal(pos)
        return @_norm
    end

    def intersect(ray)
        denom = Vector.dot(@_norm, ray.dir)
        return nil if (denom > 0)
        dist = (Vector.dot(@_norm, ray.start) + @offset) / (-denom)
        return Intersection.new(self, ray, dist)
    end

    def surface()
        return @_surface
    end
end

class ShinySurface < Surface
    def diffuse(pos)
        return Color_white
    end
    def specular(pos)
        return Color_grey
    end
    def reflect(pos)
        return 0.7
    end
    def roughness()
        return 250
    end
end

class CheckerboardSurface < Surface
    def diffuse(pos)
        return Color_white if ((pos.z).floor + (pos.x).floor) % 2 != 0
        return Color_black
    end

    def specular(pos)
        return Color_white
    end

    def reflect(pos)
        return 0.1 if ((pos.z).floor  + (pos.x).floor) % 2 != 0
        return 0.7
    end

    def roughness()
        return 250
    end
end

Surface_shiny        = ShinySurface.new
Surface_checkerboard = CheckerboardSurface.new

class RayTracer
    MaxDepth = 5

    def intersections(ray, scene)
        closest = Float::INFINITY
        closestInter = nil
        for item in scene.things()
            inter = item.intersect(ray)
            if inter != nil and inter.dist < closest
                closestInter = inter
                closest = inter.dist
            end
        end
        return closestInter
    end

    def testRay(ray, scene)
        isect = self.intersections(ray, scene)
        return isect.dist if isect != nil
        return nil
    end

    def traceRay(ray, scene, depth)
        isect = self.intersections(ray, scene)
        return Color_background if (isect == nil)
        return self.shade(isect, scene, depth)
    end

    def shade(isect, scene, depth)
        d = isect.ray.dir
        pos = Vector.plus(Vector.times(isect.dist, d), isect.ray.start)
        normal = isect.thing.normal(pos)
        reflectDir   = Vector.minus(d, Vector.times(2, Vector.times(Vector.dot(normal, d), normal)))
        naturalColor = Color.plus(Color_background,self.getNaturalColor(isect.thing, pos, normal, reflectDir, scene))

        if (depth >= MaxDepth)
            reflectedColor = Color_grey
        else
            reflectedColor = self.getReflectionColor(isect.thing, pos, normal, reflectDir, scene, depth)
        end
        return Color.plus(naturalColor, reflectedColor)
    end

    def getReflectionColor(thing, pos, normal, rd, scene, depth)
        return Color.scale(thing.surface().reflect(pos), self.traceRay(Ray.new(pos, rd), scene, depth + 1))
    end

    def getNaturalColor(thing, pos, norm, rd, scene)
        color = Color_defaultColor
        for light in scene.lights()
            color = self.addLight(color, light,pos, norm,scene,thing,rd)
        end
        return color
    end

    def addLight(col, light, pos, norm, scene, thing, rd)
        ldis  = Vector.minus(light.pos, pos)
        livec = Vector.norm(ldis)
        neatIsect = self.testRay(Ray.new(pos, livec), scene)

        isInShadow = false
        isInShadow = neatIsect <= Vector.mag(ldis) if neatIsect != nil

        return col if isInShadow

        illum = Vector.dot(livec, norm)

        lcolor = Color_defaultColor
        lcolor = Color.scale(illum, light.color) if illum > 0

        specular = Vector.dot(livec, Vector.norm(rd))
        scolor   = Color_defaultColor
        scolor   = Color.scale(specular ** thing.surface().roughness(), light.color) if (specular > 0)

        return Color.plus(col, Color.plus(Color.times(thing.surface().diffuse(pos), lcolor), Color.times(thing.surface().specular(pos), scolor)))
    end

    def getPoint(x, y, camera,screenWidth,screenHeight)
        recenterX = lambda  do |x|
            (x - (screenWidth  / 2.0)) / 2.0 / screenWidth
        end
        recenterY = lambda  do |y|
            -(y - (screenHeight / 2.0)) / 2.0 / screenHeight
        end
        return Vector.norm(Vector.plus(camera.forward, Vector.plus(Vector.times(recenterX.(x), camera.right), Vector.times(recenterY.(y), camera.up))))
    end

    def render(scene, image, screenWidth, screenHeight)
        for y in (0..screenHeight-1)
            for x in (0..screenWidth-1)
                color = self.traceRay(Ray.new(scene.camera().pos, self.getPoint(x, y, scene.camera(),screenWidth, screenHeight )) , scene, 0)
                r,g,b = Color.toDrawingColor(color)
                image.set_pixel(x,y, ImageRuby::Color.from_rgba(r,g,b, 255));
            end
        end
    end
end

class DefaultScene < Scene
    def initialize
        @things = [
            Plane.new(Vector.new(0.0, 1.0, 0.0)  ,0.0, Surface_checkerboard),
            Sphere.new(Vector.new(0.0, 1.0, -0.25),1.0, Surface_shiny),
            Sphere.new(Vector.new(-1.0, 0.5, 1.5) ,0.5, Surface_shiny)
        ]
        @lights = [
             Light.new(Vector.new(-2.0, 2.5, 0.0), Color.new(0.49, 0.07, 0.07)),
             Light.new(Vector.new(1.5, 2.5, 1.5),  Color.new(0.07, 0.07, 0.49)),
             Light.new(Vector.new(1.5, 2.5, -1.5), Color.new(0.07, 0.49, 0.071)),
             Light.new(Vector.new(0.0, 3.5, 0.0),  Color.new(0.21, 0.21, 0.35))
        ]
        @camera = Camera.new(Vector.new(3.0, 2.0, 4.0), Vector.new(-1.0, 0.5, 0.0))
    end

    def things
        return @things
    end

    def lights
        return @lights
    end

    def camera
        return @camera
    end
end

width  = 500
height = 500
image = ImageRuby::Image.new(width,height, ImageRuby::Color.black)

t1 = Time.now
rayTracer = RayTracer.new()
scene     = DefaultScene.new()
rayTracer.render(scene, image, width, height)
t2 = Time.now

t = (t2 -t1)*1000

puts "Completed in #{t} ms"
image.save("ruby-raytracer.bmp", :bmp)