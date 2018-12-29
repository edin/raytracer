#include <windows.h>
#include <math.h>
#include <vector>
#include <iostream>
#include <memory>
#include <fstream>
#include <chrono>

const double FarAway = 1000000.0;

struct RgbColor
{
    byte b, g, r, a;
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
        return Scale(div);
    }

    Vector Cross(const Vector &v) const
    {
        return Vector(
            y * v.z - z * v.y,
            z * v.x - x * v.z,
            x * v.y - y * v.x
        );
    }

    Vector Scale(double k) const
    {
        return Vector(k * x, k * y, k * z);
    }

    Vector operator*(double k) const
    {
        return Scale(k);
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

    Color() : r(0), g(0), b(0) {}

    Color(double r, double g, double b) : r(r), g(g), b(b) { }

    Color Scale(double k) const
    {
        return Color(k * r, k * g, k * b);
    }

    static Color Times(const Color &a, const Color &b)
    {
        return Color(a.r * b.r, a.g * b.g, a.b * b.b);
    }

    Color operator * (double k) const
    {
        return Scale(k);
    }

    Color operator * (const Color& c) const
    {
        return Color(r * c.r, g * c.g, b * c.b);
    }

    Color operator + (const Color& c)
    {
        return Color(r + c.r, g + c.g, b + c.b);
    }

    RgbColor ToDrawingColor()
    {
        RgbColor color;
        color.r = (byte)Legalize(r);
        color.g = (byte)Legalize(g);
        color.b = (byte)Legalize(b);
        color.a = 255;
        return color;
    }

    static int Legalize(double c)
    {
        int x = (int)(c * 255);
        if (x < 0)   x = 0;
        if (x > 255) x = 255;
        return x;
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
};

struct Ray
{
    Vector start;
    Vector dir;

    Ray() {}
    Ray(Vector start, Vector dir) : start(start), dir(dir) { }
};

struct Thing;

class Intersection
{
    bool isValid = false;
public:
    const Thing* thing;
    Ray ray;
    double dist;

    Intersection()
    {
        isValid = false;
    }

    Intersection(const Thing* thing, Ray ray, double dist) :
        thing(thing), ray(ray), dist(dist), isValid(true)
    {}

    bool IsValid()
    {
        return isValid;
    }
};

struct SurfacePropreties
{
    Color Diffuse;
    Color Specular;
    double Reflect;
    double Roughness;

    SurfacePropreties() {}
    SurfacePropreties(Color diffuse, Color specular, double reflect, double roughness) :
        Diffuse(diffuse), Specular(specular), Reflect(reflect), Roughness(roughness)
    {}
};

struct Surface
{
    virtual SurfacePropreties GetSurfaceProperties(const Vector& pos) const = 0;
};

struct Thing
{
    virtual Intersection GetIntersection(const Ray& ray) const = 0;
    virtual Vector GetNormal(const Vector& pos) const = 0;
    virtual Surface& GetSurface() const = 0;
};

struct Light
{
    Vector pos;
    Color color;
    Light(Vector pos, Color color) : pos(pos), color(color) { }
};

class Sphere : public Thing
{
private:
    Surface& surface;
    double   radius2;
    Vector   center;
public:
    Sphere(Vector center, double radius, Surface& surface)
        : center(center), surface(surface), radius2(radius*radius)
    { }

    Vector GetNormal(const Vector& pos) const override
    {
        return (pos - center).Norm();
    }

    Intersection GetIntersection(const Ray& ray) const override
    {
        Vector eo = center - ray.start;
        double v = eo * ray.dir;
        double dist = 0;

        if (v >= 0) {
            double disc = radius2 - ((eo * eo) - (v * v));
            if (disc >= 0) {
                dist = v - sqrt(disc);
            }
        }
        if (dist == 0) {
            return Intersection();
        }
        return Intersection(this, ray, dist);
    }

    Surface& GetSurface() const override
    {
        return surface;
    }
};

class Plane : public Thing
{
private:
    Vector norm;
    double offset;
    Surface& surface;
public:

    Plane(Vector norm, double offset, Surface& surface) : surface(surface), norm(norm), offset(offset)
    {
    }

    Vector GetNormal(const Vector& pos) const override
    {
        return norm;
    }

    Intersection GetIntersection(const Ray& ray) const override
    {
        double denom = norm * ray.dir;
        if (denom > 0) {
            return Intersection();
        }
        double dist = ((norm * ray.start) + offset) / (-denom);
        return Intersection(this, ray, dist);
    }

    Surface& GetSurface() const override
    {
        return surface;
    }
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
    Scene &scene;

    Intersection GetClosestIntersection(const Ray& ray)
    {
        double closest = FarAway;
        Intersection closestInter;

        auto& things = scene.things;

        for (auto& thing : things)
        {
            auto inter = thing->GetIntersection(ray);
            if (inter.IsValid() && inter.dist < closest)
            {
                closestInter = inter;
                closest = inter.dist;
            }
        }
        return closestInter;
    }

    double TestRay(const Ray& ray)
    {
        auto isect = GetClosestIntersection(ray);
        if (isect.IsValid())
        {
            return isect.dist;
        }
        return NAN;
    }

    Color TraceRay(const Ray& ray, int depth)
    {
        auto isect = GetClosestIntersection(ray);
        if (isect.IsValid())
        {
            return Shade(isect, depth);
        }
        return Color::Background;
    }

    Color Shade(const Intersection& isect, int depth)
    {
        Vector d = isect.ray.dir;
        Vector pos = (d * isect.dist) + isect.ray.start;
        Vector normal = isect.thing->GetNormal(pos);
        Vector reflectDir = d - ((normal * (normal * d)) * 2);

        auto &surface = isect.thing->GetSurface().GetSurfaceProperties(pos);

        Color naturalColor = Color::Background + GetNaturalColor(surface, pos, normal, reflectDir);
        Color reflectedColor = (depth >= maxDepth)
            ? Color::Grey
            : GetReflectionColor(surface, pos, normal, reflectDir, depth);

        return naturalColor + reflectedColor;
    }

    Color GetReflectionColor(const SurfacePropreties& surface, const Vector& pos, const Vector& normal, const Vector& rd, int depth)
    {
        Ray    ray(pos, rd);
        Color  color = TraceRay(ray, depth + 1);
        return color.Scale(surface.Reflect);
    }

    Color GetNaturalColor(const SurfacePropreties& surface, const Vector& pos, const Vector& norm, const Vector& rd)
    {
        Color result = Color::Black;
        for (auto& item : scene.lights)
        {
            AddLight(result, item, pos, surface, rd, norm);
        }
        return result;
    }

    void AddLight(Color& resultColor, const Light& light, const Vector& pos, const SurfacePropreties& surface, const Vector& rd, const Vector& norm)
    {
        Vector ldis = light.pos - pos;
        Vector livec = ldis.Norm();
        Ray ray{ pos, livec };

        double neatIsect = TestRay(ray);

        bool isInShadow = std::isnan(neatIsect) ? false : (neatIsect <= ldis.Length());
        if (isInShadow) {
            return;
        }
        double illum = livec * norm;
        double specular = livec * rd.Norm();

        Color lcolor = (illum > 0) ? (light.color * illum) : Color::DefaultColor;
        Color scolor = (specular > 0) ? (light.color * pow(specular, surface.Roughness)) : Color::DefaultColor;
        resultColor = resultColor + lcolor * surface.Diffuse + scolor * surface.Specular;
    }

    Vector GetPoint(int x, int y, const Camera& camera, int screenWidth, int screenHeight)
    {
        double recenterX = (x - (screenWidth / 2.0)) / 2.0 / screenWidth;
        double recenterY = -(y - (screenHeight / 2.0)) / 2.0 / screenHeight;
        return (camera.forward + ((camera.right * recenterX) + (camera.up * recenterY))).Norm();
    }

public:
    RayTracerEngine(Scene &scene) : scene(scene) {}

    void render(byte* bitmapData, int stride, int w, int h)
    {
        Ray ray;
        ray.start = scene.camera.pos;
        auto& camera = scene.camera;

        for (int y = 0; y < h; ++y)
        {
            RgbColor* pColor = (RgbColor*)(&bitmapData[y * stride]);
            for (int x = 0; x < w; ++x)
            {
                ray.dir = GetPoint(x, y, camera, h, w);
                *pColor = TraceRay(ray, 0).ToDrawingColor();
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
    bmpInfoHeader.biSizeImage = lWidth * lHeight * (wBitsPerPixel / 8);

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

    Scene scene;
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