#define _CRT_SECURE_NO_DEPRECATE
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>
#if __EMSCRIPTEN__
#include <emscripten.h>
#endif

const double FarAway = 1000000.0;

typedef uint8_t  UInt8;
typedef uint32_t DWORD;
typedef uint16_t WORD;
typedef int32_t  LONG;

const int BI_RGB = 0;

#pragma pack(push, 1)
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
#pragma pack(pop)

#pragma pack(push, 1)
typedef struct {
    WORD  bfType;
    DWORD bfSize;
    WORD  bfReserved1;
    WORD  bfReserved2;
    DWORD bfOffBits;
} BITMAPFILEHEADER;
#pragma pack(pop)

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
    double b, g, r;
} Color;

typedef struct Camera {
    Vector forward, right, up, pos;
} Camera;

typedef struct Ray {
    Vector start, dir;
} Ray;

typedef struct Thing {
    ObjectType  type;
    SurfaceType surface;
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

Color Shade(Intersection  *isect, Scene *scene, int depth);

Vector CreateVector(double x, double y, double z)
{
    Vector result;
    result.x = x;
    result.y = y;
    result.z = z;
    return result;
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
    double div = (mag == 0) ? FarAway : 1.0 / mag;
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
    Color result;
    result.b = b;
    result.g = g;
    result.r = r;
    return result;
}

Color ScaleColor(Color *color, double k)
{
    return CreateColor(k * color->r, k * color->g, k * color->b);
}

Color ColorMultiply(Color *v1, Color *v2)
{
    return CreateColor(
        v1->r * v2->r,
        v1->g * v2->g,
        v1->b * v2->b
    );
}

void ColorMultiplySelf(Color *v1, Color *v2)
{
    v1->r = v1->r * v2->r;
    v1->g = v1->g * v2->g;
    v1->b = v1->b * v2->b;
}

Color ColorAdd(Color *v1, Color *v2) {
    return CreateColor(
        v1->r + v2->r,
        v1->g + v2->g,
        v1->b + v2->b
    );
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
    RgbColor result;
    result.b = Legalize(c->b),
    result.g = Legalize(c->g),
    result.r = Legalize(c->r),
    result.a = 255;
    return result;
};

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
    ray.dir = dir;
    return ray;
}

Intersection CreateIntersection(Thing* thing, Ray ray, double dist)
{
    Intersection result;
    result.thing = thing;
    result.ray = ray;
    result.dist = dist;
    return result;
}

Light CreateLight(Vector pos, Color color)
{
    Light result;
    result.pos = pos;
    result.color = color;
    return result;
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
            double v  = VectorDot(&eo, &ray->dir);
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

Thing CreateSphere(Vector center, double radius, SurfaceType surface)
{
    Thing result;
    result.type    = SPHERE,
    result.surface = surface,
    result.radius2 = radius * radius,
    result.center  = center;
    return result;
}

Thing CreatePlane(Vector norm, double offset, SurfaceType surface)
{
    Thing result;
    result.type    = PLANE,
    result.surface = surface,
    result.offset  = offset,
    result.norm    = norm;
    return result;
}

void GetSurfaceProperties(SurfaceType surface, Vector *pos, SurfaceProperties *properties)
{
    switch(surface)
    {
        case SHINY_SURFACE: {
            properties->diffuse   = white;
            properties->specular  = grey;
            properties->reflect   = 0.7;
            properties->roughness = 250.0;
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
            properties->specular  = white;
            properties->roughness = 150.0;
        } break;
    }
}

Scene CreateScene()
{
    Scene scene;
    scene.maxDepth   = 5;
    scene.thingCount = 3;
    scene.lightCount = 4;

    scene.things = (Thing*)(malloc(scene.thingCount * sizeof(Thing)));
    scene.lights = (Light*)(malloc(scene.lightCount * sizeof(Light)));

    scene.things[0] = CreatePlane(CreateVector(0.0, 1.0, 0.0), 0.0, CHECKERBOARD_SURFACE);
    scene.things[1] = CreateSphere(CreateVector(0.0, 1.0, -0.25), 1.0, SHINY_SURFACE);
    scene.things[2] = CreateSphere(CreateVector(-1.0, 0.5, 1.5), 0.5, SHINY_SURFACE);

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
    double closest = FarAway;
    Intersection closestInter;
    closestInter.thing = NULL;

    Intersection inter;

    for (int i = 0; i < scene->thingCount; i++)
    {
        Thing * thing = &scene->things[i];
        int intersect = ObjectIntersect(thing, ray, &inter);
        if (intersect == 1  && inter.dist < closest)
        {
            closestInter = inter;
            closest = inter.dist;
        }
    }
    return closestInter;
}

Color TraceRay(Ray *ray, Scene *scene, int depth)
{
    Intersection isect = Intersections(ray, scene);
    return (isect.thing != NULL) ? Shade(&isect, scene, depth) : background;
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

    for (int i = 0; i < scene->lightCount; i++)
    {
        Light  *light = &scene->lights[i];
        Vector ldis  = VectorSub(&light->pos, pos);
        Vector livec = VectorNorm(ldis);

        double ldisLen = VectorLength(&ldis);
        Ray ray = { *pos, livec };

        Intersection neatIsect = Intersections(&ray, scene);

        int isInShadow = (neatIsect.thing != NULL) && (neatIsect.dist <= ldisLen);
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

    // printf("Size is: %d\n", (int)bfh.bfOffBits);
    // printf("Size of LONG: %d\n", (int)sizeof(LONG) );

    FILE *hFile;
    hFile = fopen(fileName, "wb");

    fwrite(&bfh, sizeof(char), sizeof(BITMAPFILEHEADER), hFile);
    fwrite(&bmpInfoHeader, sizeof(char), sizeof(BITMAPINFOHEADER), hFile);
    fseek(hFile, bfh.bfOffBits, SEEK_SET);
    fwrite(bitmapBits, sizeof(char), bmpInfoHeader.biSizeImage, hFile);
    fclose(hFile);
}

int main()
{
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
#if __EMSCRIPTEN__
    EM_ASM(
        const stream = FS.open("c-raytracer.bmp", "r");
        const blob = new Blob([stream.node.contents], { type: "image/bmp" });
        const a = document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = "webassembly-raytracer.bmp";
        a.click();
        URL.revokeObjectURL(a.href);
        a.remove();
    );
#endif

    ReleaseScene(&scene);
    free(bitmapData);

    return 0;
};