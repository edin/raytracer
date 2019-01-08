import math

let FarAway: float = 1000000.0

type
  SurfaceType = enum
    ShinySurface, CheckerBoardSurface

  ObjectType = enum
    Sphere, Plane

  RgbColor = object
    b, g, r, a: uint8

  Vector = object
    x, y, z: float

  Color = object
    r, b, g: float

  Camera = object
    forward, right, up, pos: Vector

  Ray = object
    start, dir: Vector

  Surface = object
    diffuse, specular: Color
    reflect, roughness: float

  Thing = object
    surfaceType: SurfaceType
    case objectType: ObjectType
    of Sphere:
      center: Vector
      radius2: float
    of Plane:
      normal: Vector
      offset: float

  Intersection = object
    thing*: Thing
    ray: Ray
    dist: float

  Light = object
    pos: Vector
    color: Color

  Scene = object
    maxDepth: int
    thingCount: int
    lightCount: int
    things: seq[Thing]
    lights: seq[Light]
    camera: Camera

  SurfaceProperties = object
    diffuse, specular: Color
    reflect, roughness: float

let white        = Color(r: 1.0, g: 1.0, b: 1.0)
let grey         = Color(r: 0.5, g: 0.5, b: 0.5)
let black        = Color(r: 0.0, g: 0.0, b: 0.0)
let background   = Color(r: 0.0, g: 0.0, b: 0.0)
let defaultColor = Color(r: 0.0, g: 0.0, b: 0.0)

method Cross(v1: Vector, v2: Vector): Vector {.base.} =
  Vector(
    x: v1.y * v2.z - v1.z * v2.y,
    y: v1.z * v2.x - v1.x * v2.z,
    z: v1.x * v2.y - v1.y * v2.x
  )

method Length(v: Vector): float {.base.} =
  sqrt(v.x * v.x + v.y * v.y + v.z * v.z)

method Scale(v: Vector, k: float): Vector {.base.}  =
  Vector(
    x: k * v.x,
    y: k * v.y,
    z: k * v.z
  )

method Norm(v: Vector): Vector {.base.} =
  let mag: float = v.Length
  var s:   float
  if (mag == 0):
    s = FarAway
  else:
    s = 1.0 / mag
  return v.Scale(s)

method Dot(v1: Vector, v2: Vector): float {.base.} =
  (v1.x * v2.y) + (v1.y * v2.y) + (v1.z * v2.z)

method Add(v1: Vector, v2: Vector): Vector {.base.} =
  Vector(
    x: v1.x + v2.x,
    y: v1.y + v2.y,
    z: v1.z + v2.z
  )

method Sub(v1: Vector, v2: Vector): Vector {.base.} =
  return Vector(
    x: v1.x - v2.x,
    y: v1.y - v2.y,
    z: v1.z - v2.z
  )

method Scale(color: Color, k: float): Color {.base.} =
  Color(
    r: k * color.r,
    g: k * color.g,
    b: k * color.b
  )

method Multiply(a: Color, b: Color): Color {.base.} =
  Color(
    r: a.r * b.r,
    g: a.g * b.g,
    b: a.b * b.b
  )

method Add(a: Color, b: Color): Color {.base.} =
  Color(
    r: a.r + b.r,
    g: a.g + b.g,
    b: a.b + b.b
  )

proc Legalize(c: float): uint8 =
  let x = cast[int](c * 255)
  if (x < 0):
    return 0
  if (x > 255):
    return 255
  return cast[uint8](x)

method ToDrawingColor(c: Color): RgbColor {.base.} =
  var color: RgbColor
  color.r = Legalize(c.r)
  color.g = Legalize(c.g)
  color.b = Legalize(c.b)
  color.a = 255
  return color

proc CreateCamera(pos: Vector, lookAt: Vector): Camera =
  var down = Vector(x:0.0, y: -1.0, z: 0.0)
  var forward = lookAt.Sub(pos)

  var camera: Camera
  camera.pos      = pos
  camera.forward  = forward.Norm()
  camera.right    = camera.forward.Cross(down)
  camera.up       = camera.forward.Cross(camera.right)

  let rightNorm = camera.right.Norm()
  let upNorm    = camera.up.Norm()

  camera.right = rightNorm.Scale(1.5)
  camera.up    = upNorm.Scale(1.5)
  return camera

method Normal(obj: Thing, pos: Vector): Vector {.base.} =
  case obj.objectType:
    of Sphere:
      return pos.Sub(obj.center).Norm()
    of Plane:
      return obj.normal
  return Vector(x:0.0, y:0.0, z:0.0)

proc ObjectIntersect(obj: Thing, ray: Ray): Intersection =
  case obj.objectType:
    of Sphere:
      let eo = obj.center.Sub(ray.start)
      let v  = eo.Dot(ray.dir)
      var dist = 0.0
      if (v >= 0):
          let disc = obj.radius2 - (eo.Dot(eo) - (v * v))
          if (disc >= 0):
              dist = v - sqrt(disc)
      if (dist != 0):
          result.thing = obj
          result.ray   = ray
          result.dist  = dist
          return result
    of Plane:
      let denom = obj.center.Dot(ray.dir)
      if (denom <= 0):
        result.dist  = (obj.normal.Dot(ray.start) + obj.offset) / (-denom)
        result.thing = obj
        result.ray   = ray
        return result

proc CreateVector(x: float, y: float, z: float): Vector =
  return Vector(x: x, y: y, z: z)

proc CreateLight(pos: Vector, color: Color): Light =
  return Light(pos: pos, color: color)

proc CreateColor(r: float, g: float, b: float): Color =
  return Color(r: r, g: g, b: b)

proc CreateSphere(center: Vector, radius: float, surfaceType: SurfaceType): Thing =
  var sphere: Thing
  sphere.surfaceType = surfaceType
  sphere.objectType = Sphere
  sphere.radius2 = radius * radius
  sphere.center = center
  return sphere

proc CreatePlane(normal: Vector, offset: float, surfaceType: SurfaceType): Thing =
  var plane: Thing
  plane.surfaceType = surfaceType
  plane.objectType = Plane
  plane.normal  = normal
  plane.offset  = offset
  return plane

proc GetSurfaceProperties(obj: Thing, pos: Vector): SurfaceProperties =
  var properties: SurfaceProperties
  case obj.surfaceType:
    of ShinySurface:
      properties.diffuse   = white
      properties.specular  = grey
      properties.reflect   = 0.7
      properties.roughness = 250.0
    of CheckerBoardSurface:
      let val = (int)(floor(pos.z) + floor(pos.x))
      if (val % 2 != 0):
          properties.reflect   = 0.1
          properties.diffuse   = white
      else:
          properties.reflect   = 0.7
          properties.diffuse   = black
      properties.specular  = white
      properties.roughness = 150.0
  return properties

proc CreateScene(): Scene =
  var scene: Scene;
  scene.maxDepth   = 5

  scene.things = @[
    CreatePlane(CreateVector(0.0, 1.0, 0.0), 0.0, CheckerBoardSurface),
    CreateSphere(CreateVector(0.0, 1.0, -0.25), 1.0, ShinySurface),
    CreateSphere(CreateVector(-1.0, 0.5, 1.5), 0.5, ShinySurface)
  ]

  scene.lights =  @[
    CreateLight(CreateVector(-2.0, 2.5, 0.0), CreateColor(0.49, 0.07, 0.07)),
    CreateLight(CreateVector(1.5, 2.5, 1.5),  CreateColor(0.07, 0.07, 0.49)),
    CreateLight(CreateVector(1.5, 2.5, -1.5), CreateColor(0.07, 0.49, 0.071)),
    CreateLight(CreateVector(0.0, 3.5, 0.0),  CreateColor(0.21, 0.21, 0.35))
  ]

  scene.camera = CreateCamera(CreateVector(3.0, 2.0, 4.0), CreateVector(-1.0, 0.5, 0.0))
  return scene

proc Intersections(ray: Ray, scene: Scene): Intersection
  double closest = INFINITY
  Intersection closestInter
  closestInter.thing = NULL

  int thingCount = scene.thingCount

  Thing *first = &scene.things[0]
  Thing *last  = &scene.things[thingCount-1]

  Intersection inter

  for (Thing *thing = first thing <= last ++thing):
    int intersect = ObjectIntersect(thing, ray, &inter)
    if (intersect == 1  && inter.dist < closest)
      closestInter = inter
      closest = inter.dist
  return closestInter

method TestRay(scene: Scene, ray: Ray): float =
    Intersection isect = scene.Intersections(ray)
    if (isect.thing != NULL):
        return isect.dist
    return NAN

method TraceRay(scene: Scene, ray: Ray, depth: int): Color =
  Intersection isect = Intersections(ray, scene)
  if (isect.thing != NULL):
      return scene.Shade(&isect, depth)
  return background

method GetReflectionColor(scene: Scene, thing: Thing, pos: Vector, normal: Vector, rd: Vector, depth: int) =
  let ray = Ray(pos, rd)
  let color = scene.TraceRay(ray, depth + 1)
  let properties = GetSurfaceProperties(thing.surface, pos)
  return color.Scale(properties.reflect)

method GetNaturalColor(scene: Scene, Thing* thing, Vector *pos, Vector *norm, Vector *rd, Scene *scene)
  Color resultColor = black
  Vector rdNorm = rd.Norm()

  // SurfaceProperties sp
  // GetSurfaceProperties(thing.surface, pos, &sp)

  for item in scene.lights
    Vector ldis  = VectorSub(&light.pos, pos)
    Vector livec = VectorNorm(ldis)

    double ldisLen = VectorLength(&ldis)
    Ray ray = { *pos, livec }

    double neatIsect = TestRay(&ray, scene)

    let isInShadow = (neatIsect == NAN) ? 0 : (neatIsect <= ldisLen)
    if (!isInShadow):
      let illum   =  livec.Dot(norm)
      let specular = livec.Dot(rdNorm)

      Color lcolor = (illum > 0)    ? ScaleColor(light.color, illum) : defaultColor
      Color scolor = (specular > 0) ? ScaleColor(light.color, pow(specular, sp.roughness)) : defaultColor

      ColorMultiplySelf(&lcolor, &sp.diffuse)
      ColorMultiplySelf(&scolor, &sp.specular)

      Color result = lcolor.Add(scolor)
      resultColor = resultColor.Add(result)
  return resultColor

Color Shade(Intersection *isect, Scene *scene, int depth)
    Vector d = isect.ray.dir
    Vector scaled = VectorScale(&d, isect.dist)

    Vector pos = VectorAdd(&scaled, &isect.ray.start)
    Vector normal = ObjectNormal(isect.thing, &pos)
    double nodmalDotD = VectorDot(&normal, &d)
    Vector normalScaled = VectorScale(&normal, nodmalDotD * 2)

    Vector reflectDir = VectorSub(&d, &normalScaled)

    Color naturalColor = GetNaturalColor(isect.thing, &pos, &normal, &reflectDir, scene)
    naturalColor = ColorAdd(&background, &naturalColor)

    Color reflectedColor = (depth >= scene.maxDepth) ? grey : GetReflectionColor(isect.thing, &pos, &normal, &reflectDir, scene, depth)

    return ColorAdd(&naturalColor, &reflectedColor)

Vector GetPoint(int x, int y, Camera *camera, int screenWidth, int screenHeight)
  double recenterX = (x - (screenWidth / 2.0)) / 2.0 / screenWidth
  double recenterY = -(y - (screenHeight / 2.0)) / 2.0 / screenHeight

  Vector vx = VectorScale(&camera.right, recenterX)
  Vector vy = VectorScale(&camera.up, recenterY)

  Vector v = VectorAdd(&vx, &vy)
  Vector z = VectorAdd(&camera.forward, &v)

  z  = VectorNorm(z)
  return z

void RenderScene(Scene *scene, byte* bitmapData, int stride, int w, int h)
  Ray ray
  ray.start = scene.camera.pos
  for (int y = 0 y < h ++y)
  {
      RgbColor* pColor = (RgbColor*)(&bitmapData[y * stride])
      for (int x = 0 x < w ++x)
      {
          ray.dir = GetPoint(x, y, &scene.camera, h, w)
          Color color = TraceRay(&ray, scene, 0)
          *pColor = ToDrawingColor(&color)
          ++pColor
      }
  }

# void SaveRGBBitmap(byte* pBitmapBits, int lWidth, int lHeight, int wBitsPerPixel, const char* lpszFileName)
#   BITMAPINFOHEADER bmpInfoHeader = {0}
#   bmpInfoHeader.biSize = sizeof(BITMAPINFOHEADER)
#   bmpInfoHeader.biBitCount = wBitsPerPixel
#   bmpInfoHeader.biClrImportant = 0
#   bmpInfoHeader.biClrUsed = 0
#   bmpInfoHeader.biCompression = BI_RGB
#   bmpInfoHeader.biHeight = -lHeight
#   bmpInfoHeader.biWidth  = lWidth
#   bmpInfoHeader.biPlanes = 1
#   bmpInfoHeader.biSizeImage = lWidth* lHeight * (wBitsPerPixel/8)

#   BITMAPFILEHEADER bfh = {0}
#   bfh.bfType = 'B' + ('M' << 8)
#   bfh.bfOffBits = sizeof(BITMAPINFOHEADER) + sizeof(BITMAPFILEHEADER)
#   bfh.bfSize    = bfh.bfOffBits + bmpInfoHeader.biSizeImage

#   FILE *hFile
#   hFile = fopen(lpszFileName, "wb")
#   fwrite(&bfh, sizeof(char), sizeof(bfh), hFile)
#   fwrite(&bmpInfoHeader, sizeof(char), sizeof(bmpInfoHeader), hFile)
#   fwrite(pBitmapBits, sizeof(char), bmpInfoHeader.biSizeImage, hFile)
#   fclose(hFile)

# Start:

let t1 = GetTickCount()
Scene scene  = CreateScene()

int width  = 500
int height = 500
int stride = width * 4

byte* bitmapData = (byte*)(malloc(stride * height))

RenderScene(&scene, &bitmapData[0], stride, width, height)

long t2 = GetTickCount()
long time = t2 - t1

printf("Completed in %d ms\n", time)
SaveRGBBitmap(&bitmapData[0], width, height, 32, "cpp-raytracer.bmp")

ReleaseScene(&scene)