import math

let FarAway: float = 1000000.0

type
  SurfaceType = enum
    ShinySurface, CheckerBoardSurface

  ObjectType = enum
    Sphere, Plane

  RgbColor {.packed.} = object
    b, g, r, a: uint8

  Vector = object
    x, y, z: float

  Color = object
    r, b, g: float

  Camera = object
    forward, right, up, pos: Vector

  Ray = object
    start, dir: Vector

  Thing = ref object
    surfaceType: SurfaceType
    case objectType: ObjectType
    of Sphere:
      center: Vector
      radius2: float
    of Plane:
      normal: Vector
      offset: float

  Intersection = object
    thing: Thing
    ray: Ray
    dist: float

  Light = object
    pos: Vector
    color: Color

  Scene = object
    maxDepth: int
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

proc Cross(v1: Vector, v2: Vector): Vector =
  return Vector(
    x: v1.y * v2.z - v1.z * v2.y,
    y: v1.z * v2.x - v1.x * v2.z,
    z: v1.x * v2.y - v1.y * v2.x
  )

proc Length(v: Vector): float =
  return sqrt(v.x * v.x + v.y * v.y + v.z * v.z)

proc Scale(v: Vector, k: float): Vector =
  return Vector(
    x: k * v.x,
    y: k * v.y,
    z: k * v.z
  )

proc Norm(v: Vector): Vector =
  let mag: float = v.Length
  var s:   float
  if mag == 0:
    s = FarAway
  else:
    s = 1.0 / mag
  return v.Scale(s)

proc Dot(v1: Vector, v2: Vector): float =
  return (v1.x * v2.x) + (v1.y * v2.y) + (v1.z * v2.z)

proc Add(v1: Vector, v2: Vector): Vector  =
  return Vector(
    x: v1.x + v2.x,
    y: v1.y + v2.y,
    z: v1.z + v2.z
  )

proc Sub(v1: Vector, v2: Vector): Vector =
  return Vector(
    x: v1.x - v2.x,
    y: v1.y - v2.y,
    z: v1.z - v2.z
  )

proc Scale(color: Color, k: float): Color  =
  return Color(
    r: k * color.r,
    g: k * color.g,
    b: k * color.b
  )

proc Multiply(a: Color, b: Color): Color =
  return Color(
    r: a.r * b.r,
    g: a.g * b.g,
    b: a.b * b.b
  )

proc Add(a: Color, b: Color): Color =
  return Color(
    r: a.r + b.r,
    g: a.g + b.g,
    b: a.b + b.b
  )

proc Legalize(c: float): uint8 =
  let x = (c * 255.0)
  if x < 0.0:
    return 0
  if x > 255.0:
    return 255
  return cast[uint8](x)

proc ToDrawingColor(c: Color): RgbColor =
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

proc Normal(obj: Thing, pos: Vector): Vector =
  case obj.objectType:
    of Sphere:
      return pos.Sub(obj.center).Norm()
    of Plane:
      return obj.normal
  return Vector(x:0.0, y:0.0, z:0.0)

proc ObjectIntersect(obj: Thing, ray: Ray): Intersection =
  result = Intersection(thing: nil, ray: ray, dist: 0)
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
    of Plane:
      let denom = obj.normal.Dot(ray.dir)
      if (denom <= 0):
        result.dist  = (obj.normal.Dot(ray.start) + obj.offset) / (-denom)
        result.thing = obj
        result.ray   = ray

proc CreateVector(x: float, y: float, z: float): Vector =
  return Vector(x: x, y: y, z: z)

proc CreateLight(pos: Vector, color: Color): Light =
  return Light(pos: pos, color: color)

proc CreateColor(r: float, g: float, b: float): Color =
  return Color(r: r, g: g, b: b)

proc CreateSphere(center: Vector, radius: float, surfaceType: SurfaceType): Thing =
  var r2 = radius * radius
  return Thing(surfaceType: surfaceType, objectType: Sphere, center: center, radius2: r2)

proc CreatePlane(normal: Vector, offset: float, surfaceType: SurfaceType): Thing =
  return Thing(surfaceType: surfaceType, objectType: Plane,  normal: normal, offset: offset)

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
      if (val mod 2 != 0):
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

proc Intersections(scene: Scene, ray: Ray): Intersection =
  var closest: float = FarAway

  for thing in scene.things:
    let intersect = ObjectIntersect(thing, ray)
    if not isNil(intersect.thing) and (intersect.dist < closest):
      result = intersect
      closest = intersect.dist
  return result

proc TestRay(scene: Scene, ray: Ray): float =
  let isect = scene.Intersections(ray)
  if not isNil(isect.thing):
    return isect.dist
  return NAN

proc GetNaturalColor(scene: Scene, thing: Thing, pos: Vector, norm: Vector, rd: Vector): Color
proc GetReflectionColor(scene: Scene, thing: Thing, pos: Vector, normal: Vector, rd: Vector, depth: int): Color

proc Shade(scene: Scene, isect: Intersection, depth: int): Color =
  var d = isect.ray.dir
  var scaled = d.Scale(isect.dist)

  var pos = scaled.Add(isect.ray.start)
  var normal = isect.thing.Normal(pos)
  var nodmalDotD = normal.Dot(d)
  var normalScaled = normal.Scale(nodmalDotD * 2)
  var reflectDir = d.Sub(normalScaled)

  var naturalColor = GetNaturalColor(scene, isect.thing, pos, normal, reflectDir)
  naturalColor = background.Add(naturalColor)

  var reflectedColor: Color

  if depth >= scene.maxDepth:
    reflectedColor = grey 
  else:
    reflectedColor = GetReflectionColor(scene, isect.thing, pos, normal, reflectDir, depth)

  return naturalColor.Add(reflectedColor)

proc TraceRay(scene: Scene, ray: Ray, depth: int): Color =
  let isect = Intersections(scene, ray)
  if not isNil(isect.thing):
    return scene.Shade(isect, depth)
  return background

proc GetReflectionColor(scene: Scene, thing: Thing, pos: Vector, normal: Vector, rd: Vector, depth: int): Color =
  var ray: Ray = Ray(start: pos, dir: rd)
  var color = scene.TraceRay(ray, depth + 1)
  var properties = GetSurfaceProperties(thing, pos)
  return color.Scale(properties.reflect)

proc GetNaturalColor(scene: Scene, thing: Thing, pos: Vector, norm: Vector, rd: Vector): Color =
  result = black
  var rdNorm = rd.Norm()

  var sp =  GetSurfaceProperties(thing, pos);

  for light in scene.lights:
    var ldis  = light.pos.Sub(pos)
    var livec = ldis.Norm()

    var ldisLen = ldis.Length()
    var ray = Ray(start: pos, dir: livec)
    var neatIsect = scene.TestRay(ray)

    let isInShadow = if (neatIsect == NAN): 
                      false 
                     else: 
                      neatIsect <= ldisLen
    if not isInShadow:
      let illum   =  livec.Dot(norm)
      let specular = livec.Dot(rdNorm)

      var lcolor = if illum > 0:    
                    light.color.Scale(illum) 
                   else:  
                    defaultColor
      var scolor = if specular > 0: 
                     light.color.Scale(pow(specular, sp.roughness))
                   else: 
                     defaultColor
      lcolor = lcolor.Multiply(sp.diffuse)
      scolor = scolor.Multiply(sp.specular)

      var resultCol = lcolor.Add(scolor)
      result = result.Add(resultCol)

proc GetPoint(x: int, y: int, camera: Camera, screenWidth: int, screenHeight: int): Vector =
  var sw: float = float(screenWidth)
  var sh: float = float(screenHeight)
  var xf = float(x)
  var yf = float(y)

  var recenterX =  (xf - (sw / 2.0)) / 2.0 / sw
  var recenterY = -(yf - (sh / 2.0)) / 2.0 / sh

  var vx: Vector = camera.right.Scale(recenterX)
  var vy: Vector = camera.up.Scale(recenterY)

  var v: Vector = vx.Add(vy)
  var z: Vector = camera.forward.Add(v)

  return z.Norm()

proc RenderScene(scene: Scene, bitmapData: var seq[RgbColor], stride: int, w: int, h: int) = 
  var ray: Ray
  ray.start = scene.camera.pos
  for y in 0 .. h-1:
    var pos = y * w
    for x in 0 .. w-1:
      ray.dir = GetPoint(x, y, scene.camera, h, w)
      var color = scene.TraceRay(ray, 0)
      bitmapData[pos] = color.ToDrawingColor()
      pos = pos + 1

proc SaveRGBBitmap(bitmapData: seq[RgbColor], width: int, height: int, wBitsPerPixel: int, fileName: string) =
  type DWORD = uint32
  type LONG  = int32
  type WORD  = int16
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

  var bmpInfoHeader : BITMAPINFOHEADER
  bmpInfoHeader.biSize = DWORD(sizeof(BITMAPINFOHEADER))
  bmpInfoHeader.biBitCount = WORD(wBitsPerPixel)
  bmpInfoHeader.biClrImportant = 0
  bmpInfoHeader.biClrUsed = 0
  bmpInfoHeader.biCompression = BI_RGB
  bmpInfoHeader.biHeight = LONG(-height)
  bmpInfoHeader.biWidth = LONG(width)
  bmpInfoHeader.biPlanes = 1
  bmpInfoHeader.biSizeImage = DWORD(width * height * (wBitsPerPixel div 8))

  var bfh : BITMAPFILEHEADER
  bfh.bfType = 0x4D42 #'B' + ('M'shl 8)
  bfh.bfOffBits = sizeof(BITMAPINFOHEADER) + sizeof(BITMAPFILEHEADER)
  bfh.bfSize = bfh.bfOffBits + bmpInfoHeader.biSizeImage

  var file = open(fileName, fmWrite )

  discard file.writeBuffer(addr bfh, sizeof(BITMAPFILEHEADER))
  discard file.writeBuffer(addr bmpInfoHeader, sizeof(BITMAPINFOHEADER))
  for c in bitmapData:
    var x = c
    discard file.writeBuffer(addr x, sizeof(RgbColor))
  file.close()

#let t1 = GetTickCount()
var scene  = CreateScene()
var width  = 500
var height = 500
var stride = width * 4

var bitmapData = newSeq[RgbColor](width * height)

RenderScene(scene, bitmapData, stride, width, height)

SaveRGBBitmap(bitmapData, width, height, 32, "nim-raytracer.bmp")
