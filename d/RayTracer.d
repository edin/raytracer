import std.stdio;
import std.datetime;
import std.typecons;
import std.container;
import std.math;
import std.conv;
import core.sys.windows.windows;

struct RGBColor
{
    ubyte b;
    ubyte g;
    ubyte r;
    ubyte a;
}

struct Vector
{
    double x;
    double y;
    double z;

    this(double x, double y, double z)
    {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    Vector opBinaryRight(string op)(double k) const if(op == "*")
    {
        return Vector(k * x, k * y, k * z);
    }

    Vector opBinary(string op)(Vector v) if (op == "+")
    {
        return Vector(x + v.x, y + v.y, z + v.z);
    }

    Vector opBinary(string op)(Vector v) if (op == "-")
    {
        return Vector(x - v.x, y - v.y, z - v.z);
    }

    double dot(const Vector v)
    {
        return x * v.x + y * v.y + z * v.z;
    }

    double mag()
    {
        return sqrt(x * x + y * y + z * z);
    }

    Vector norm()
    {
        double magnitude = this.mag;
        double div = (mag == 0) ? double.infinity : 1.0 / magnitude;
        return div * this;
    }

    Vector cross(const Vector v) const
    {
        return Vector(y * v.z - z * v.y,
                      z * v.x - x * v.z,
                      x * v.y - y * v.x);
    }
}

struct Color
{
    double r = 0;
    double g = 0;
    double b = 0;

    static const Color white = Color(1.0, 1.0, 1.0);
    static const Color grey  = Color(0.5, 0.5, 0.5);
    static const Color black = Color(0.0, 0.0, 0.0);
    static const Color background = black;
    static const Color defaultColor = black;

    this(double r, double g, double b)
    {
        this.r = r;
        this.g = g;
        this.b = b;
    }

    Color opBinaryRight(string op)(double k) if(op == "*")
    {
        return Color(k * r, k * g, k * b);
    }

    Color opBinary(string op)(const Color color) if (op == "+")
    {
        return Color(r + color.r, g + color.g, b + color.b);
    }

    Color opBinary(string op)(const Color color) if (op == "*")
    {
        return Color(r * color.r, g * color.g, b * color.b);
    }

    RGBColor toDrawingColor()
    {
        RGBColor color;
        color.r = to!ubyte(legalize(r));
        color.g = to!ubyte(legalize(g));
        color.b = to!ubyte(legalize(b));
        color.a = 255;
        return color;
    }

    static int legalize(double c)
    {
        int x = to!int(c * 255.0);
        if (x < 0) x = 0;
        if (x > 255) x = 255;
        return x;
    }
}

class Camera
{
public:
    Vector forward;
    Vector right;
    Vector up;
    Vector pos;

    this(){}

    this(Vector pos, Vector lookAt)
    {
        this.pos = pos;
        Vector down    = Vector(0.0, -1.0, 0.0);
        Vector forward = lookAt - pos;
        this.forward  = forward.norm;
        this.right    = 1.5 * this.forward.cross(down).norm;
        this.up       = 1.5 * this.forward.cross(this.right).norm;
    }
}

struct Ray
{
    Vector start;
    Vector dir;

    this(Vector start, Vector dir)
    {
        this.start = start;
        this.dir = dir;
    }
}

struct Intersection
{
    Thing thing;
    Ray ray;
    double dist;

    this(Thing thing, Ray ray, double dist)
    {
        this.thing = thing;
        this.ray = ray;
        this.dist = dist;
    }
}

class Surface
{
public:
    Color  diffuse(Vector pos)  { return Color.black; };
    Color  specular(Vector pos) { return Color.black; };
    double reflect(Vector pos)  { return 0; };
    double roughness()          { return 0; };
}

interface Thing
{
    Nullable!Intersection intersect(Ray ray);
    Vector normal(Vector pos);
    Surface surface();
}

class Light
{
public:
    Vector pos;
    Color color;

    this(Vector pos, Color color)
    {
        this.pos = pos;
        this.color = color;
    }
}

interface Scene
{
    ref Array!Thing things();
    ref Array!Light lights();
    Camera camera();
}

class Sphere : Thing
{
public:
    double radius2;
    Vector center;
    Surface _surface;

    this(Vector center, double radius, Surface surface)
    {
        this.radius2 = radius * radius;
        this.center = center;
        this._surface = surface;
    }

    Vector normal(Vector pos)
    {
        return (pos - this.center).norm;
    }

    Nullable!Intersection intersect(Ray ray)
    {
        Nullable!Intersection result;

        Vector eo = this.center - ray.start;
        double v  = eo.dot(ray.dir);
        double dist = 0;
        if (v >= 0)
        {
            double disc = this.radius2 - (eo.dot(eo) - v * v);
            if (disc >= 0)
            {
                dist = v - sqrt(disc);
            }
        }

        if (dist == 0)
        {
            return result;
        }
        result = Intersection(this, ray, dist);
        return result;
    }

    Surface surface()
    {
        return _surface;
    }
}

class Plane: Thing
{
private:
    Vector norm;
    double offset;
public:
    Surface _surface;

    Vector normal(Vector pos)
    {
        return this.norm;
    }

    Nullable!Intersection intersect(Ray ray)
    {
        Nullable!Intersection result;

        double denom = norm.dot(ray.dir);
        if (denom > 0)
        {
            return result;
        }
        double dist = (norm.dot(ray.start) + offset) / (-denom);
        result = Intersection(this, ray, dist);
        return result;
    }

    this(Vector norm, double offset, Surface surface)
    {
        this._surface = surface;
        this.norm = norm;
        this.offset = offset;
    }

    Surface surface()
    {
        return _surface;
    }
}

class ShinySurface: Surface
{
public:
    override Color diffuse(Vector pos)
    {
        return Color.white;
    }

    override Color specular(Vector pos)
    {
        return Color.grey;
    }

    override double reflect(Vector pos)
    {
        return 0.7;
    }

    override double roughness()
    {
        return 250.0;
    }
}

class CheckerboardSurface : Surface
{
public:
    override Color diffuse(Vector pos)
    {
        if ( to!int(floor(pos.z) + floor(pos.x))  % 2 != 0)
        {
            return Color.white;
        }
        else
        {
            return Color.black;
        }
    }

    override Color specular(Vector pos)
    {
        return Color.white;
    }

    override double reflect(Vector pos)
    {
        if (to!int(floor(pos.z) + floor(pos.x)) % 2 != 0)
        {
            return 0.1;
        }
        return 0.7;
    }

    override double roughness()
    {
        return 150.0;
    }
}

class DefaultScene: Scene
{
private:
    Array!Thing m_things;
    Array!Light m_lights;
    Camera      m_camera;
public:
    this()
    {
        ShinySurface        shiny        = new ShinySurface();
        CheckerboardSurface checkerboard = new CheckerboardSurface();

        m_things = Array!Thing([
            cast(Thing)new Plane (Vector(0.0, 1.0, 0.0),   0.0, checkerboard),
            cast(Thing)new Sphere(Vector(0.0, 1.0, -0.25), 1.0, shiny),
            cast(Thing)new Sphere(Vector(-1.0, 0.5, 1.5),  0.5, shiny)
        ]);

        m_lights = Array!Light([
            new Light(Vector(-2.0, 2.5, 0.0), Color(0.49, 0.07, 0.07)),
            new Light(Vector(1.5, 2.5, 1.5),  Color(0.07, 0.07, 0.49)),
            new Light(Vector(1.5, 2.5, -1.5), Color(0.07, 0.49, 0.071)),
            new Light(Vector(0.0, 3.5, 0.0),  Color(0.21, 0.21, 0.35)),
        ]);

        m_camera = new Camera(Vector(3.0, 2.0, 4.0), Vector(-1.0, 0.5, 0.0));
    }

    ref Array!Thing things()
    {
        return m_things;
    }

    ref Array!Light lights()
    {
        return m_lights;
    }

    Camera camera()
    {
        return m_camera;
    }
}

class RayTracerEngine
{
private:
    static const int maxDepth = 5;

    Nullable!Intersection intersections(Ray ray, Scene scene)
    {
        double closest = double.infinity;
        Nullable!Intersection closestInter;

        foreach (thing; scene.things())
        {
            auto inter = thing.intersect(ray);
            if (!inter.isNull && inter.dist < closest)
            {
                closestInter = inter;
                closest = inter.dist;
            }
        }
        return closestInter;
    }

    double testRay(Ray ray, Scene scene)
    {
        Nullable!Intersection isect = this.intersections(ray, scene);
        if (!isect.isNull)
        {
            return isect.dist;
        }
        return double.nan;
    }

    Color traceRay(Ray ray, Scene scene, int depth)
    {
        Nullable!Intersection isect = this.intersections(ray, scene);
        if (isect.isNull)
        {
            return Color.background;
        }
        return this.shade(isect, scene, depth);
    }

    Color shade(Intersection isect, Scene scene, int depth)
    {
        Vector d      = isect.ray.dir;
        Vector pos    = isect.dist * d + isect.ray.start;
        Vector normal = isect.thing.normal(pos);

        Vector reflectDir  = d - (2.0 * (normal.dot(d)* normal));
        Color naturalColor = cast(Color)Color.background + this.getNaturalColor(isect.thing, pos, normal, reflectDir, scene);

        Color reflectedColor = (depth >= this.maxDepth) ?
                               Color.grey : this.getReflectionColor(isect.thing, pos, normal, reflectDir, scene, depth);

        return naturalColor + reflectedColor;
    }

    Color getReflectionColor(Thing thing, Vector pos, Vector normal, Vector rd, Scene scene, int depth)
    {
        Ray ray = Ray(pos, rd);
        return thing.surface.reflect(pos) * this.traceRay(ray, scene, depth + 1);
    }

    Color getNaturalColor(Thing thing, const Vector pos, const Vector norm, const Vector rd, Scene scene)
    {
        Color c = Color.black;
        foreach (item; scene.lights)
        {
            Color newColor = addLight(c, item, pos, scene, thing, rd, norm);
            c = newColor;
        }
        return c;
    }

    Color addLight(Color col, Light light, Vector pos,
                   Scene scene, Thing thing,
                   Vector rd, Vector norm)
    {
        Vector ldis  = light.pos - pos;
        Vector livec = ldis.norm;
        double neatIsect = this.testRay(Ray(pos, livec), scene);

        bool isInShadow = (neatIsect == double.nan) ? false : (neatIsect <= ldis.mag);

        if (isInShadow) {
            return col;
        }

        double illum = livec.dot(norm);
        Color lcolor = (illum > 0) ? illum * light.color: Color.defaultColor;

        double specular = livec.dot(rd.norm);
        Color scolor = (specular > 0) ? pow(specular, thing.surface.roughness) * light.color : Color.defaultColor;

        return  col + ((thing.surface.diffuse(pos) * lcolor) +
                       (thing.surface.specular(pos) * scolor));

    }

    Vector getPoint(int x, int y, Camera camera, int screenWidth, int screenHeight, int scale)
    {
        double recenterX =  (x - (screenWidth / 2.0)) / 2.0 / scale;
        double recenterY = -(y - (screenHeight / 2.0)) / 2.0 / scale;
        return (camera.forward + (recenterX * camera.right + recenterY * camera.up)).norm;
    }

public:
    void render(Scene scene, ubyte[] bitmapData, int stride, int w, int h)
    {
        import std.algorithm.comparison;

        Ray ray;
        ray.start     = scene.camera.pos;
        Camera camera = scene.camera;

        int scale = min(w,h);

        for (int y = 0; y < h; ++y)
        {
            int pos = y * stride;
            RGBColor* ptrColor = (cast(RGBColor*)&bitmapData[pos]);

            for (int x = 0; x < w; ++x) {
                ray.dir      = this.getPoint(x, y, camera, w, h, scale);
                *ptrColor++  = this.traceRay(ray, scene, 0).toDrawingColor;
            }
        }
    }
}

void SaveRGBBitmap(ubyte[] pBitmapBits, int lWidth, int lHeight, int wBitsPerPixel, string fileName )
{
    const BI_RGB = 0;

    BITMAPINFOHEADER bmpInfoHeader = {};
    bmpInfoHeader.biSize = BITMAPINFOHEADER.sizeof;
    bmpInfoHeader.biBitCount = cast(WORD)wBitsPerPixel;
    bmpInfoHeader.biClrImportant = 0;
    bmpInfoHeader.biClrUsed = 0;
    bmpInfoHeader.biCompression = BI_RGB;
    bmpInfoHeader.biHeight = -lHeight;
    bmpInfoHeader.biWidth = lWidth;
    bmpInfoHeader.biPlanes = 1;
    bmpInfoHeader.biSizeImage = lWidth* lHeight * (wBitsPerPixel/8);

    struct BITMAPFILEHEADER
    {
        //align(1):
        WORD  bfType;
        DWORD bfSize;
        WORD  bfReserved1;
        WORD  bfReserved2;
        DWORD bfOffBits;
    };

    BITMAPFILEHEADER bfh = {};
    bfh.bfType    = 'B' + ('M' << 8);
    bfh.bfOffBits = BITMAPINFOHEADER.sizeof + 14; // BITMAPFILEHEADER.sizeof;
    bfh.bfSize    = bfh.bfOffBits + bmpInfoHeader.biSizeImage;

    auto file = File(fileName, "wb");

    file.rawWrite((cast(ubyte*)&bfh)[0..2]); //Skip padded bytes
    file.rawWrite((cast(ubyte*)&bfh)[4..16]);
    file.rawWrite((cast(ubyte*)&bmpInfoHeader)[0 .. 40]);
    file.rawWrite(pBitmapBits);
    file.close();
}

int main(string[] argv)
{
    writeln("Starting");
    StopWatch sw;
    sw.start();

    int width  = 500;
    int height = 500;
    int stride = width * 4;
    ubyte[] bitmapData = new ubyte[stride * height];

    Scene scene = new DefaultScene();
    RayTracerEngine rayTracer = new RayTracerEngine();

    rayTracer.render(scene, bitmapData, stride,width,height);
    sw.stop();

    SaveRGBBitmap(bitmapData, width,height, 32, "d-raytracer.bmp");

    writeln("Completed in: ", sw.peek.msecs, " [ms]");
    readln;
    return 0;
}

unittest{
    int width  = 100;
    int height = 100;
    int stride = width * 4;
    ubyte[] bitmapData = new ubyte[stride * height];

    Scene scene = new DefaultScene();
    RayTracerEngine rayTracer = new RayTracerEngine();

    rayTracer.render(scene, bitmapData, stride,width,height);
}