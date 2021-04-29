import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.ArrayList
import java.util.List
import java.util.concurrent.TimeUnit
import scala.beans.{BeanProperty, BooleanBeanProperty}

object RayTracer {
  def main(args: Array[String]): Unit = {
    val start: Long = System.nanoTime()
    val image: Image = new Image(500, 500)
    val scene: Scene = new Scene()
    val tracer: RayTracerEngine = new RayTracerEngine()
    tracer.render(scene, image)
    val t: Long = System.nanoTime() - start
    image.save("ray-scala.bmp")
    println("Rendered in: " + TimeUnit.NANOSECONDS.toMillis(t) + " ms")
  }
}

class Vector(var x: Double, var y: Double, var z: Double) {
  def times(k: Double): Vector = new Vector(k * x, k * y, k * z)
  def minus(v: Vector): Vector = new Vector(x - v.x, y - v.y, z - v.z)
  def plus(v: Vector): Vector = new Vector(x + v.x, y + v.y, z + v.z)
  def dot(v: Vector): Double = x * v.x + y * v.y + z * v.z
  def mag(): Double = Math.sqrt(x * x + y * y + z * z)
  def norm(): Vector = {
    val mag: Double = this.mag()
    val div: Double =
      if (mag == 0) java.lang.Double.POSITIVE_INFINITY else 1.0 / mag
    this.times(div)
  }
  def cross(v: Vector): Vector =
    new Vector(y * v.z - z * v.y, z * v.x - x * v.z, x * v.y - y * v.x)
}

class RGBColor {
  var b: Byte = _
  var g: Byte = _
  var r: Byte = _
  var a: Byte = _
}

object Color {
  var white: Color = new Color(1.0, 1.0, 1.0)
  var grey: Color = new Color(0.5, 0.5, 0.5)
  var black: Color = new Color(0.0, 0.0, 0.0)
  var background: Color = Color.black
  var defaultColor: Color = Color.black

  private def legalize(c: Double): Byte = {
    var x: Int = (c * 255.0).toInt
    if (x < 0) {
      x = 0;
    } else if (x > 255) {
      x = 255;
    }
    return x.toByte
  }
}

class Color(var r: Double, var g: Double, var b: Double) {
  def scale(k: Double): Color = new Color(k * r, k * g, k * b)
  def plus(v: Color): Color = new Color(r + v.r, g + v.g, b + v.b)
  def times(v: Color): Color = new Color(r * v.r, g * v.g, b * v.b)
  def toDrawingColor(): RGBColor = {
    val result: RGBColor = new RGBColor()

    result.r = Color.legalize(this.r)
    result.g = Color.legalize(this.g)
    result.b = Color.legalize(this.b)
    result.a = -1

    return result
  }
}

class Camera(var pos: Vector, lookAt: Vector) {
  val down: Vector = new Vector(0.0, -1.0, 0.0)
  var forward: Vector = lookAt.minus(this.pos).norm()
  var right: Vector = this.forward.cross(down).norm().times(1.5)
  var up: Vector = this.forward.cross(right).norm().times(1.5)

  def getPoint(x: Int, y: Int, screenWidth: Int, screenHeight: Int): Vector = {
    val recenterX: Double = (x - (screenWidth / 2.0)) / 2.0 / screenWidth
    val recenterY: Double = -(y - (screenHeight / 2.0)) / 2.0 / screenHeight
    forward.plus(right.times(recenterX)).plus(up.times(recenterY)).norm()
  }
}

class Ray {
  var start: Vector = _
  var dir: Vector = _

  def this(start: Vector, dir: Vector) = {
    this()
    this.start = start
    this.dir = dir
  }
}

class Intersection(var thing: Thing, var ray: Ray, var dist: Double)

trait Surface {
  def diffuse(pos: Vector): Color
  def specular(pos: Vector): Color
  def reflect(pos: Vector): Double
  def roughness(): Double
}

trait Thing {
  def intersect(ray: Ray): Intersection
  def normal(pos: Vector): Vector
  def surface(): Surface
}

class Light(var pos: Vector, var color: Color);

class Sphere(
    private var center: Vector,
    private var radius: Double,
    private var _surface: Surface
) extends Thing {

  var radius2: Double = this.radius * this.radius

  def normal(pos: Vector): Vector = pos.minus(this.center).norm()

  def intersect(ray: Ray): Intersection = {
    val eo: Vector = this.center.minus(ray.start)
    val v: Double = eo.dot(ray.dir)
    var dist: Double = 0
    if (v >= 0) {
      val disc: Double = this.radius2 - (eo.dot(eo) - v * v)
      if (disc >= 0) {
        dist = v - Math.sqrt(disc)
        return new Intersection(this, ray, dist)
      }
    }
    return null
  }

  override def surface(): Surface = this._surface
}

class Plane(
    private var norm: Vector,
    private var offset: Double,
    private var _surface: Surface
) extends Thing {

  def normal(pos: Vector): Vector = this.norm
  def intersect(ray: Ray): Intersection = {
    val denom: Double = norm.dot(ray.dir)
    if (denom > 0) {
      return null
    }
    val dist: Double = (norm.dot(ray.start) + offset) / (-denom)
    return new Intersection(this, ray, dist)
  }
  override def surface(): Surface = this._surface
}

object Surfaces {
  var shiny: Surface = new Surface() {
    override def diffuse(pos: Vector): Color = Color.white
    override def specular(pos: Vector): Color = Color.grey
    override def reflect(pos: Vector): Double = 0.7
    override def roughness(): Double = 250
  }

  var checkerboard: Surface = new Surface() {
    override def diffuse(pos: Vector): Color = {
      if ((Math.floor(pos.z) + Math.floor(pos.x)) % 2 != 0) {
        return Color.white
      }
      return Color.black
    }
    override def specular(pos: Vector): Color = Color.white
    override def reflect(pos: Vector): Double = {
      if ((Math.floor(pos.z) + Math.floor(pos.x)) % 2 != 0) {
        return 0.1
      }
      return 0.7
    }
    override def roughness(): Double = 150
  }
}

class Scene {
  var things: List[Thing] = new ArrayList[Thing]()
  var lights: List[Light] = new ArrayList[Light]()
  var camera: Camera =
    new Camera(new Vector(3.0, 2.0, 4.0), new Vector(-1.0, 0.5, 0.0))

  things.add(new Plane(new Vector(0.0, 1.0, 0.0), 0.0, Surfaces.checkerboard))
  things.add(new Sphere(new Vector(0.0, 1.0, -0.25), 1.0, Surfaces.shiny))
  things.add(new Sphere(new Vector(-1.0, 0.5, 1.5), 0.5, Surfaces.shiny))
  lights.add(new Light(new Vector(-2.0, 2.5, 0.0), new Color(0.49, 0.07, 0.07)))
  lights.add(new Light(new Vector(1.5, 2.5, 1.5), new Color(0.07, 0.07, 0.49)))
  lights.add(
    new Light(new Vector(1.5, 2.5, -1.5), new Color(0.07, 0.49, 0.071))
  )
  lights.add(new Light(new Vector(0.0, 3.5, 0.0), new Color(0.21, 0.21, 0.35)))
}

class RayTracerEngine {
  private var maxDepth: Int = 5

  private def intersections(ray: Ray, scene: Scene): Intersection = {
    var closest: Double = java.lang.Double.POSITIVE_INFINITY
    var closestInter: Intersection = null

    scene.things.forEach { thing =>
      val inter: Intersection = thing.intersect(ray)
      if (inter != null && inter.dist < closest) {
        closestInter = inter
        closest = inter.dist
      }
    }
    closestInter
  }

  private def traceRay(ray: Ray, scene: Scene, depth: Int): Color = {
    val isect: Intersection = intersections(ray, scene)
    if (isect == null) {
      return Color.background
    }
    shade(isect, scene, depth)
  }

  private def shade(isect: Intersection, scene: Scene, depth: Int): Color = {
    val d: Vector = isect.ray.dir
    val pos: Vector = d.times(isect.dist).plus(isect.ray.start)
    val normal: Vector = isect.thing.normal(pos)
    val reflectDir: Vector = d.minus(normal.times(normal.dot(d)).times(2))
    val naturalColor: Color = Color.background.plus(
      getNaturalColor(isect.thing, pos, normal, reflectDir, scene)
    )
    var reflectedColor: Color = Color.grey
    if (depth < this.maxDepth) {
      reflectedColor =
        getReflectionColor(isect.thing, pos, normal, reflectDir, scene, depth)
    }
    naturalColor.plus(reflectedColor)
  }

  private def getReflectionColor(
      thing: Thing,
      pos: Vector,
      normal: Vector,
      rd: Vector,
      scene: Scene,
      depth: Int
  ): Color = {
    val color: Color = traceRay(new Ray(pos, rd), scene, depth + 1)
    val reflect: Double = thing.surface().reflect(pos)
    color.scale(reflect)
  }

  private def getNaturalColor(
      thing: Thing,
      pos: Vector,
      norm: Vector,
      rd: Vector,
      scene: Scene
  ): Color = {
    var color: Color = Color.black
    scene.lights.forEach { light =>
      val ldis: Vector = light.pos.minus(pos)
      val livec: Vector = ldis.norm()
      val ray: Ray = new Ray(pos, livec)
      val neatIsect: Intersection = intersections(ray, scene)
      val isInShadow: Boolean = (neatIsect != null) && (neatIsect.dist <= ldis
        .mag())

      if (!isInShadow) {
        val illum: Double = livec.dot(norm)
        val specular: Double = livec.dot(rd.norm())
        var lcolor: Color = Color.defaultColor
        var scolor: Color = Color.defaultColor

        if (illum > 0) {
          lcolor = light.color.scale(illum)
        }

        if (specular > 0) {
          scolor =
            light.color.scale(Math.pow(specular, thing.surface().roughness()))
        }

        val surfDiffuse: Color = thing.surface().diffuse(pos)
        val surfSpecular: Color = thing.surface().specular(pos)
        color = color
          .plus(lcolor.times(surfDiffuse))
          .plus(scolor.times(surfSpecular))
      }
    }
    color
  }

  def render(scene: Scene, img: Image): Unit = {
    val h: Int = img.getHeight()
    val w: Int = img.getWidth()
    for (y <- 0 until h; x <- 0 until w) {
      val point: Vector = scene.camera.getPoint(x, y, w, h)
      val ray: Ray = new Ray(scene.camera.pos, point)
      val color: Color = this.traceRay(ray, scene, 0)
      img.setColor(x, y, color.toDrawingColor())
    }
  }
}

class BITMAPINFOHEADER {
  var biSize: Int = _
  var biWidth: Int = _
  var biHeight: Int = _
  var biPlanes: Short = _
  var biBitCount: Short = _
  var biCompression: Int = _
  var biSizeImage: Int = _
  var biXPelsPerMeter: Int = _
  var biYPelsPerMeter: Int = _
  var biClrUsed: Int = _
  var biClrImportant: Int = _

  def getBytes(): Array[Byte] =
    Encoding.Join(
      Encoding.DWORD(this.biSize),
      Encoding.LONG(this.biWidth),
      Encoding.LONG(this.biHeight),
      Encoding.WORD(this.biPlanes),
      Encoding.WORD(this.biBitCount),
      Encoding.DWORD(this.biCompression),
      Encoding.DWORD(this.biSizeImage),
      Encoding.LONG(this.biXPelsPerMeter),
      Encoding.LONG(this.biYPelsPerMeter),
      Encoding.DWORD(this.biClrUsed),
      Encoding.DWORD(this.biClrImportant)
    )
}

class BITMAPFILEHEADER {
  var bfType: Short = _
  var bfSize: Int = _
  var bfReserved: Int = _
  var bfOffBits: Int = _

  def getBytes(): Array[Byte] =
    Encoding.Join(
      Encoding.WORD(this.bfType),
      Encoding.DWORD(this.bfSize),
      Encoding.DWORD(this.bfReserved),
      Encoding.DWORD(this.bfOffBits)
    )
}

object Encoding {
  def DWORD(n: Int): Array[Byte] = {
    val b0: Byte = ((n >> 0) & 0x000000ff).toByte
    val b1: Byte = ((n >> 8) & 0x000000ff).toByte
    val b2: Byte = ((n >> 16) & 0x000000ff).toByte
    val b3: Byte = ((n >> 24) & 0x000000ff).toByte
    Array(b0, b1, b2, b3)
  }
  def LONG(n: Int): Array[Byte] = Encoding.DWORD(n)
  def WORD(n: Int): Array[Byte] = {
    val b0: Byte = (n & 0x000000ff).toByte
    val b1: Byte = ((n >> 8) & 0x000000ff).toByte
    Array(b0, b1)
  }

  def Join(elements: Array[Byte]*): Array[Byte] = {
    var size: Int = 0
    for (e <- elements) {
      size += e.length
    }
    val result: Array[Byte] = Array.ofDim[Byte](size)
    var pos: Int = 0

    for (e <- elements; b <- e) {
      result(pos) = b;
      pos += 1;
    }
    result
  }
}

class Image(@BeanProperty val width: Int, @BeanProperty val height: Int) {

  private var data: Array[RGBColor] = new Array[RGBColor](width * height)

  def setColor(x: Int, y: Int, color: RGBColor): Unit = {
    this.data(y * width + x) = color
  }

  def save(fileName: String): Unit = {
    val infoHeaderSize: Int = 40
    val fileHeaderSize: Int = 14
    val offBits: Int = infoHeaderSize + fileHeaderSize
    val infoHeader: BITMAPINFOHEADER = new BITMAPINFOHEADER()
    infoHeader.biSize = infoHeaderSize
    infoHeader.biBitCount = 32
    infoHeader.biClrImportant = 0
    infoHeader.biClrUsed = 0
    infoHeader.biCompression = 0
    infoHeader.biHeight = -height
    infoHeader.biWidth = width
    infoHeader.biPlanes = 1
    infoHeader.biSizeImage = (width * height * 4)
    val fileHeader: BITMAPFILEHEADER = new BITMAPFILEHEADER()
    fileHeader.bfType = 'B' + ('M' << 8)
    fileHeader.bfOffBits = offBits
    fileHeader.bfSize = (offBits + infoHeader.biSizeImage)

    try {
      val os: FileOutputStream = new FileOutputStream(fileName)

      os.write(fileHeader.getBytes());
      os.write(infoHeader.getBytes());

      for (color <- this.data) {
        val bgra = Array(color.b, color.g, color.r, color.a)
        os.write(bgra);
      }

      os.close()
    } catch {
      case ex: IOException => {}
    }
  }
}
