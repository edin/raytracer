import std.stdio;
import std.datetime;
import std.typecons;
import std.container;
import std.math;
import std.conv;
import core.sys.windows.windows;
import std.algorithm.comparison;
import std.algorithm;

struct RGBColor
{
    ubyte b, g, r, a;
}

struct Vector
{
    double x, y, z;

    Vector opBinaryRight(string op)(double k) const if(op == "*")
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
        return Vector(y * v.z - z * v.y,
                      z * v.x - x * v.z,
                      x * v.y - y * v.x);
    }
}

struct Color
{
    double r, g, b;

    static immutable Color white = Color(1.0, 1.0, 1.0);
    static immutable Color grey  = Color(0.5, 0.5, 0.5);
    static immutable Color black = Color(0.0, 0.0, 0.0);
    static immutable Color background   = black;
    static immutable Color defaultColor = black;

    Color opBinaryRight(string op)(double k) const if(op == "*")
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
        const double value = std.algorithm.comparison.clamp(c*255.0, 0.0, 255.0);
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
        const Vector _down     = Vector(0.0, -1.0, 0.0);
        const Vector _forward = lookAt - pos;
        this.pos      = pos;
        this.forward  = _forward.norm;
        this.right    = 1.5 * this.forward.cross(_down).norm;
        this.up       = 1.5 * this.forward.cross(this.right).norm;
    }
}

struct Ray
{
    Vector start;
    Vector dir;
}

struct Intersection
{
    Thing thing;
    Ray ray;
    double dist;
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
    Nullable!Intersection intersect(ref const Ray ray) const;
    Vector normal(ref Vector pos) const;
    Surface surface() const;
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
    public Surface _surface;

    public this(Vector center, double radius, Surface surface)
    {
        this.radius2 = radius * radius;
        this.center = center;
        this._surface = surface;
    }

    public Vector normal(ref Vector pos) const
    {
        return (pos - this.center).norm;
    }

    public Nullable!Intersection intersect(ref Ray ray) const
    {
        Nullable!Intersection result;
        Vector eo = this.center - ray.start;
        const double v  = eo.dot(ray.dir);
        double dist = 0;
        if (v >= 0)
        {
            double disc = this.radius2 - (eo.dot(eo) - v * v);
            if (disc >= 0)
            {
                dist = v - sqrt(disc);
            }
        }

        if (dist == 0) {
            return result;
        }
        result = Intersection(this, ray, dist);
        return result;
    }

    public Surface surface() const
    {
        return _surface;
    }
}

class Plane: Thing
{
    private Vector norm;
    private double offset;
    private Surface _surface;

    public Vector normal(ref Vector pos) const
    {
        return this.norm;
    }

    public Nullable!Intersection intersect(ref const Ray ray) const
    {
        Nullable!Intersection result;

        const double denom = norm.dot(ray.dir);
        if (denom > 0)
        {
            return result;
        }
        const double dist = (norm.dot(ray.start) + offset) / (-denom);
        result = Intersection(this, ray, dist);
        return result;
    }

    public this(Vector norm, double offset, Surface surface)
    {
        this._surface = surface;
        this.norm = norm;
        this.offset = offset;
    }

    public Surface surface() const
    {
        return _surface;
    }
}

class ShinySurface: Surface
{
    public override SurfaceProperties getSurfaceProperties(ref Vector pos) {
        return SurfaceProperties(Color.white, Color.grey, 0.7, 250.0);
    }
}

class CheckerboardSurface : Surface
{
    public override SurfaceProperties getSurfaceProperties(ref Vector pos)
    {
        Color diffuse = Color.black;
        double reflect = 0.7;

        if (to!int(floor(pos.z) + floor(pos.x))  % 2 != 0) {
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
    public Camera  camera;

    public this()
    {
        ShinySurface shiny = new ShinySurface();
        CheckerboardSurface checkerboard = new CheckerboardSurface();

        this.things = [
            cast(Thing)new Plane (Vector(0.0, 1.0, 0.0),   0.0, checkerboard),
            cast(Thing)new Sphere(Vector(0.0, 1.0, -0.25), 1.0, shiny),
            cast(Thing)new Sphere(Vector(-1.0, 0.5, 1.5),  0.5, shiny)
        ];

        this.lights = [
            Light(Vector(-2.0, 2.5, 0.0), Color(0.49, 0.07, 0.07)),
            Light(Vector(1.5, 2.5, 1.5),  Color(0.07, 0.07, 0.49)),
            Light(Vector(1.5, 2.5, -1.5), Color(0.07, 0.49, 0.071)),
            Light(Vector(0.0, 3.5, 0.0),  Color(0.21, 0.21, 0.35)),
        ];

        this.camera = new Camera(Vector(3.0, 2.0, 4.0), Vector(-1.0, 0.5, 0.0));
    }
}

class RayTracerEngine
{
    private static const int maxDepth = 5;
    private Scene scene;

    private Nullable!Intersection intersections(ref Ray ray) const
    {
        double closest = double.infinity;
        Nullable!Intersection closestInter;

        foreach (thing; scene.things)
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

    private Color traceRay(ref Ray ray, int depth)
    {
        Nullable!Intersection isect = intersections(ray);
        if (isect.isNull) {
            return Color.background;
        }
        return this.shade(isect, depth);
    }

    private Color shade(ref Intersection isect, int depth)
    {
        Vector d      = isect.ray.dir;
        Vector pos    = isect.dist * d + isect.ray.start;
        Vector normal = isect.thing.normal(pos);

        const Vector vec   = 2.0 * (normal.dot(d) * normal);
        Vector reflectDir  = (d - vec);
        auto  surface = isect.thing.surface.getSurfaceProperties(pos);

        Color getReflectionColor() {
            Ray ray = Ray(pos, reflectDir);
            return surface.reflect * traceRay(ray, depth + 1);
        }

        Color getNaturalColor()
        {
            Color   resultColor = Color.black;
            Vector  rayDirNormal = reflectDir.norm();
            Color colDiffuse  = surface.diffuse;
            Color colSpecular = surface.specular;
            Ray ray = Ray(pos, Vector(0,0,0));

            void addLight(ref Light light)
            {
                const Vector ldis    = light.pos - pos;
                Vector livec   = ldis.norm;
                ray.dir = livec;

                const auto  neatIsect  = intersections(ray);
                const bool  isInShadow = (neatIsect.isNull) ? false : (neatIsect.dist <= ldis.mag);

                if (!isInShadow) {
                    const double illum    = livec.dot(normal);
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

    private Vector getPoint(int x, int y, Camera camera, int screenWidth, int screenHeight, int scale)
    {
        const double recenterX =  (x - (screenWidth / 2.0)) / 2.0 / scale;
        const double recenterY = -(y - (screenHeight / 2.0)) / 2.0 / scale;
        const Vector vx = recenterX * camera.right;
        const Vector vy = recenterY * camera.up;
        const Vector v  = vx + vy;
        return (camera.forward + v).norm;
    }

    public void render(Scene scene, ubyte[] bitmapData, int stride, int w, int h)
    {
        //import std.algorithm.comparison;
        this.scene = scene;

        Camera camera = scene.camera;
        Ray ray = Ray(camera.pos, Vector(0,0,0));
        int scale = min(w,h);

        for (int y = 0; y < h; ++y) {
            int pos = y * stride;
            RGBColor* ptrColor = (cast(RGBColor*)&bitmapData[pos]);

            for (int x = 0; x < w; ++x) {
                ray.dir = this.getPoint(x, y, camera, w, h, scale);
                *ptrColor++  = this.traceRay(ray, 0).toDrawingColor;
            }
        }
    }
}

void saveImage(ubyte[] pBitmapBits, int lWidth, int lHeight, int wBitsPerPixel, string fileName )
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

    struct BITMAPFILEHEADER {
        WORD  bfType;
        DWORD bfSize;
        WORD  bfReserved1;
        WORD  bfReserved2;
        DWORD bfOffBits;
    }

    BITMAPFILEHEADER bfh = {  };
    bfh.bfType    = 'B' + ('M' << 8);
    bfh.bfOffBits = BITMAPINFOHEADER.sizeof + 14;
    bfh.bfSize    = bfh.bfOffBits + bmpInfoHeader.biSizeImage;

    auto file = File(fileName, "wb");
    file.rawWrite((cast(ubyte*)&bfh)[0..2]); // Skip padded bytes
    file.rawWrite((cast(ubyte*)&bfh)[4..16]);
    file.rawWrite((cast(ubyte*)&bmpInfoHeader)[0 .. 40]);
    file.rawWrite(pBitmapBits);
    file.close();
}

void main(string[] argv)
{
    writeln("Starting");
    StopWatch sw;
    sw.start();

    int width  = 500;
    int height = 500;
    int stride = width * 4;
    ubyte[] bitmapData = new ubyte[stride * height];

    Scene scene = new Scene();
    RayTracerEngine rayTracer = new RayTracerEngine();

    rayTracer.render(scene, bitmapData, stride,width,height);
    sw.stop();
    saveImage(bitmapData, width,height, 32, "d-raytracer.bmp");
    writeln("Completed in: ", sw.peek.msecs, " [ms]");
}