#define _CRT_SECURE_NO_DEPRECATE
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#ifdef _MSC_VER
#   ifndef INFINITY
#       define INFINITY (DBL_MAX+DBL_MAX)
#       define NAN (INFINITY-INFINITY)
#   endif
#endif

typedef unsigned char  UInt8;
typedef unsigned long  DWORD;
typedef unsigned short WORD;
typedef long LONG;

const int BI_RGB = 0;

typedef struct {
    DWORD biSize;
    LONG  biWidth;
    LONG  biHeight;
    WORD  biPlanes;
    WORD  biBitCount;
    DWORD biCompression;
    DWORD biSizeImage;
    LONG  biXPelsPerMeter;
    LONG  biYPelsPerMeter;
    DWORD biClrUsed;
    DWORD biClrImportant;
} BITMAPINFOHEADER;

typedef struct {
    WORD  bfType;
    DWORD bfSize;
    WORD  bfReserved1;
    WORD  bfReserved2;
    DWORD bfOffBits;
} BITMAPFILEHEADER;

typedef enum SurfaceType {
    SHINY_SURFACE,
    CHECKERBOARD_SURFACE
} SurfaceType;

typedef enum ObjectType {
    SPHERE,
    PLANE
} ObjectType;

typedef struct RgbColor {
    UInt8 b, g, r ,a;
} RgbColor;

typedef struct Vector{
    double x, y, z;
} Vector;

typedef struct Color {
    double r, b, g;
} Color;

typedef struct Camera {
    Vector forward, right, up, pos;
} Camera;

typedef struct Ray {
    Vector start, dir;
} Ray;

typedef struct Surface {
    SurfaceType type;
    Color  diffuse, specular;
    double reflect, roughness;
} Surface;

typedef struct Thing {
    ObjectType  type;
    Surface    *surface;
    union {
        double radius2; // For Sphere
        double offset;  // For Plane
    };
    union {
        Vector center;  // For Sphere
        Vector norm;    // For Plane
    };
} Thing;

typedef struct Intersection {
    Thing *thing;
    Ray    ray;
    double dist;
} Intersection;

typedef struct Light {
    Vector pos;
    Color color;
} Light;

typedef struct Scene {
    int    maxDepth;
    int    thingCount;
    int    lightCount;
    Thing* things;
    Light* lights;
    Camera camera;
} Scene;

typedef struct SurfaceProperties {
    Color diffuse, specular;
    double reflect, roughness;
} SurfaceProperties;

static Color white  = { 1.0, 1.0, 1.0 };
static Color grey   = { 0.5, 0.5, 0.5 };
static Color black  = { 0.0, 0.0, 0.0 };
static Color background   = { 0.0, 0.0, 0.0 };
static Color defaultColor = { 0.0, 0.0, 0.0 };

static Surface shiny;
static Surface checkerboard;

Color Shade(Intersection  *isect, Scene *scene, int depth);

Vector CreateVector(double x, double y, double z)
{
    Vector v;
    v.x = x;
    v.y = y;
    v.z = z;
    return v;
}

Vector VectorCross(Vector *v1, Vector *v2)
{
    return CreateVector(
        v1->y * v2->z - v1->z * v2->y,
        v1->z * v2->x - v1->x * v2->z,
        v1->x * v2->y - v1->y * v2->x
    );
}

double VectorLength(Vector *v)
{
    return sqrt(v->x * v->x + v->y * v->y + v->z * v->z);
}

Vector VectorScale(Vector *v, double k)
{
    return CreateVector(k * v->x, k * v->y, k * v->z);
}

Vector VectorNorm(Vector v)
{
    double mag = VectorLength(&v);
    double div = (mag == 0) ? INFINITY : 1.0 / mag;
    return VectorScale(&v, div);
}

double VectorDot(Vector *v1, Vector *v2)
{
    return (v1->x * v2->x) + 
           (v1->y * v2->y) + 
           (v1->z * v2->z);
}

Vector VectorAdd(Vector *v1, Vector *v2)
{
    return CreateVector(v1->x + v2->x,
                        v1->y + v2->y,
                        v1->z + v2->z);
}

Vector VectorSub(Vector *v1, Vector *v2)
{
    return CreateVector(v1->x - v2->x,
                        v1->y - v2->y,
                        v1->z - v2->z);
}

Color CreateColor(double r, double g, double b)
{
    Color color;
    color.r = r;
    color.g = g;
    color.b = b;
    return color;
}

Color ScaleColor(Color *color, double k)
{
    Color result;
    result.r = k * color->r;
    result.g = k * color->g;
    result.b = k * color->b;
    return result;
}

Color ColorMultiply(Color *v1, Color *v2)
{
    Color color;
    color.r = v1->r * v2->r;
    color.g = v1->g * v2->g;
    color.b = v1->b * v2->b;
    return color;
}

void ColorMultiplySelf(Color *v1, Color *v2)
{
    v1->r = v1->r * v2->r;
    v1->g = v1->g * v2->g;
    v1->b = v1->b * v2->b;
}

Color ColorAdd(Color *v1, Color *v2) {
    Color color;
    color.r = v1->r + v2->r;
    color.g = v1->g + v2->g;
    color.b = v1->b + v2->b;
    return color;
}

UInt8 Legalize(double c)
{
    UInt8 x = (UInt8)(c * 255);
    if (x < 0)   return 0;
    if (x > 255) return 255;
    return x;
}

RgbColor ToDrawingColor(Color *c)
{
    RgbColor color;
    color.r = (UInt8)Legalize(c->r);
    color.g = (UInt8)Legalize(c->g);
    color.b = (UInt8)Legalize(c->b);
    color.a = 255;
    return color;
}

Camera CreateCamera(Vector pos, Vector lookAt)
{
    Camera camera;
    camera.pos            = pos;
    Vector down    = CreateVector(0.0, -1.0, 0.0);
    Vector forward = VectorSub(&lookAt, &pos);

    camera.forward  = VectorNorm(forward);
    camera.right    = VectorCross(&camera.forward, &down);
    camera.up       = VectorCross(&camera.forward, &camera.right);

    Vector rightNorm = VectorNorm(camera.right);
    Vector upNorm = VectorNorm(camera.up);

    camera.right = VectorScale(&rightNorm, 1.5);
    camera.up = VectorScale(&upNorm, 1.5);
    return camera;
}

Ray CreateRay(Vector start, Vector dir)
{
    Ray ray;
    ray.start = start;
    ray.dir   = dir;
    return ray;
}

Intersection CreateIntersection(Thing* thing, Ray ray, double dist)
{
    Intersection isect;
    isect.thing = thing;
    isect.ray   = ray;
    isect.dist  = dist;
    return isect;
}

Light CreateLight(Vector pos, Color color)
{
    Light light;
    light.pos = pos;
    light.color = color;
    return light;
}

Vector ObjectNormal(Thing *object, Vector *pos)
{
    Vector result;
    switch(object->type)
    {
        case SPHERE: {
            result = VectorNorm(VectorSub(pos, &object->center));
        } break;
        case PLANE: {
            result = object->norm;
        } break;
    }
    return result;
}

int ObjectIntersect(Thing *object, Ray *ray, Intersection *result)
{
    switch(object->type)
    {
        case SPHERE: {
            Vector eo = VectorSub(&object->center, &ray->start);
            double v    = VectorDot(&eo, &ray->dir);
            double dist = 0;

            if (v >= 0) {
                double disc = object->radius2 - (VectorDot(&eo, &eo) - (v * v));
                if (disc >= 0) {
                    dist = v - sqrt(disc);
                }
            }
            if (dist != 0) {
                result->thing = object;
                result->ray   = *ray;
                result->dist  = dist;
                return 1;
            }
        } break;
        case PLANE: {
            double denom = VectorDot(&object->norm, &ray->dir);
            if (denom <= 0) {
                result->dist = (VectorDot(&object->norm, &ray->start) + object->offset) / (-denom);
                result->thing = object;
                result->ray = *ray;
                return 1;
            }
        } break;
    }
    return 0;
}

Thing CreateSphere(Vector center, double radius, Surface *surface)
{
    Thing sphere;
    sphere.type    = SPHERE;
    sphere.radius2 = radius * radius;
    sphere.center  = center;
    sphere.surface = surface;
    return sphere;
}

Thing CreatePlane(Vector norm, double offset, Surface *surface)
{
    Thing plane;
    plane.type = PLANE;
    plane.surface = surface;
    plane.norm    = norm;
    plane.offset  = offset;
    return plane;
}

void GetSurfaceProperties(Surface *surface, Vector *pos, SurfaceProperties *properties)
{
    switch(surface->type)
    {
        case SHINY_SURFACE: {
            properties->diffuse   = surface->diffuse;
            properties->specular  = surface->specular;
            properties->reflect   = surface->reflect;
            properties->roughness = surface->roughness;
        } break;
        case CHECKERBOARD_SURFACE: {
            int val = (int)(floor(pos->z) + floor(pos->x));
            if (val % 2 != 0) {
                properties->reflect   = 0.1;
                properties->diffuse   = white;
            } else {
                properties->reflect   = 0.7;
                properties->diffuse   = black;
            }
            properties->specular  = surface->specular;
            properties->roughness = surface->roughness;
        } break;
    }
}

Surface CreateSurface(SurfaceType type)
{
    Surface surface;
    surface.type = type;
    switch (type) {
        case SHINY_SURFACE: {
            surface.diffuse   = white;
            surface.specular  = grey;
            surface.reflect   = 0.7;
            surface.roughness = 250.0;
        } break;
        case CHECKERBOARD_SURFACE: {
            surface.diffuse   = black;
            surface.specular  = white;
            surface.reflect   = 0.7;
            surface.roughness = 150.0;
        } break;
    }
    return surface;
}

Scene CreateScene()
{
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
}

void ReleaseScene(Scene *scene)
{
    free((void *)scene->things);
    free((void *)scene->lights);
}

Intersection Intersections(Ray *ray, Scene *scene)
{
    double closest = INFINITY;
    Intersection closestInter;
    closestInter.thing = NULL;

    int thingCount = scene->thingCount;

    Thing *first = &scene->things[0];
    Thing *last  = &scene->things[thingCount-1];

    Intersection inter;

    for (Thing *thing = first; thing <= last; ++thing)
    {
        int intersect = ObjectIntersect(thing, ray, &inter);
        if (intersect == 1  && inter.dist < closest)
        {
            closestInter = inter;
            closest = inter.dist;
        }
    }
    return closestInter;
}

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
{
    Intersection isect = Intersections(ray, scene);
    if (isect.thing != NULL)
    {
        return Shade(&isect, scene, depth);
    }
    return background;
}

Color GetReflectionColor(Thing* thing, Vector *pos, Vector *normal, Vector *rd, Scene *scene, int depth)
{
    Ray ray = CreateRay(*pos, *rd);
    Color color = TraceRay(&ray, scene, depth + 1);

    SurfaceProperties properties;
    GetSurfaceProperties(thing->surface, pos, &properties);

    return ScaleColor(&color, properties.reflect);
}

Color GetNaturalColor(Thing* thing, Vector *pos, Vector *norm, Vector *rd, Scene *scene)
{
    Color resultColor = black;

    SurfaceProperties sp;
    GetSurfaceProperties(thing->surface, pos, &sp);

    int lightCount = scene->lightCount;

    Light *first = &scene->lights[0];
    Light *last  = &scene->lights[lightCount - 1];

    for (Light *light = first; light <= last; ++light)
    {
        Vector ldis  = VectorSub(&light->pos, pos);
        Vector livec = VectorNorm(ldis);

        double ldisLen = VectorLength(&ldis);
        Ray ray = { *pos, livec };

        double neatIsect = TestRay(&ray, scene);

        int isInShadow = (neatIsect == NAN) ? 0 : (neatIsect <= ldisLen);
        if (!isInShadow) {
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
        }
    }
    return resultColor;
}

Color Shade(Intersection  *isect, Scene *scene, int depth)
{
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
}

Vector GetPoint(int x, int y, Camera *camera, int screenWidth, int screenHeight)
{
    double recenterX = (x - (screenWidth / 2.0)) / 2.0 / screenWidth;
    double recenterY = -(y - (screenHeight / 2.0)) / 2.0 / screenHeight;

    Vector vx = VectorScale(&camera->right, recenterX);
    Vector vy = VectorScale(&camera->up, recenterY);

    Vector v = VectorAdd(&vx, &vy);
    Vector z = VectorAdd(&camera->forward, &v);

    z  = VectorNorm(z);
    return z;
}

void RenderScene(Scene *scene, UInt8* bitmapData, int stride, int w, int h)
{
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
}

void SaveRGBBitmap(UInt8* bitmapBits, int width, int height, int bitsPerPixel, const char* fileName)
{
    BITMAPINFOHEADER bmpInfoHeader = {0};
    bmpInfoHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmpInfoHeader.biBitCount = bitsPerPixel;
    bmpInfoHeader.biClrImportant = 0;
    bmpInfoHeader.biClrUsed = 0;
    bmpInfoHeader.biCompression = BI_RGB;
    bmpInfoHeader.biHeight = -height;
    bmpInfoHeader.biWidth  = width;
    bmpInfoHeader.biPlanes = 1;
    bmpInfoHeader.biSizeImage = width* height * (bitsPerPixel/8);

    BITMAPFILEHEADER bfh = {0};
    bfh.bfType = 'B' + ('M' << 8);
    bfh.bfOffBits = sizeof(BITMAPINFOHEADER) + sizeof(BITMAPFILEHEADER);
    bfh.bfSize    = bfh.bfOffBits + bmpInfoHeader.biSizeImage;

    FILE *hFile;
    hFile = fopen(fileName, "wb");
    fwrite(&bfh, sizeof(char), sizeof(bfh), hFile);
    fwrite(&bmpInfoHeader, sizeof(char), sizeof(bmpInfoHeader), hFile);
    fwrite(bitmapBits, sizeof(char), bmpInfoHeader.biSizeImage, hFile);
    fclose(hFile);
}

int main()
{
    shiny        = CreateSurface(SHINY_SURFACE);
    checkerboard = CreateSurface(CHECKERBOARD_SURFACE);

    printf("Started\n");
    clock_t t1 = clock();
    Scene scene  = CreateScene();

    int width  = 500;
    int height = 500;
    int stride = width * 4;

    UInt8* bitmapData = (UInt8*)(malloc(stride * height));

    RenderScene(&scene, &bitmapData[0], stride, width, height);

    clock_t t2   = clock();
    clock_t time = t2 - t1;
    int time_ms = (int)((((double)time) / CLOCKS_PER_SEC) * 1000);

    printf("Completed in %d ms\n", time_ms);
    SaveRGBBitmap(&bitmapData[0], width, height, 32, "c-raytracer.bmp");

    ReleaseScene(&scene);
    free(bitmapData);
    //system("pause");

    return 0;
};