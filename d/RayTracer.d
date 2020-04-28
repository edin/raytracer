import std.stdio;
import std.datetime;
import std.typecons;
import std.container;
import std.math;
import std.conv;
import std.algorithm.comparison;
import std.algorithm;

struct RGBColor
{
    ubyte b, g, r, a;
}

struct Vector
{
    double x, y, z;

    Vector opBinaryRight(string op)(double k) const if (op == "*")
    {
        return Vector(k * x, k * y, k * z);
    }

    Vector opBinary(string op)(const ref Vector v) const if (op == "+")
    {
        return Vector(x + v.x, y + v.y, z + v.z);
    }

    Vector opBinary(string op)(const ref Vector v) const if (op == "-")
    {
        return Vector(x - v.x, y - v.y, z - v.z);
    }

    double dot(const ref Vector v) const
    {
        return x * v.x + y * v.y + z * v.z;
    }

    double mag() const
    {
        return sqrt(x * x + y * y + z * z);
    }

    Vector norm() const
    {
        const double magnitude = this.mag;
        const double div = (mag == 0) ? double.infinity : 1.0 / magnitude;
        return div * this;
    }

    Vector cross(const ref Vector v) const
    {
        return Vector(y * v.z - z * v.y, z * v.x - x * v.z, x * v.y - y * v.x);
    }
}

struct Color
{
    double r, g, b;

    static immutable Color white = Color(1.0, 1.0, 1.0);
    static immutable Color grey = Color(0.5, 0.5, 0.5);
    static immutable Color black = Color(0.0, 0.0, 0.0);
    static immutable Color background = black;
    static immutable Color defaultColor = black;

    Color opBinaryRight(string op)(double k) const if (op == "*")
    {
        return Color(k * r, k * g, k * b);
    }

    Color opBinary(string op)(Color c) const if (op == "+")
    {
        return Color(r + c.r, g + c.g, b + c.b);
    }

    Color times(const ref Color c) const
    {
        return Color(r * c.r, g * c.g, b * c.b);
    }

    RGBColor toDrawingColor() const
    {
        return RGBColor(clamp(b), clamp(g), clamp(r), 255);
    }

    private static ubyte clamp(double c)
    {
        const double value = std.algorithm.comparison.clamp(c * 255.0, 0.0, 255.0);
        return to!ubyte(value);
    }
}

class Camera
{
    public Vector forward;
    public Vector right;
    public Vector up;
    public Vector pos;

    public this(Vector pos, Vector lookAt)
    {
        const Vector _down = Vector(0.0, -1.0, 0.0);
        const Vector _forward = lookAt - pos;
        this.pos = pos;
        this.forward = _forward.norm;
        this.right = 1.5 * this.forward.cross(_down).norm;
        this.up = 1.5 * this.forward.cross(this.right).norm;
    }

    private Vector getPoint(int x, int y, int screenWidth, int screenHeight, int scale)
    {
        const double recenterX = (x - (screenWidth / 2.0)) / 2.0 / scale;
        const double recenterY = -(y - (screenHeight / 2.0)) / 2.0 / scale;
        const Vector vx = recenterX * this.right;
        const Vector vy = recenterY * this.up;
        const Vector v = vx + vy;
        return (this.forward + v).norm;
    }
}

struct Ray
{
    Vector start;
    Vector dir;
}

class Intersection
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

struct SurfaceProperties
{
    Color diffuse;
    Color specular;
    double reflect;
    double roughness;
}

interface Surface
{
    public SurfaceProperties getSurfaceProperties(ref Vector pos);
}

interface Thing
{
    Intersection intersect(ref const Ray ray);
    Vector normal(ref Vector pos);
    Surface surface();
}

struct Light
{
    public Vector pos;
    public Color color;
}

class Sphere : Thing
{
    public double radius2;
    public Vector center;
    private Surface _surface;

    public this(Vector center, double radius, Surface surface)
    {
        this.radius2 = radius * radius;
        this.center = center;
        this._surface = surface;
    }

    public Vector normal(ref Vector pos)
    {
        return (pos - this.center).norm;
    }

    public Intersection intersect(ref const Ray ray)
    {
        Vector eo = this.center - ray.start;
        const double v = eo.dot(ray.dir);
        double dist = 0;
        if (v >= 0)
        {
            const double disc = this.radius2 - (eo.dot(eo) - v * v);
            dist = (disc >= 0) ? v - sqrt(disc) : dist;
        }
        return (dist == 0) ? null : new Intersection(this, ray, dist);
    }

    public Surface surface()
    {
        return _surface;
    }
}

class Plane : Thing
{
    private Vector norm;
    private double offset;
    private Surface _surface;

    public this(Vector norm, double offset, Surface surface)
    {
        this._surface = surface;
        this.norm = norm;
        this.offset = offset;
    }

    public Vector normal(ref Vector pos)
    {
        return this.norm;
    }

    public Intersection intersect(ref const Ray ray)
    {
        const double denom = norm.dot(ray.dir);
        if (denom <= 0)
        {
            const double dist = (norm.dot(ray.start) + offset) / (-denom);
            return new Intersection(this, ray, dist);
        }
        return null;
    }

    public Surface surface()
    {
        return _surface;
    }
}

class ShinySurface : Surface
{
    public override SurfaceProperties getSurfaceProperties(ref Vector pos)
    {
        return SurfaceProperties(Color.white, Color.grey, 0.7, 250.0);
    }
}

class CheckerboardSurface : Surface
{
    public override SurfaceProperties getSurfaceProperties(ref Vector pos)
    {
        Color diffuse = Color.black;
        double reflect = 0.7;
        if (to!int(floor(pos.z) + floor(pos.x)) % 2 != 0)
        {
            diffuse = Color.white;
            reflect = 0.1;
        }
        return SurfaceProperties(diffuse, Color.white, reflect, 150.0);
    }
}

class Scene
{
    public Thing[] things;
    public Light[] lights;
    public Camera camera;

    public this()
    {
        ShinySurface shiny = new ShinySurface();
        CheckerboardSurface checkerboard = new CheckerboardSurface();

        this.things = [
            cast(Thing) new Plane(Vector(0.0, 1.0, 0.0), 0.0, checkerboard),
            cast(Thing) new Sphere(Vector(0.0, 1.0, -0.25), 1.0, shiny),
            cast(Thing) new Sphere(Vector(-1.0, 0.5, 1.5), 0.5, shiny)
        ];

        this.lights = [
            Light(Vector(-2.0, 2.5, 0.0), Color(0.49, 0.07, 0.07)),
            Light(Vector(1.5, 2.5, 1.5), Color(0.07, 0.07, 0.49)),
            Light(Vector(1.5, 2.5, -1.5), Color(0.07, 0.49, 0.071)),
            Light(Vector(0.0, 3.5, 0.0), Color(0.21, 0.21, 0.35)),
        ];

        this.camera = new Camera(Vector(3.0, 2.0, 4.0), Vector(-1.0, 0.5, 0.0));
    }
}

class RayTracerEngine
{
    private static const int maxDepth = 5;
    private Scene scene;

    private Intersection intersections(ref Ray ray)
    {
        double closest = double.infinity;
        Intersection closestInter = null;

        foreach (thing; scene.things)
        {
            auto inter = thing.intersect(ray);
            if (inter !is null && inter.dist < closest)
            {
                closestInter = inter;
                closest = inter.dist;
            }
        }
        return closestInter;
    }

    private Color traceRay(ref Ray ray, int depth)
    {
        Intersection isect = intersections(ray);
        return (isect is null) ? Color.background : this.shade(isect, depth);
    }

    private Color shade(Intersection isect, int depth)
    {
        Vector d = isect.ray.dir;
        Vector pos = isect.dist * d + isect.ray.start;
        Vector normal = isect.thing.normal(pos);

        const Vector vec = 2.0 * (normal.dot(d) * normal);
        Vector reflectDir = (d - vec);
        auto surface = isect.thing.surface.getSurfaceProperties(pos);

        Color getReflectionColor()
        {
            Ray ray = Ray(pos, reflectDir);
            return surface.reflect * traceRay(ray, depth + 1);
        }

        Color getNaturalColor()
        {
            Color resultColor = Color.black;
            Vector rayDirNormal = reflectDir.norm();
            Color colDiffuse = surface.diffuse;
            Color colSpecular = surface.specular;
            Ray ray = Ray(pos, Vector(0, 0, 0));

            void addLight(ref Light light)
            {
                const Vector ldis = light.pos - pos;
                Vector livec = ldis.norm;
                ray.dir = livec;

                const auto neatIsect = intersections(ray);
                const bool isInShadow = (neatIsect !is null) && (neatIsect.dist <= ldis.mag);

                if (!isInShadow)
                {
                    const double illum = livec.dot(normal);
                    const double specular = livec.dot(rayDirNormal);
                    Color lcolor = (illum > 0) ? illum * light.color : Color.defaultColor;
                    Color scolor = (specular > 0) ? pow(specular, surface.roughness) * light.color : Color.defaultColor;
                    resultColor = resultColor + lcolor.times(colDiffuse) + scolor.times(colSpecular);
                }
            }
            foreach (item; scene.lights)
            {
                addLight(item);
            }
            return resultColor;
        }

        Color naturalColor = getNaturalColor() + Color.background;
        Color reflectedColor = (depth >= this.maxDepth) ? Color.grey : getReflectionColor();
        return naturalColor + reflectedColor;
    }

    public void render(Scene scene, Image image)
    {
        this.scene = scene;
        Camera camera = scene.camera;
        Ray ray = Ray(camera.pos, Vector(0, 0, 0));
        int w = image.width;
        int h = image.height;
        int scale = min(w, h);

        for (int y = 0; y < h; ++y)
        {
            for (int x = 0; x < w; ++x)
            {
                ray.dir = camera.getPoint(x, y, w, h, scale);
                RGBColor color = this.traceRay(ray, 0).toDrawingColor;
                image.setColor(x, y, color);
            }
        }
    }
}

class Image
{
    private int _width;
    private int _height;
    private RGBColor[] _data;

    @property int width()
    {
        return _width;
    }

    @property int height()
    {
        return _height;
    }

    this(int width, int height)
    {
        this._width = width;
        this._height = height;
        this._data = new RGBColor[_width * _height];
    }

    public void setColor(int x, int y, ref RGBColor color)
    {
        this._data[y * _height + x] = color;
    }

    public void save(string fileName)
    {
        alias WORD = ushort;
        alias DWORD = uint;
        alias LONG = int;

        struct BITMAPINFOHEADER
        {
            DWORD biSize;
            LONG biWidth;
            LONG biHeight;
            WORD biPlanes;
            WORD biBitCount;
            DWORD biCompression;
            DWORD biSizeImage;
            LONG biXPelsPerMeter;
            LONG biYPelsPerMeter;
            DWORD biClrUsed;
            DWORD biClrImportant;
        }

        struct BITMAPFILEHEADER
        {
            WORD bfType;
            DWORD bfSize;
            WORD bfReserved1;
            WORD bfReserved2;
            DWORD bfOffBits;
        }

        BITMAPINFOHEADER bmpInfoHeader = {};
        bmpInfoHeader.biSize = BITMAPINFOHEADER.sizeof;
        bmpInfoHeader.biBitCount = 32;
        bmpInfoHeader.biClrImportant = 0;
        bmpInfoHeader.biClrUsed = 0;
        bmpInfoHeader.biCompression = 0;
        bmpInfoHeader.biHeight = -_height;
        bmpInfoHeader.biWidth = _width;
        bmpInfoHeader.biPlanes = 1;
        bmpInfoHeader.biSizeImage = _width * _height * 4;

        BITMAPFILEHEADER bfh = {};
        bfh.bfType = 'B' + ('M' << 8);
        bfh.bfOffBits = BITMAPINFOHEADER.sizeof + 14;
        bfh.bfSize = bfh.bfOffBits + bmpInfoHeader.biSizeImage;

        auto file = File(fileName, "wb");
        file.rawWrite((cast(ubyte*)&bfh)[0 .. 2]); // Skip padded bytes - could not get struct align to work
        file.rawWrite((cast(ubyte*)&bfh)[4 .. 16]);
        file.rawWrite((cast(ubyte*)&bmpInfoHeader)[0 .. 40]);
        file.rawWrite(_data);
        file.close();
    }
}

void main(string[] argv)
{
    writeln("Starting");
    StopWatch sw;
    sw.start();
    Image image = new Image(500, 500);
    Scene scene = new Scene();
    RayTracerEngine rayTracer = new RayTracerEngine();
    rayTracer.render(scene, image);
    sw.stop();
    writeln("Completed in: ", sw.peek.msecs, " [ms]");
    image.save("d-raytracer.bmp");
}
