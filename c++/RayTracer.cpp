#include <windows.h>
#include <math.h>
#include <vector>
#include <iostream>
#include <memory>
#include <fstream>
#include <chrono>

#ifdef _MSC_VER
#ifndef INFINITY
#define INFINITY (DBL_MAX+DBL_MAX)
#define NAN (INFINITY-INFINITY)
#endif
#endif

struct RgbColor
{
    byte b;
    byte g;
    byte r;
    byte a;
};

struct Vector
{
    double x;
    double y;
    double z;

    Vector() : x(0), y(0), z(0) {}

    Vector(double x, double y, double z) : x(x), y(y), z(z)
    {
    }

    double mag() const
    {
        return sqrt(this->x * this->x + this->y * this->y + this->z * this->z);
    }

    Vector norm() const
    {
        double mag = this->mag();
        double div = (mag == 0) ? INFINITY : 1.0 / mag;
        return this->scale(div);
    }

    Vector cross(const Vector &v2) const
    {
        return Vector(this->y * v2.z - this->z * v2.y,
            this->z * v2.x - this->x * v2.z,
            this->x * v2.y - this->y * v2.x);
    }

    Vector scale(double k) const
    {
        return Vector(k * this->x, k * this->y, k * this->z);
    }

    Vector operator*(double k) const
    {
        return this->scale(k);
    }

    double operator*(const Vector& v2) const
    {
        return this->x * v2.x + this->y * v2.y + this->z * v2.z;
    }

    Vector operator+(const Vector& v2) const
    {
        return Vector(this->x + v2.x, this->y + v2.y, this->z + v2.z);
    }

    Vector operator-(const Vector& v2) const
    {
        return Vector(this->x - v2.x, this->y - v2.y, this->z - v2.z);
    }
};

struct Color
{
    double r;
    double g;
    double b;

    static Color white;
    static Color grey;
    static Color black;
    static Color background;
    static Color defaultColor;

    Color() : r(0), g(0), b(0) {}

    Color(double r, double g, double b)
    {
        this->r = r;
        this->g = g;
        this->b = b;
    }

    Color scale(double k) const
    {
        return Color(k * this->r, k * this->g, k * this->b);
    }

    static Color times(const Color &v1, const Color &v2)
    {
        return Color(v1.r * v2.r, v1.g * v2.g, v1.b * v2.b);
    }

    Color operator*(double k) const
    {
        return this->scale(k);
    }

    Color operator*(const Color& v2) const
    {
        return Color(this->r * v2.r, this->g * v2.g, this->b * v2.b);
    }

    Color operator+(const Color& v2)
    {
        return Color(this->r + v2.r, this->g + v2.g, this->b + v2.b);
    }

    RgbColor toDrawingColor()
    {
        RgbColor color;
        color.r = (byte)legalize(this->r);
        color.g = (byte)legalize(this->g);
        color.b = (byte)legalize(this->b);
        color.a = 255;
        return color;
    }

    static int legalize(double c)
    {
        int x = (int)(c * 255);
        if (x < 0)   x = 0;
        if (x > 255) x = 255;
        return x;
    }
};

Color Color::white = Color(1.0, 1.0, 1.0);
Color Color::grey = Color(0.5, 0.5, 0.5);
Color Color::black = Color(0.0, 0.0, 0.0);
Color Color::background = Color::black;
Color Color::defaultColor = Color::black;

struct Camera
{
    Vector forward;
    Vector right;
    Vector up;
    Vector pos;

    Camera() {}

    Camera(Vector pos, Vector lookAt)
    {
        this->pos = pos;
        Vector down = Vector(0.0, -1.0, 0.0);
        Vector forward = lookAt - pos;
        this->forward = forward.norm();
        this->right = this->forward.cross(down).norm() * 1.5;
        this->up = this->forward.cross(this->right).norm() * 1.5;
    }
};

struct Ray
{
    Vector start;
    Vector dir;

    Ray() {}

    Ray(Vector start, Vector dir)
    {
        this->start = start;
        this->dir = dir;
    }
};

class Thing;

class Intersection
{
private:
    bool m_IsValid = false;
public:
    const Thing* thing;
    Ray ray;
    double dist;

    Intersection()
    {
        m_IsValid = false;
    }

    Intersection(const Thing* thing, Ray ray, double dist)
    {
        this->thing = thing;
        this->ray = ray;
        this->dist = dist;
        this->m_IsValid = true;
    }

    bool IsValid() {
        return m_IsValid;
    }
};

class Surface
{
public:
    virtual Color  diffuse(const Vector& pos) const { return Color::black; };
    virtual Color  specular(const Vector& pos) const { return Color::black; };
    virtual double reflect(const Vector& pos) const { return 0; };
    virtual double roughness() const { return 0; };
};

class Thing
{
public:
    virtual Intersection intersect(const Ray& ray) const = 0;
    virtual Vector normal(const Vector& pos) const = 0;
    virtual Surface& surface() const = 0;
};

struct Light
{
    Vector pos;
    Color color;

    Light(Vector pos, Color color)
    {
        this->pos = pos;
        this->color = color;
    }
};

class Sphere : public Thing
{
private:
    Surface& m_surface;
    double   m_radius2;
    Vector   m_center;
public:
    Sphere(Vector center, double radius, Surface& surface) : m_surface{ surface }
    {
        this->m_radius2 = radius * radius;
        this->m_center = center;
    }

    Vector normal(const Vector& pos) const override
    {
        return (pos - this->m_center).norm();
    }

    Intersection intersect(const Ray& ray) const override
    {
        Vector eo = this->m_center - ray.start;
        double v = eo * ray.dir;
        double dist = 0;

        if (v >= 0) {
            double disc = this->m_radius2 - ((eo * eo) - (v * v));
            if (disc >= 0) {
                dist = v - sqrt(disc);
            }
        }
        if (dist == 0) {
            return Intersection();
        }
        return Intersection(this, ray, dist);
    }

    Surface& surface() const override
    {
        return m_surface;
    }
};

class Plane : public Thing
{
private:
    Vector norm;
    double offset;
    Surface& m_surface;
public:

    Plane(Vector norm, double offset, Surface& surface) : m_surface{ surface }
    {
        this->norm = norm;
        this->offset = offset;
    }

    Vector normal(const Vector& pos) const override
    {
        return this->norm;
    }

    Intersection intersect(const Ray& ray) const override
    {
        double denom = norm * ray.dir;
        if (denom > 0) {
            return Intersection();
        }
        double dist = ((norm * ray.start) + offset) / (-denom);
        return Intersection(this, ray, dist);
    }

    Surface& surface() const override
    {
        return m_surface;
    }
};

class ShinySurface : public Surface
{
public:
    Color diffuse(const Vector& pos) const
    {
        return Color::white;
    }

    Color specular(const Vector& pos) const
    {
        return Color::grey;
    }

    double reflect(const Vector& pos) const
    {
        return 0.7;
    }

    double roughness() const
    {
        return 250.0;
    }
};

class CheckerboardSurface : public Surface
{
public:
    Color diffuse(const Vector& pos) const
    {
        if (((int)(floor(pos.z) + floor(pos.x))) % 2 != 0)
        {
            return Color::white;
        }
        return Color::black;
    }

    Color specular(const Vector& pos) const
    {
        return Color::white;
    }

    double reflect(const Vector& pos) const
    {
        if (((int)(floor(pos.z) + floor(pos.x))) % 2 != 0)
        {
            return 0.1;
        }
        return 0.7;
    }

    double roughness() const
    {
        return 150.0;
    }
};

using ThingList = std::vector<std::unique_ptr<Thing>>;
using LightList = std::vector<Light>;

class Scene
{
public:
    virtual ThingList const& things() const = 0;
    virtual LightList const& lights() const = 0;
    virtual Camera const& camera() const = 0;
};

class DefaultScene : public  Scene
{
private:
    ThingList m_things;
    LightList m_lights;
    Camera    m_camera;

    ShinySurface        shiny;
    CheckerboardSurface checkerboard;

public:
    DefaultScene()
    {
        m_things.push_back(std::make_unique<Plane>(Vector(0.0, 1.0, 0.0), 0.0, checkerboard));
        m_things.push_back(std::make_unique<Sphere>(Vector(0.0, 1.0, -0.25), 1.0, shiny));
        m_things.push_back(std::make_unique<Sphere>(Vector(-1.0, 0.5, 1.5), 0.5, shiny));

        m_lights.push_back(Light(Vector(-2.0, 2.5, 0.0), Color(0.49, 0.07, 0.07)));
        m_lights.push_back(Light(Vector(1.5, 2.5, 1.5), Color(0.07, 0.07, 0.49)));
        m_lights.push_back(Light(Vector(1.5, 2.5, -1.5), Color(0.07, 0.49, 0.071)));
        m_lights.push_back(Light(Vector(0.0, 3.5, 0.0), Color(0.21, 0.21, 0.35)));

        this->m_camera = Camera(Vector(3.0, 2.0, 4.0), Vector(-1.0, 0.5, 0.0));
    }

    ThingList const& things() const override
    {
        return m_things;
    }

    LightList const& lights() const override
    {
        return m_lights;
    }

    Camera const& camera() const override
    {
        return m_camera;
    }
};

class RayTracerEngine
{
private:
    static const int maxDepth = 5;
    Scene &scene;

    Intersection intersections(const Ray& ray)
    {
        double closest = INFINITY;
        Intersection closestInter;

        auto& things = scene.things();

        for (auto& thing : things)
        {
            auto inter = thing->intersect(ray);
            if (inter.IsValid() && inter.dist < closest)
            {
                closestInter = inter;
                closest = inter.dist;
            }
        }
        return closestInter;
    }

    double testRay(const Ray& ray)
    {
        auto isect = this->intersections(ray);
        if (isect.IsValid())
        {
            return isect.dist;
        }
        return NAN;
    }

    Color traceRay(const Ray& ray, int depth)
    {
        auto isect = this->intersections(ray);
        if (isect.IsValid())
        {
            return this->shade(isect, depth);
        }
        return Color::background;
    }

    Color shade(const Intersection& isect, int depth)
    {
        Vector d = isect.ray.dir;
        Vector pos = (d * isect.dist) + isect.ray.start;
        Vector normal = isect.thing->normal(pos);
        Vector reflectDir = d - ((normal * (normal * d)) * 2);

        Color naturalColor = Color::background + this->getNaturalColor(isect.thing, pos, normal, reflectDir);
        Color reflectedColor = (depth >= this->maxDepth)
            ? Color::grey
            : this->getReflectionColor(isect.thing, pos, normal, reflectDir, depth);

        return naturalColor + reflectedColor;
    }

    Color getReflectionColor(const Thing* thing, const Vector& pos, const Vector& normal, const Vector& rd, int depth)
    {
        Ray    ray(pos, rd);
        Color  color = this->traceRay(ray, depth + 1);
        double factor = thing->surface().reflect(pos);
        return color.scale(factor);
    }

    Color getNaturalColor(const Thing* thing, const Vector& pos, const Vector& norm, const Vector& rd)
    {
        Color result = Color::black;
        auto& items = scene.lights();

        for (auto& item : items)
        {
            addLight(result, item, pos, thing, rd, norm);
        }
        return result;
    }

    void addLight(Color& resultColor, const Light& light, const Vector& pos, const Thing* thing, const Vector& rd, const Vector& norm)
    {
        Vector ldis = light.pos - pos;
        Vector livec = ldis.norm();
        Ray ray{ pos, livec };

        double neatIsect = this->testRay(ray);

        bool isInShadow = (neatIsect == NAN) ? false : (neatIsect <= ldis.mag());
        if (isInShadow) {
            return;
        }
        double illum    = livec * norm;
        double specular = livec * rd.norm();

        auto& surface = thing->surface();

        Color lcolor = (illum > 0) ? (light.color * illum) : Color::defaultColor;
        Color scolor = (specular > 0) ? (light.color * pow(specular, surface.roughness())) : Color::defaultColor;
        resultColor = resultColor + lcolor * surface.diffuse(pos) + scolor * surface.specular(pos);
    }

    Vector getPoint(int x, int y, const Camera& camera, int screenWidth, int screenHeight)
    {
        double recenterX = (x - (screenWidth / 2.0)) / 2.0 / screenWidth;
        double recenterY = -(y - (screenHeight / 2.0)) / 2.0 / screenHeight;
        return (camera.forward + ((camera.right * recenterX) + (camera.up * recenterY))).norm();
    }

public:

    RayTracerEngine(Scene &scene) : scene{ scene } {}

    void render(byte* bitmapData, int stride, int w, int h)
    {
        Ray ray;
        ray.start = scene.camera().pos;
        auto& camera = scene.camera();

        for (int y = 0; y < h; ++y)
        {
            RgbColor* pColor = (RgbColor*)(&bitmapData[y * stride]);
            for (int x = 0; x < w; ++x)
            {
                ray.dir = this->getPoint(x, y, camera, h, w);
                *pColor = this->traceRay(ray, 0).toDrawingColor();
                pColor++;
            }
        }
    }
};

void SaveRGBBitmap(byte* pBitmapBits, LONG lWidth, LONG lHeight, WORD wBitsPerPixel, LPCSTR lpszFileName)
{
    BITMAPINFOHEADER bmpInfoHeader = { 0 };
    bmpInfoHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmpInfoHeader.biBitCount = wBitsPerPixel;
    bmpInfoHeader.biClrImportant = 0;
    bmpInfoHeader.biClrUsed = 0;
    bmpInfoHeader.biCompression = BI_RGB;
    bmpInfoHeader.biHeight = -lHeight;
    bmpInfoHeader.biWidth = lWidth;
    bmpInfoHeader.biPlanes = 1;
    bmpInfoHeader.biSizeImage = lWidth* lHeight * (wBitsPerPixel / 8);

    BITMAPFILEHEADER bfh = { 0 };
    bfh.bfType = 'B' + ('M' << 8);
    bfh.bfOffBits = sizeof(BITMAPINFOHEADER) + sizeof(BITMAPFILEHEADER);
    bfh.bfSize = bfh.bfOffBits + bmpInfoHeader.biSizeImage;

    std::ofstream file(lpszFileName, std::ios::binary | std::ios::trunc);
    file.write((const char*)&bfh, sizeof(bfh));
    file.write((const char*)&bmpInfoHeader, sizeof(bmpInfoHeader));
    file.write((const char*)pBitmapBits, bmpInfoHeader.biSizeImage);
    file.close();
}

int main()
{
    std::cout << "Started " << std::endl;
    auto t1 = std::chrono::high_resolution_clock::now();

    DefaultScene    scene;
    RayTracerEngine rayTracer(scene);

    int width = 500;
    int height = 500;
    int stride = width * 4;

    std::vector<byte> bitmapData(stride * height);

    rayTracer.render(&bitmapData[0], stride, width, height);

    auto t2 = std::chrono::high_resolution_clock::now();
    auto diff = std::chrono::duration_cast<std::chrono::milliseconds>((t2 - t1));

    std::cout << "Completed in " << diff.count() << " ms" << std::endl;
    SaveRGBBitmap(&bitmapData[0], width, height, 32, "cpp-raytracer.bmp");

    return 0;
};