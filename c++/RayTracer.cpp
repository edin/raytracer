#include <cmath>
#include <vector>
#include <iostream>
#include <memory>
#include <fstream>
#include <chrono>
#include <optional>

const double FarAway = 1000000.0;
using UInt8 = unsigned char;

struct RgbColor
{
    UInt8 b, g, r, a;
};

struct Vector
{
    double x, y, z;

    Vector() : x(0), y(0), z(0) {}

    Vector(double x, double y, double z) : x(x), y(y), z(z) { }

    double Length() const
    {
        return sqrt(x * x + y * y + z * z);
    }

    Vector Norm() const
    {
        double mag = Length();
        double div = (mag == 0) ? FarAway : 1.0 / mag;
        return *this * div;
    }

    Vector Cross(const Vector& v) const
    {
        return Vector(
            y * v.z - z * v.y,
            z * v.x - x * v.z,
            x * v.y - y * v.x
        );
    }

    Vector operator*(double k) const
    {
        return Vector(k * x, k * y, k * z);
    }

    double operator*(const Vector& v) const
    {
        return x * v.x + y * v.y + z * v.z;
    }

    Vector operator+(const Vector& v) const
    {
        return Vector(x + v.x, y + v.y, z + v.z);
    }

    Vector operator-(const Vector& v) const
    {
        return Vector(x - v.x, y - v.y, z - v.z);
    }
};

struct Color
{
    double r, g, b;

    static Color White;
    static Color Grey;
    static Color Black;
    static Color Background;
    static Color DefaultColor;

    Color() : r(0.0), g(0.0), b(0.0) {}

    Color(double r, double g, double b) : r(r), g(g), b(b) { }

    Color Scale(double k) const
    {
        return Color(k * r, k * g, k * b);
    }

    Color operator * (const Color& c) const
    {
        return Color(r * c.r, g * c.g, b * c.b);
    }

    Color operator + (const Color& c) const
    {
        return Color(r + c.r, g + c.g, b + c.b);
    }

    RgbColor ToDrawingColor() const
    {
        return RgbColor{ Clamp(b), Clamp(g), Clamp(r), 255 };
    }

    static UInt8 Clamp(double c)
    {
        int x = (int)(c * 255);
        if (x < 0)   x = 0;
        if (x > 255) x = 255;
        return (UInt8)x;
    }
};

Color Color::White = Color(1.0, 1.0, 1.0);
Color Color::Grey = Color(0.5, 0.5, 0.5);
Color Color::Black = Color(0.0, 0.0, 0.0);
Color Color::Background = Color::Black;
Color Color::DefaultColor = Color::Black;

struct Camera
{
    Vector forward;
    Vector right;
    Vector up;
    Vector pos;

    Camera() {}
    Camera(Vector pos, Vector lookAt)
    {
        Vector Down = Vector(0.0, -1.0, 0.0);
        Vector Forward = lookAt - pos;
        this->pos = pos;
        this->forward = Forward.Norm();
        this->right = this->forward.Cross(Down).Norm() * 1.5;
        this->up = this->forward.Cross(this->right).Norm() * 1.5;
    }

    Vector GetPoint(int x, int y, int screenWidth, int screenHeight) const
    {
        double recenterX = (x - (screenWidth / 2.0)) / 2.0 / screenWidth;
        double recenterY = -(y - (screenHeight / 2.0)) / 2.0 / screenHeight;
        return (this->forward + ((this->right * recenterX) + (this->up * recenterY))).Norm();
    }
};

struct Ray
{
    Vector start;
    Vector dir;

    Ray(Vector start, Vector dir) : start(start), dir(dir) { }
};

struct Thing;

struct Intersection
{
    const Thing* thing;
    Ray ray;
    double dist;

    Intersection(const Thing* thing, Ray ray, double dist) :
        thing(thing), ray(ray), dist(dist)
    {}
};

struct SurfacePropreties
{
    Color Diffuse;
    Color Specular;
    double Reflect = 0.0;
    double Roughness = 0.0;

    SurfacePropreties() {}
    SurfacePropreties(Color diffuse, Color specular, double reflect, double roughness) :
        Diffuse(diffuse), Specular(specular), Reflect(reflect), Roughness(roughness)
    {}
};

struct Surface
{
    virtual SurfacePropreties GetSurfaceProperties(const Vector& pos) const = 0;
};

struct Light
{
    Vector pos;
    Color color;
    Light(Vector pos, Color color) : pos(pos), color(color) { }
};

struct Thing
{
    virtual Vector GetNormal(const Vector& pos) const = 0;
    virtual std::optional<Intersection> GetIntersection(const Ray& ray) const = 0;
    virtual Surface& GetSurface() const = 0;
    virtual ~Thing() = default;
};

class Sphere : public Thing {
    Surface& surface;
    Vector   center;
    double   radius2;
public:
    Sphere(Vector center, double radius, Surface& surface) : surface(surface), center(center), radius2(radius* radius) {}

    Vector GetNormal(const Vector& pos) const override {
        return (pos - center).Norm();
    }

    std::optional<Intersection> GetIntersection(const Ray& ray) const override {
        Vector eo = center - ray.start;
        double v = eo * ray.dir;
        if (v >= 0.0) {
            double disc = radius2 - ((eo * eo) - (v * v));
            if (disc >= 0.0) {
                double dist = v - sqrt(disc);
                return Intersection(this, ray, dist);
            }
        }
        return std::nullopt;
    }

    Surface& GetSurface() const override { return surface; };
};

class Plane : public Thing {
    Surface& surface;
    Vector   normal;
    double   offset;
public:
    Plane(Vector normal, double offset, Surface& surface) : surface(surface), normal(normal), offset(offset) {}

    Vector GetNormal(const Vector& pos) const override {
        return normal;
    }

    std::optional<Intersection> GetIntersection(const Ray& ray) const override {
        double denom = normal * ray.dir;
        if (denom > 0.0) {
            return std::nullopt;
        }
        double dist = ((normal * ray.start) + offset) / (-denom);
        return Intersection(this, ray, dist);
    }

    Surface& GetSurface() const override { return surface; };
};

struct ShinySurface : public Surface
{
    SurfacePropreties GetSurfaceProperties(const Vector& pos) const override
    {
        return SurfacePropreties(Color::White, Color::Grey, 0.7, 250.0);
    }
};

struct CheckerboardSurface : public Surface
{
    SurfacePropreties GetSurfaceProperties(const Vector& pos) const override
    {
        Color diffuse = Color::Black;
        double reflect = 0.7;
        if (((int)(floor(pos.z) + floor(pos.x))) % 2 != 0)
        {
            diffuse = Color::White;
            reflect = 0.1;
        }
        return SurfacePropreties(diffuse, Color::White, reflect, 150.0);
    }
};

class Scene {
private:
    ShinySurface        shiny;
    CheckerboardSurface checkerboard;
public:
    std::vector<std::unique_ptr<Thing>> things;
    std::vector<Light> lights;
    Camera    camera;

    Scene()
    {
        things.push_back(std::make_unique<Plane>(Vector(0.0, 1.0, 0.0), 0.0, checkerboard));
        things.push_back(std::make_unique<Sphere>(Vector(0.0, 1.0, -0.25), 1.0, shiny));
        things.push_back(std::make_unique<Sphere>(Vector(-1.0, 0.5, 1.5), 0.5, shiny));

        lights.push_back(Light(Vector(-2.0, 2.5, 0.0), Color(0.49, 0.07, 0.07)));
        lights.push_back(Light(Vector(1.5, 2.5, 1.5), Color(0.07, 0.07, 0.49)));
        lights.push_back(Light(Vector(1.5, 2.5, -1.5), Color(0.07, 0.49, 0.071)));
        lights.push_back(Light(Vector(0.0, 3.5, 0.0), Color(0.21, 0.21, 0.35)));
        camera = Camera(Vector(3.0, 2.0, 4.0), Vector(-1.0, 0.5, 0.0));
    }
};

class RayTracerEngine
{
    static const int maxDepth = 5;
    Scene& scene;

    std::optional<Intersection> GetClosestIntersection(const Ray& ray)
    {
        double closest = FarAway;
        std::optional<Intersection> closestInter = std::nullopt;

        for (auto& thing : scene.things)
        {
            auto inter = thing->GetIntersection(ray);
            if (inter && inter->dist < closest) {
                closestInter = inter;
                closest = inter->dist;
            }
        }
        return closestInter;
    }

    Color TraceRay(const Ray& ray, int depth)
    {
        auto isect = GetClosestIntersection(ray);
        if (isect) {
            return Shade(*isect, depth);
        }
        return Color::Background;
    }

    Color Shade(const Intersection& isect, int depth)
    {
        Vector d = isect.ray.dir;
        Vector pos = (d * isect.dist) + isect.ray.start;
        Vector normal = isect.thing->GetNormal(pos);
        Vector reflectDir = (d - ((normal * (normal * d)) * 2)).Norm();

        SurfacePropreties surface = isect.thing->GetSurface().GetSurfaceProperties(pos);

        Color naturalColor = Color::Background + GetNaturalColor(surface, pos, normal, reflectDir);
        Color reflectedColor = (depth >= maxDepth) ? Color::Grey : GetReflectionColor(surface, pos, reflectDir, depth);

        return naturalColor + reflectedColor;
    }

    Color GetReflectionColor(const SurfacePropreties& surface, const Vector& pos, const Vector& reflectDir, int depth)
    {
        Ray    ray(pos, reflectDir);
        Color  color = TraceRay(ray, depth + 1);
        return color.Scale(surface.Reflect);
    }

    Color GetNaturalColor(const SurfacePropreties& surface, const Vector& pos, const Vector& norm, const Vector& reflectDir)
    {
        Color result = Color::Black;
        for (auto& light : scene.lights)
        {
            Vector ldis = light.pos - pos;
            Vector livec = ldis.Norm();
            Ray ray{ pos, livec };

            auto neatIsect = GetClosestIntersection(ray);
            bool isInShadow = neatIsect.has_value() ? (neatIsect->dist <= ldis.Length()) : false;

            if (!isInShadow) {
                double illum = livec * norm;
                double specular = livec * reflectDir;

                Color lcolor = (illum > 0) ? (light.color.Scale(illum)) : Color::DefaultColor;
                Color scolor = (specular > 0) ? (light.color.Scale(pow(specular, surface.Roughness))) : Color::DefaultColor;
                result = result + lcolor * surface.Diffuse + scolor * surface.Specular;
            }
        }
        return result;
    }

public:
    RayTracerEngine(Scene& scene) : scene(scene) {}

    void render(RgbColor* image, int w, int h)
    {
        Ray ray(scene.camera.pos, Vector());
        auto& camera = scene.camera;
        int pos = 0;

        for (int y = 0; y < h; ++y) {
            pos = y * h;
            for (int x = 0; x < w; ++x) {
                ray.dir = camera.GetPoint(x, y, w, h);
                image[pos + x] = TraceRay(ray, 0).ToDrawingColor();
            }
        }
    }
};

void SaveImage(RgbColor* bitmapBits, int width, int height, const char* fileName)
{
    typedef unsigned int DWORD;
    typedef int LONG;
    typedef unsigned short WORD;
    const int BI_RGB = 0;

    struct BITMAPINFOHEADER {
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
    };

#pragma pack(push, 1)
    struct BITMAPFILEHEADER {
        WORD  bfType;
        DWORD bfSize;
        WORD  bfReserved1;
        WORD  bfReserved2;
        DWORD bfOffBits;
    };
#pragma pack(pop)

    BITMAPINFOHEADER bmpInfoHeader = { 0 };
    bmpInfoHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmpInfoHeader.biBitCount = 32;
    bmpInfoHeader.biClrImportant = 0;
    bmpInfoHeader.biClrUsed = 0;
    bmpInfoHeader.biCompression = BI_RGB;
    bmpInfoHeader.biHeight = -height;
    bmpInfoHeader.biWidth = width;
    bmpInfoHeader.biPlanes = 1;
    bmpInfoHeader.biSizeImage = width * height * 4;

    BITMAPFILEHEADER bfh = { 0 };
    bfh.bfType = 'B' + ('M' << 8);
    bfh.bfOffBits = sizeof(BITMAPINFOHEADER) + sizeof(BITMAPFILEHEADER);
    bfh.bfSize = bfh.bfOffBits + bmpInfoHeader.biSizeImage;

    std::ofstream file(fileName, std::ios::binary | std::ios::trunc);
    file.write((const char*)&bfh, sizeof(bfh));
    file.write((const char*)&bmpInfoHeader, sizeof(bmpInfoHeader));
    file.write((const char*)bitmapBits, bmpInfoHeader.biSizeImage);
    file.close();
}

int main()
{
    std::cout << "Started " << std::endl;
    auto t1 = std::chrono::high_resolution_clock::now();

    Scene scene;
    RayTracerEngine rayTracer(scene);

    const int width = 500;
    const int height = 500;

    std::vector<RgbColor> bitmapData(width * height);
    rayTracer.render(&bitmapData[0], width, height);

    auto t2 = std::chrono::high_resolution_clock::now();
    auto diff = std::chrono::duration_cast<std::chrono::milliseconds>((t2 - t1));

    std::cout << "Completed in " << diff.count() << " ms" << std::endl;
    SaveImage(&bitmapData[0], width, height, "cpp-raytracer.bmp");

    return 0;
};
