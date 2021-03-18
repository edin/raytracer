import math
import times
import macros
type
  SurfaceType = enum
    ShinySurface, CheckerBoardSurface

  ObjectType = enum
    Sphere, Plane

  RgbColor {.packed.} = object
    b, g, r, a: uint8

  Vector = object
    x, y, z: float64

  Color = object
    r, g, b: float64

  VC = Vector | Color

  Camera = object
    forward, right, up, pos: Vector

  Thing = object
    surfaceType: SurfaceType
    case objectType: ObjectType
    of Sphere:
      center: Vector
      radius2: float64
    of Plane:
      normal: Vector
      offset: float64

  Light = object
    pos: Vector
    color: Color

  Scene[T, L: static int] = object
    maxDepth: int
    things: array[T, Thing]
    lights: array[L, Light]
    camera: Camera

  SurfaceProperties = object
    diffuse, specular: Color
    reflect: float64
    roughness: (when defined(intpow): uint else: float64)

func pow(x: float64, y: uint): float64{.inline.} =
  result = 1.0
  var
    base = x
    exp = y
  while exp != 0:
    if (exp and 1) == 1:
      result *= base
    exp = exp div 2
    base *= base

#init procs
func initVector(x, y, z: float64): Vector{.noinit, inline.} =
  result.x = x
  result.y = y
  result.z = z

func toRgbColor(c: Color): RgbColor{.noinit, inline.} =
  #as long as we never have a negative color
  template legalize(c: float64): uint8 = (if c > 1.0: 255'u8 else: uint8(c*255.0))
  result.r = legalize(c.r)
  result.g = legalize(c.g)
  result.b = legalize(c.b)
  result.a = 255

#wankery i cant help it
macro getfield(x: untyped, f: static string): untyped =
  let id = ident(f)
  result = quote do:
    `x`.`id`
template fieldop(res, obj1, obj2: typed, op: untyped): untyped =
  for fld, val1, val2 in fieldpairs(obj1, obj2):
    let
      a{.inject.} = obj1.getfield(fld)
      b{.inject.} = obj2.getfield(fld)
    res.getfield(fld) = op

###Vector Math
func cross(v1, v2: Vector): Vector =
  initVector(
    x = v1.y * v2.z - v1.z * v2.y,
    y = v1.z * v2.x - v1.x * v2.z,
    z = v1.x * v2.y - v1.y * v2.x
  )
func dot(v1, v2: Vector): float64 =
  ((v1.x * v2.x) + (v1.y * v2.y) + (v1.z * v2.z))

func len(v: Vector): float64 =
  sqrt(v.x * v.x + v.y * v.y + v.z * v.z)

func `*`[T: VC](v: T, k: float64): T =
  for fld, val in v.fieldpairs:
    result.getfield(fld) = v.getfield(fld) * k

func `*`[T: VC](v1, v2: T): T = fieldop(result, v1, v2, a*b)
func `+`[T: VC](v1, v2: T): T = fieldop(result, v1, v2, a+b)
func `-`[T: VC](v1, v2: T): T = fieldop(result, v1, v2, a - b)
func `+=`[T: VC](v1: var T, v2: T) = fieldop(v1, v1, v2, a+b)

func norm(v: Vector): Vector =
  when defined(quake):
    type Naughty{.union.} = object
      d: float64
      i: int64
    var res = cast[Naughty](v.x*v.x + v.y*v.y+v.z*v.z)
    let x2 = res.d*0.5'f64
    res.i = 0x5fe6eb50c7b537a9 - (res.i shr 1)
    res.d *= (1.5'f64 - (x2 * res.d * res.d))
    v * res.d
  else:
    v * (1.0 / v.len)

func getnormal(obj: Thing, pos: Vector): Vector =
  case obj.objectType:
    of Sphere:
      (pos - (obj.center)).norm()
    of Plane:
      obj.normal

#setup
const
  white = Color(r: 1.0, g: 1.0, b: 1.0)
  grey = Color(r: 0.5, g: 0.5, b: 0.5)
  black = Color(r: 0.0, g: 0.0, b: 0.0)
  background = black

func initCamera(pos: Vector, lookAt: Vector): Camera =
  let down = Vector(x: 0.0, y: -1.0, z: 0.0)
  let forward = lookAt - pos
  var camera: Camera
  camera.pos = pos
  camera.forward = forward.norm()
  camera.right = camera.forward.cross(down)
  camera.up = camera.forward.cross(camera.right)
  let rightNorm = camera.right.norm()
  let upNorm = camera.up.norm()
  camera.right = rightNorm * 1.5
  camera.up = upNorm * 1.5
  return camera

proc initSphere(center: Vector, radius: float64,
    surfaceType: SurfaceType): Thing =
  var r2 = radius * radius
  return Thing(surfaceType: surfaceType, objectType: Sphere, center: center, radius2: r2)

proc initPlane(normal: Vector, offset: float64,
    surfaceType: SurfaceType): Thing =
  return Thing(surfaceType: surfaceType, objectType: Plane, normal: normal,
      offset: offset)

func initScene(): auto =
  let
    maxDepth = 5

    things = [
      initPlane(Vector(x: 0.0, y: 1.0, z: 0.0), 0.0, CheckerBoardSurface),
      initSphere(Vector(x: -1.0, y: 0.5, z: 1.5), 0.5, ShinySurface),
      initSphere(Vector(x: 0.0, y: 1.0, z: -0.25), 1.0, ShinySurface)
      ]

    lights = [
      Light(pos: Vector(x: -2.0, y: 2.5, z: 0.0), color: Color(r: 0.49,
        g: 0.07, b: 0.07)),
      Light(pos: Vector(x: 1.5, y: 2.5, z: 1.5), color: Color(r: 0.07,
        g: 0.07, b: 0.49)),
      Light(pos: Vector(x: 1.5, y: 2.5, z: -1.5), color: Color(r: 0.07,
        g: 0.49, b: 0.071)),
      Light(pos: Vector(x: 0.0, y: 3.5, z: 0.0), color: Color(r: 0.21,
        g: 0.21, b: 0.35))
    ]

    camera = initCamera(Vector(x: 3.0, y: 2.0, z: 4.0), Vector(x: -1.0,
      y: 0.5, z: 0.0))
  return Scene[things.len, lights.len](maxDepth: maxDepth, things: things,
      lights: lights, camera: camera)



##   the real meat of the program ##
##
func getSurfaceProperties(obj: Thing, pos: Vector): SurfaceProperties{.noinit.} =
  case obj.surfaceType:
  of ShinySurface:
    result.diffuse = white
    result.specular = grey
    result.reflect = 0.7
    result.roughness = 250
  of CheckerBoardSurface:
    let val = (int)(floor(pos.z) + floor(pos.x)) and 1
    if val == 0:
      result.reflect = 0.7
      result.diffuse = black
    else:
      result.reflect = 0.1
      result.diffuse = white
    result.specular = white
    result.roughness = 150

template intersections(obj: Thing, start, dir: Vector, test,
    body: untyped): untyped =
  var dist{.inject.}: float64
  case obj.objectType:
  of Sphere:
    let
      eo = obj.center - start
      v = eo.dot(dir)
    if v >= 0:
      let disc = obj.radius2 - (eo.dot(eo) - (v * v))
      if disc >= 0:
        dist = v - sqrt(disc)
        if test:
          body
  of Plane:
    let denom = obj.normal.dot(dir)
    if (denom <= 0) and test:
      dist = (obj.normal.dot(start) + obj.offset) / (-denom)
      body
func getReflectionColor(scene: var Scene, sp: SurfaceProperties, pos,
    rd: Vector, depth: int): Color =
  scene.traceRay(pos, rd, depth + 1) * sp.reflect

func getNaturalColor(scene: var Scene, sp: SurfaceProperties,
    pos, rd, norm: Vector): Color =
  var rdNorm = rd.norm()
  for light in scene.lights:
    let
      ldis = light.pos - pos
      ldisLen = ldis.len()
      livec = ldis.norm()
      neatIsect = scene.testRay(pos, livec)

    if neatIsect > ldisLen:
      let illum = livec.dot(norm)
      let specular = livec.dot(rdNorm)
      assert illum > 0.0
      result += (light.color * illum) * sp.diffuse
      if specular > 0:
        result += (light.color * pow(specular, sp.roughness) * sp.specular)



func shade(scene: var Scene, thing: Thing, start, dir: Vector, dist: float64,
    depth: int): Color =
  let
    scaled = dir * dist
    pos = scaled + start
    normal = thing.getnormal(pos)
    reflectDir = dir - (normal * (normal.dot(dir) * 2))
    sp = thing.getSurfaceProperties(pos)
  when background == black:
    let naturalColor = getNaturalColor(scene, sp, pos, reflectDir, normal)
  else:
    let naturalColor = getNaturalColor(scene, sp, pos, reflectDir, normal) + background

  let reflectedColor = if depth >= scene.maxDepth:
      grey
    else:
      getReflectionColor(scene, sp, pos, reflectDir, depth)

  return naturalColor+reflectedColor


func testRay(scene: var Scene, start, dir: Vector): float64 =
  result = INF
  for thing in scene.things:
    intersections(thing, start, dir, dist < result):
      result = dist
func traceRay(scene: var Scene, start, dir: Vector, depth: int): Color =
  var
    closest = INF
    closestThing: ptr Thing
  for thng in scene.things.mitems:
    intersections(thng, start, dir, dist < closest):
      closest = dist
      closestThing = thng.addr
  result = if closestThing != nil:
    scene.shade(closestThing[], start, dir, closest, depth)
  else:
    black

### Render Scene
func getPoint(x, y: int, camera: Camera, sw, sh: float64): Vector =
  let
    recenterX = (x.float64 - (sw / 2.0)) / (2.0 * sw)
    recenterY = -(y.float64 - (sh / 2.0)) / (2.0 * sh)

    vx = camera.right * recenterX
    vy = camera.up * recenterY

    v = vx + vy
    z = camera.forward + v

  z.norm()

proc RenderScene(scene: var Scene, bitmapData: var seq[RgbColor], stride: int,
    w: int, h: int) =
  let start = scene.camera.pos
  var dir: Vector
  let
    wf = w.float64
    hf = h.float64
  for y in 0 ..< h:
    var pos = y * w
    for x in 0 ..< w:
      dir = getPoint(x, y, scene.camera, wf, hf)
      bitmapData[pos] = scene.traceRay(start, dir, 0).toRgbColor()
      pos = pos + 1


#Bitmap
proc SaveRGBBitmap(bitmapData: seq[RgbColor], width: int, height: int,
    wBitsPerPixel: int, fileName: string) =
  type DWORD = uint32
  type LONG = int32
  type WORD = int16
  const BI_RGB = 0

  type BITMAPINFOHEADER {.packed.} = object
    biSize: DWORD
    biWidth: LONG
    biHeight: LONG
    biPlanes: WORD
    biBitCount: WORD
    biCompression: DWORD
    biSizeImage: DWORD
    biXPelsPerMeter: LONG
    biYPelsPerMeter: LONG
    biClrUsed: DWORD
    biClrImportant: DWORD

  type BITMAPFILEHEADER {.packed.} = object
    bfType: WORD
    bfSize: DWORD
    bfReserved1: WORD
    bfReserved2: WORD
    bfOffBits: DWORD

  var bmpInfoHeader: BITMAPINFOHEADER
  bmpInfoHeader.biSize = DWORD(sizeof(BITMAPINFOHEADER))
  bmpInfoHeader.biBitCount = WORD(wBitsPerPixel)
  bmpInfoHeader.biClrImportant = 0
  bmpInfoHeader.biClrUsed = 0
  bmpInfoHeader.biCompression = BI_RGB
  bmpInfoHeader.biHeight = LONG(-height)
  bmpInfoHeader.biWidth = LONG(width)
  bmpInfoHeader.biPlanes = 1
  bmpInfoHeader.biSizeImage = DWORD(width * height * (wBitsPerPixel div 8))

  var bfh: BITMAPFILEHEADER
  bfh.bfType = 0x4D42 #'B' + ('M'shl 8)
  bfh.bfOffBits = sizeof(BITMAPINFOHEADER) + sizeof(BITMAPFILEHEADER)
  bfh.bfSize = bfh.bfOffBits + bmpInfoHeader.biSizeImage

  var file = open(fileName, fmWrite)

  discard file.writeBuffer(addr bfh, sizeof(BITMAPFILEHEADER))
  discard file.writeBuffer(addr bmpInfoHeader, sizeof(BITMAPINFOHEADER))
  for c in bitmapData:
    var x = c
    discard file.writeBuffer(addr x, sizeof(RgbColor))
  file.close()


var t1 = cpuTime()
var scene = initScene()
var width = 500
var height = 500
var stride = width * 4
var bitmapData = newSeq[RgbColor](width * height)

RenderScene(scene, bitmapData, stride, width, height)
var t2 = cpuTime()
var diff = (t2 - t1) * 1000

echo "CPU time [ms] ", diff

SaveRGBBitmap(bitmapData, width, height, 32, "nim-raytracer.bmp")
