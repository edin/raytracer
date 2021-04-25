require "imageruby"

class Vector
  attr_accessor :x , :y , :z
  def initialize(x, y, z)
    @x, @y, @z = x, y, z
  end

  def self.scale(k, v)
    Vector.new(k * v.x, k * v.y, k * v.z)
  end

  def self.minus(v1, v2)
    Vector.new(v1.x - v2.x, v1.y - v2.y, v1.z - v2.z)
  end

  def self.plus(v1, v2)
    Vector.new(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z)
  end

  def self.dot(v1, v2)
    v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
  end

  def self.mag(v)
    Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
  end

  def self.norm(v)
    mag = Vector.mag(v)
    div = (mag == 0) ? Float::INFINITY : 1.0 / mag
    Vector.scale(div, v)
  end

  def self.cross(v1, v2)
    Vector.new(v1.y * v2.z - v1.z * v2.y, v1.z * v2.x - v1.x * v2.z, v1.x * v2.y - v1.y * v2.x)
  end
end

class Color
  attr_accessor :r, :g, :b

  def initialize(r, g, b)
    @r, @g, @b = r, g, b
  end

  def self.scale(k, v)
    Color.new(k * v.r, k * v.g, k * v.b)
  end

  def self.plus(v1, v2)
    Color.new(v1.r + v2.r, v1.g + v2.g, v1.b + v2.b)
  end

  def self.mult(v1, v2)
    Color.new(v1.r * v2.r, v1.g * v2.g, v1.b * v2.b)
  end

  def self.toDrawingColor(c)
    r = (c.r.clamp(0.0, 1.0)*255).floor
    g = (c.g.clamp(0.0, 1.0)*255).floor
    b = (c.b.clamp(0.0, 1.0)*255).floor
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
    @right   = Vector.scale(1.5, Vector.norm(Vector.cross(@forward, down)))
    @up      = Vector.scale(1.5, Vector.norm(Vector.cross(@forward, @right)))
  end
end

class Ray
  attr_accessor :start, :dir
  def initialize(start, dir)
    @start, @dir = start, dir
  end
end

class Intersection
  attr_accessor :thing, :ray, :dist
  def initialize(thing, ray, dist)
    @thing, @ray, @dist = thing, ray, dist
  end
end

class Light
  attr_accessor :pos, :color
  def initialize(pos, color)
    @pos, @color = pos, color
  end
end

class Sphere
  def initialize(center, radius, surface)
    @radius2, @_surface, @center = radius*radius, surface, center
  end

  def normal(pos)
    Vector.norm(Vector.minus(pos, @center))
  end

  def surface()
    @_surface
  end

  def intersect(ray)
    eo = Vector.minus(@center, ray.start)
    v  = Vector.dot(eo, ray.dir)
    dist = 0
    if (v >= 0)
      disc = @radius2 - (Vector.dot(eo, eo) - v * v)
      dist = v - Math.sqrt(disc) if (disc >= 0)
    end
    (dist == 0) ? nil : Intersection.new(self, ray, dist)
  end
end

class Plane
  def initialize(norm, offset, surface)
    @_norm, @_surface, @offset = norm, surface, offset
  end

  def normal(pos)
    @_norm
  end

  def intersect(ray)
    denom = Vector.dot(@_norm, ray.dir)
    return nil if (denom > 0)
    dist = (Vector.dot(@_norm, ray.start) + @offset) / (-denom)
    Intersection.new(self, ray, dist)
  end

  def surface()
    @_surface
  end
end

class ShinySurface
  def diffuse(pos)
    Color_white
  end

  def specular(pos)
    Color_grey
  end

  def reflect(pos)
    0.7
  end

  def roughness()
    250
  end
end

class CheckerboardSurface
  def diffuse(pos)
    ((pos.z).floor + (pos.x).floor).to_i.odd? ? Color_white : Color_black
  end

  def reflect(pos)
    ((pos.z).floor + (pos.x).floor).to_i.odd? ? 0.1 : 0.7
  end

  def specular(pos)
    Color_white
  end

  def roughness()
    250
  end
end

Surface_shiny        = ShinySurface.new
Surface_checkerboard = CheckerboardSurface.new

class RayTracer
  MaxDepth = 5

  def intersections(ray, scene)
    closest = Float::INFINITY
    closestInter = nil
    scene.things.each do |item|
      inter = item.intersect(ray)
      if inter && inter.dist < closest
        closestInter = inter
        closest = inter.dist
      end
    end
    closestInter
  end

  def testRay(ray, scene)
    isect = self.intersections(ray, scene)
    isect && isect.dist
  end

  def traceRay(ray, scene, depth)
    isect = self.intersections(ray, scene)
    isect == nil ? Color_background : self.shade(isect, scene, depth)
  end

  def shade(isect, scene, depth)
    d = isect.ray.dir
    pos = Vector.plus(Vector.scale(isect.dist, d), isect.ray.start)
    normal = isect.thing.normal(pos)
    reflectDir   = Vector.minus(d, Vector.scale(2, Vector.scale(Vector.dot(normal, d), normal)))
    naturalColor = Color.plus(Color_background,self.getNaturalColor(isect.thing, pos, normal, reflectDir, scene))
    reflectedColor = (depth >= MaxDepth) ? Color_grey : self.getReflectionColor(isect.thing, pos, normal, reflectDir, scene, depth)
    Color.plus(naturalColor, reflectedColor)
  end

  def getReflectionColor(thing, pos, normal, rd, scene, depth)
    Color.scale(thing.surface().reflect(pos), self.traceRay(Ray.new(pos, rd), scene, depth + 1))
  end

  def getNaturalColor(thing, pos, norm, rd, scene)
    color = Color_defaultColor
    scene.lights.each { |light| color = self.addLight(color, light, pos, norm, scene, thing, rd) }
    color
  end

  def addLight(col, light, pos, norm, scene, thing, rd)
    ldis  = Vector.minus(light.pos, pos)
    livec = Vector.norm(ldis)
    neatIsect = self.testRay(Ray.new(pos, livec), scene)

    isInShadow = neatIsect && neatIsect <= Vector.mag(ldis)
    return col if isInShadow

    illum  = Vector.dot(livec, norm)
    lcolor = (illum > 0) ? Color.scale(illum, light.color) : Color_defaultColor

    specular = Vector.dot(livec, Vector.norm(rd))
    scolor = (specular > 0) ? Color.scale(specular ** thing.surface().roughness(), light.color) : Color_defaultColor

    Color.plus(col, Color.plus(Color.mult(thing.surface().diffuse(pos), lcolor), Color.mult(thing.surface().specular(pos), scolor)))
  end

  def getPoint(x, y, screenWidth, screenHeight, camera)
    recenterX =  (x - (screenWidth  * 0.5)) / (screenWidth  * 2.0)
    recenterY = -(y - (screenHeight * 0.5)) / (screenHeight * 2.0)
    Vector.norm(Vector.plus(camera.forward, Vector.plus(Vector.scale(recenterX, camera.right), Vector.scale(recenterY, camera.up))))
  end

  def render(scene, image, screenWidth, screenHeight)
    screenHeight.times do |y|
      screenWidth.times do |x|
        color = self.traceRay(Ray.new(scene.camera().pos, self.getPoint(x, y, screenWidth, screenHeight, scene.camera())), scene, 0)
        r,g,b = Color.toDrawingColor(color)
        image.set_pixel(x,y, ImageRuby::Color.from_rgba(r,g,b, 255))
  end end end
end

class DefaultScene
  attr_accessor :things, :lights, :camera
  def initialize
    @things = [
      Plane.new(Vector.new(0.0, 1.0, 0.0), 0.0, Surface_checkerboard),
      Sphere.new(Vector.new(0.0, 1.0, -0.25), 1.0, Surface_shiny),
      Sphere.new(Vector.new(-1.0, 0.5, 1.5), 0.5, Surface_shiny)
    ]
    @lights = [
      Light.new(Vector.new(-2.0, 2.5, 0.0), Color.new(0.49, 0.07, 0.07)),
      Light.new(Vector.new(1.5, 2.5, 1.5),  Color.new(0.07, 0.07, 0.49)),
      Light.new(Vector.new(1.5, 2.5, -1.5), Color.new(0.07, 0.49, 0.071)),
      Light.new(Vector.new(0.0, 3.5, 0.0),  Color.new(0.21, 0.21, 0.35))
    ]
    @camera = Camera.new(Vector.new(3.0, 2.0, 4.0), Vector.new(-1.0, 0.5, 0.0))
  end
end

width, height = 500, 500
image = ImageRuby::Image.new(width, height, ImageRuby::Color.black)

t1 = Time.now
rayTracer = RayTracer.new()
scene     = DefaultScene.new()
rayTracer.render(scene, image, width, height)
t2 = (Time.now - t1) * 1000

puts "Completed in #{t2} ms"
image.save("ruby-raytracer-opt.bmp", :bmp)
