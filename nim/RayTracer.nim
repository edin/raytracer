import math

let INFINITY: float = 1000000.0;

type
  SurfaceType = enum
    SHINY_SURFACE, CHECKERBOARD_SURFACE

  ObjectType = enum
    SPHERE, PLANE

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
    surfaceType: SurfaceType
    diffuse, specular: Color
    reflect, roughness: float

  Thing = object
    objectType: ObjectType
    surface*: Surface
    center:   Vector
    radius:   float

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

let white        = Color(r: 1.0, g: 1.0, b: 1.0);
let grey         = Color(r: 0.5, g: 0.5, b: 0.5);
let black        = Color(r: 0.0, g: 0.0, b: 0.0);
let background   = Color(r: 0.0, g: 0.0, b: 0.0);
let defaultColor = Color(r: 0.0, g: 0.0, b: 0.0);

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
    s = INFINITY
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
  let x = cast[int](c * 255);
  if (x < 0):
    return 0
  if (x > 255):
    return 255
  return cast[uint8](x);

method ToDrawingColor(c: Color): RgbColor {.base.} =
  var color: RgbColor;
  color.r = Legalize(c.r);
  color.g = Legalize(c.g);
  color.b = Legalize(c.b);
  color.a = 255;
  return color;

proc CreateCamera(pos, lookAt: Vector): Camera =
  var down = Vector(x:0.0, y: -1.0, z: 0.0)
  var forward = lookAt.Sub(pos)

  var camera: Camera
  camera.pos      = pos
  camera.forward  = forward.Norm()
  camera.right    = camera.forward.Cross(down)
  camera.up       = camera.forward.Cross(camera.right)

  let rightNorm = camera.right.Norm();
  let upNorm    = camera.up.Norm();

  camera.right = rightNorm.Scale(1.5);
  camera.up    = upNorm.Scale(1.5);
  return camera;

method Normal(obj: Thing, pos: Vector): Vector {.base.} =
  case obj.objectType:
    of SPHERE:
      return pos.Sub(obj.center).Norm()
    of PLANE:
      return obj.center
  return Vector(x:0.0, y:0.0, z:0.0)

proc ObjectIntersect(obj: Thing, ray: Ray, result: Intersection): int =
  case obj.objectType:
    of SPHERE:
      let eo = VectorSub(&object->center, &ray->start)
      let v  = VectorDot(&eo, &ray->dir)
      let dist = 0;
      if (v >= 0):
          let disc = object->radius2 - (VectorDot(&eo, &eo) - (v * v))
          if (disc >= 0):
              dist = v - sqrt(disc)
      if (dist != 0):
          result.thing = object
          result.ray   = *ray
          result.dist  = dist
          return 1
    of PLANE:
      let denom = obj.center.Dot(ray.dir)
      if (denom <= 0):
        result.dist  = obj.norm.Dot(ray.start).Add(obj.offset) / (-denom)
        result.thing = obj
        result.ray   = ray
        return 1
  return 0

proc CreateSphere(center: Vector, radius: float, surface: Surface): Thing
  var sphere: Thing
  sphere.objectType = SPHERE
  sphere.radius2 = radius * radius
  sphere.center = center
  sphere.surface = surface
  return sphere

proc CreatePlane(norm: Vector, offset: float, surface: Surface): Thing
  var plane: Thing
  plane.objectType = PLANE;
  plane.surface = surface;
  plane.norm    = norm;
  plane.offset  = offset;
  return plane;

proc GetSurfaceProperties(surface: Surface, pos: Pos): SurfaceProperties
  var properties: SurfaceProperties
  case surface->type:
    of SHINY_SURFACE:
      properties->diffuse   = surface->diffuse;
      properties->specular  = surface->specular;
      properties->reflect   = surface->reflect;
      properties->roughness = surface->roughness;
    of CHECKERBOARD_SURFACE: {
      int val = (int)(floor(pos->z) + floor(pos->x));
      if (val % 2 != 0):
          properties->reflect   = 0.1;
          properties->diffuse   = white;
      else:
          properties->reflect   = 0.7;
          properties->diffuse   = black;
      properties->specular  = surface->specular;
      properties->roughness = surface->roughness;
  return properties

proc CreateSurface(SurfaceType type): Surface =
  Surface surface;
  surface.type = type;
  switch (type)
      case SHINY_SURFACE:
          surface.diffuse   = white;
          surface.specular  = grey;
          surface.reflect   = 0.7;
          surface.roughness = 250.0;
      case CHECKERBOARD_SURFACE:
          surface.diffuse   = black;
          surface.specular  = white;
          surface.reflect   = 0.7;
          surface.roughness = 150.0;
  return surface;

proc CreateScene(): Scene =
  Scene scene;
  scene.maxDepth   = 5;
  scene.thingCount = 3;
  scene.lightCount = 4;

  scene.things = (Thing*)(malloc(scene.thingCount * sizeof(Thing)));
  scene.lights = (Light*)(malloc(scene.lightCount * sizeof(Light)));

  scene.things[0] = CreatePlane(CreateVector(0.0, 1.0, 0.0), 0.0, &checkerboard);
  scene.things[1] = CreateSphere(CreateVector(0.0, 1.0, -0.25), 1.0, &shiny);
  scene.things[2] = CreateSphere(CreateVector(-1.0, 0.5, 1.5), 0.5, &shiny);

  scene.lights[0] = CreateLight(CreateVector(-2.0, 2.5, 0.0), CreateColor(0.49, 0.07, 0.07));
  scene.lights[1] = CreateLight(CreateVector(1.5, 2.5, 1.5),  CreateColor(0.07, 0.07, 0.49));
  scene.lights[2] = CreateLight(CreateVector(1.5, 2.5, -1.5), CreateColor(0.07, 0.49, 0.071));
  scene.lights[3] = CreateLight(CreateVector(0.0, 3.5, 0.0),  CreateColor(0.21, 0.21, 0.35));

  scene.camera = CreateCamera(CreateVector(3.0, 2.0, 4.0), CreateVector(-1.0, 0.5, 0.0));
  return scene;

# void ReleaseScene(Scene *scene)
# {
#     free((void *)scene->things);
#     free((void *)scene->lights);
# }

proc Intersections(Ray *ray, Scene *scene): Intersection
  double closest = INFINITY;
  Intersection closestInter;
  closestInter.thing = NULL;

  int thingCount = scene->thingCount;

  Thing *first = &scene->things[0];
  Thing *last  = &scene->things[thingCount-1];

  Intersection inter;

  for (Thing *thing = first; thing <= last; ++thing):
    int intersect = ObjectIntersect(thing, ray, &inter);
    if (intersect == 1  && inter.dist < closest)
      closestInter = inter;
      closest = inter.dist;
  return closestInter;

double TestRay(Ray *ray, Scene *scene)
{
    Intersection isect = Intersections(ray, scene);
    if (isect.thing != NULL)
    {
        return isect.dist;
    }
    return NAN;
}

Color TraceRay(Ray *ray, Scene *scene, int depth)
  Intersection isect = Intersections(ray, scene);
  if (isect.thing != NULL)
  {
      return Shade(&isect, scene, depth);
  }
  return background;

Color GetReflectionColor(Thing* thing, Vector *pos, Vector *normal, Vector *rd, Scene *scene, int depth)
  Ray ray = CreateRay(*pos, *rd);
  Color color = TraceRay(&ray, scene, depth + 1);

  SurfaceProperties properties;
  GetSurfaceProperties(thing->surface, pos, &properties);

  return ScaleColor(&color, properties.reflect);

Color GetNaturalColor(Thing* thing, Vector *pos, Vector *norm, Vector *rd, Scene *scene)
  Color resultColor = black;

  SurfaceProperties sp;
  GetSurfaceProperties(thing->surface, pos, &sp);

  int lightCount = scene->lightCount;

  Light *first = &scene->lights[0];
  Light *last  = &scene->lights[lightCount - 1];

  for (Light *light = first; light <= last; ++light)
    Vector ldis  = VectorSub(&light->pos, pos);
    Vector livec = VectorNorm(ldis);

    double ldisLen = VectorLength(&ldis);
    Ray ray = { *pos, livec };

    double neatIsect = TestRay(&ray, scene);

    int isInShadow = (neatIsect == NAN) ? 0 : (neatIsect <= ldisLen);
    if (!isInShadow)
      Vector rdNorm = VectorNorm(*rd);

      double illum   =  VectorDot(&livec, norm);
      double specular = VectorDot(&livec, &rdNorm);

      Color lcolor = (illum > 0) ?    ScaleColor(&light->color, illum) : defaultColor;
      Color scolor = (specular > 0) ? ScaleColor(&light->color, pow(specular, sp.roughness)) : defaultColor;

      ColorMultiplySelf(&lcolor, &sp.diffuse);
      ColorMultiplySelf(&scolor, &sp.specular);

      Color result = ColorAdd(&lcolor, &scolor);

      resultColor.r += result.r;
      resultColor.g += result.g;
      resultColor.b += result.b;
  return resultColor;

Color Shade(Intersection  *isect, Scene *scene, int depth)
    Vector d = isect->ray.dir;
    Vector scaled = VectorScale(&d, isect->dist);

    Vector pos = VectorAdd(&scaled, &isect->ray.start);
    Vector normal = ObjectNormal(isect->thing, &pos);
    double nodmalDotD = VectorDot(&normal, &d);
    Vector normalScaled = VectorScale(&normal, nodmalDotD * 2);

    Vector reflectDir = VectorSub(&d, &normalScaled);

    Color naturalColor = GetNaturalColor(isect->thing, &pos, &normal, &reflectDir, scene);
    naturalColor = ColorAdd(&background, &naturalColor);

    Color reflectedColor = (depth >= scene->maxDepth) ? grey : GetReflectionColor(isect->thing, &pos, &normal, &reflectDir, scene, depth);

    return ColorAdd(&naturalColor, &reflectedColor);

Vector GetPoint(int x, int y, Camera *camera, int screenWidth, int screenHeight)
  double recenterX = (x - (screenWidth / 2.0)) / 2.0 / screenWidth;
  double recenterY = -(y - (screenHeight / 2.0)) / 2.0 / screenHeight;

  Vector vx = VectorScale(&camera->right, recenterX);
  Vector vy = VectorScale(&camera->up, recenterY);

  Vector v = VectorAdd(&vx, &vy);
  Vector z = VectorAdd(&camera->forward, &v);

  z  = VectorNorm(z);
  return z;

void RenderScene(Scene *scene, byte* bitmapData, int stride, int w, int h)
  Ray ray;
  ray.start = scene->camera.pos;
  for (int y = 0; y < h; ++y)
  {
      RgbColor* pColor = (RgbColor*)(&bitmapData[y * stride]);
      for (int x = 0; x < w; ++x)
      {
          ray.dir = GetPoint(x, y, &scene->camera, h, w);
          Color color = TraceRay(&ray, scene, 0);
          *pColor = ToDrawingColor(&color);
          ++pColor;
      }
  }

void SaveRGBBitmap(byte* pBitmapBits, int lWidth, int lHeight, int wBitsPerPixel, const char* lpszFileName)
  BITMAPINFOHEADER bmpInfoHeader = {0};
  bmpInfoHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmpInfoHeader.biBitCount = wBitsPerPixel;
  bmpInfoHeader.biClrImportant = 0;
  bmpInfoHeader.biClrUsed = 0;
  bmpInfoHeader.biCompression = BI_RGB;
  bmpInfoHeader.biHeight = -lHeight;
  bmpInfoHeader.biWidth  = lWidth;
  bmpInfoHeader.biPlanes = 1;
  bmpInfoHeader.biSizeImage = lWidth* lHeight * (wBitsPerPixel/8);

  BITMAPFILEHEADER bfh = {0};
  bfh.bfType = 'B' + ('M' << 8);
  bfh.bfOffBits = sizeof(BITMAPINFOHEADER) + sizeof(BITMAPFILEHEADER);
  bfh.bfSize    = bfh.bfOffBits + bmpInfoHeader.biSizeImage;

  FILE *hFile;
  hFile = fopen(lpszFileName, "wb");
  fwrite(&bfh, sizeof(char), sizeof(bfh), hFile);
  fwrite(&bmpInfoHeader, sizeof(char), sizeof(bmpInfoHeader), hFile);
  fwrite(pBitmapBits, sizeof(char), bmpInfoHeader.biSizeImage, hFile);
  fclose(hFile);

let shiny        = CreateSurface(SHINY_SURFACE);
let checkerboard = CreateSurface(CHECKERBOARD_SURFACE);

printf("Started\n");
long t1 = GetTickCount();
Scene scene  = CreateScene();

int width  = 500;
int height = 500;
int stride = width * 4;

byte* bitmapData = (byte*)(malloc(stride * height));

RenderScene(&scene, &bitmapData[0], stride, width, height);

long t2 = GetTickCount();
long time = t2 - t1;

printf("Completed in %d ms\n", time);
SaveRGBBitmap(&bitmapData[0], width, height, 32, "cpp-raytracer.bmp");

ReleaseScene(&scene);
#free(bitmapData);