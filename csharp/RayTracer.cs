
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing.Imaging;


class Program
{
    static void Main(string[] args)
    {
        var bmp = new System.Drawing.Bitmap(500, 500, PixelFormat.Format32bppArgb);
        Stopwatch sw = new Stopwatch();
        Console.WriteLine("C# RayTracer Test");

        sw.Start();
        RayTracerEngine rayTracer = new RayTracerEngine();
        DefaultScene scene = new DefaultScene();
        rayTracer.render(scene, bmp);
        sw.Stop();
        bmp.Save("csharp-ray-tracer.png");

        Console.WriteLine("");
        Console.WriteLine("Total time: " + sw.ElapsedMilliseconds.ToString() + " ms");
        Console.ReadLine();
    }
}

class Vector
{
    public double x;
    public double y;
    public double z;

    public Vector(double x, double y, double z)
    {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    public static Vector operator -(Vector v1, Vector v2)
    {
        return new Vector(v1.x - v2.x, v1.y - v2.y, v1.z - v2.z);
    }

    public static double dot(Vector v1, Vector v2)
    {
        return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
    }

    public static double mag(Vector v)
    {
        return Math.Sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    }

    public static Vector operator +(Vector v1, Vector v2)
    {
        return new Vector(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z);
    }

    public static Vector operator *(double k, Vector v)
    {
        return new Vector(k * v.x, k * v.y, k * v.z);
    }

    public static Vector norm(Vector v)
    {
        var mag = Vector.mag(v);
        var div = (mag == 0) ? double.PositiveInfinity : 1.0 / mag;
        return div * v;
    }

    public static Vector cross(Vector v1, Vector v2)
    {
        return new Vector(
            v1.y * v2.z - v1.z * v2.y,
            v1.z * v2.x - v1.x * v2.z,
            v1.x * v2.y - v1.y * v2.x);
    }
}

class Color
{
    public double r;
    public double g;
    public double b;

    public static Color white = new Color(1.0, 1.0, 1.0);
    public static Color grey = new Color(0.5, 0.5, 0.5);
    public static Color black = new Color(0.0, 0.0, 0.0);
    public static Color background = Color.black;
    public static Color defaultcolor = Color.black;

    public Color(double r, double g, double b)
    {
        this.r = r;
        this.g = g;
        this.b = b;
    }

    public static Color operator *(double k, Color v)
    {
        return new Color(k * v.r, k * v.g, k * v.b);
    }

    public static Color operator +(Color v1, Color v2)
    {
        return new Color(v1.r + v2.r, v1.g + v2.g, v1.b + v2.b);
    }

    public static Color operator *(Color v1, Color v2)
    {
        return new Color(v1.r * v2.r, v1.g * v2.g, v1.b * v2.b);
    }

    public static System.Drawing.Color ToDrawingColor(Color c)
    {
        return System.Drawing.Color.FromArgb(Clamp(c.r), Clamp(c.g), Clamp(c.b));
    }

    public static byte Clamp(double c)
    {
        if (c > 1.0) return (byte)255;
        if (c < 0.0) return (byte)0;
        return (byte)(c * 255);
    }
}

class Camera
{
    public Vector forward;
    public Vector right;
    public Vector up;

    public Vector pos;
    public Camera(Vector pos, Vector lookAt)
    {
        var down = new Vector(0.0, -1.0, 0.0);
        this.pos = pos;
        this.forward = Vector.norm(lookAt - this.pos);
        this.right = 1.5 * Vector.norm(Vector.cross(this.forward, down));
        this.up = 1.5 * Vector.norm(Vector.cross(this.forward, this.right));
    }
}

class Ray
{
    public Vector start;
    public Vector dir;

    public Ray(Vector start, Vector dir)
    {
        this.start = start;
        this.dir = dir;
    }
}

class Intersection
{
    public Thing thing;
    public Ray ray;
    public double dist;

    public Intersection(Thing thing, Ray ray, double dist)
    {
        this.thing = thing;
        this.ray = ray;
        this.dist = dist;
    }
}

interface Surface
{
    Color diffuse(Vector pos);
    Color specular(Vector pos);
    double reflect(Vector pos);
    double roughness { get; set; }
}

interface Thing
{
    Intersection intersect(Ray ray);
    Vector normal(Vector pos);
    Surface surface { get; set; }
}

class Light
{
    public Vector pos;

    public Color color;
    public Light(Vector pos, Color color)
    {
        this.pos = pos;
        this.color = color;
    }
}

interface Scene
{
    List<Thing> things();
    List<Light> lights();
    Camera camera { get; set; }
}

class Sphere : Thing
{

    private double radius2;

    private Vector center;
    public Sphere(Vector center, double radius, Surface surface)
    {
        this.radius2 = radius * radius;
        this.surface = surface;
        this.center = center;
    }

    public Intersection intersect(Ray ray)
    {
        var eo = (this.center - ray.start);
        var v = Vector.dot(eo, ray.dir);
        var dist = 0.0;

        if (v >= 0) {
            var disc = this.radius2 - (Vector.dot(eo, eo) - v * v);
            if (disc >= 0) {
                dist = v - Math.Sqrt(disc);
            }
        }

        if (dist == 0)
            return null;

        return new Intersection(this, ray, dist);
    }

    public Vector normal(Vector pos)
    {
        return Vector.norm(pos - this.center);
    }

    public Surface surface { get; set; }
}

class Plane : Thing
{
    private Vector _normal;

    private double _offset;
    public Plane(Vector norm, double offset, Surface surface)
    {
        this._normal = norm;
        this._offset = offset;
        this.surface = surface;
    }

    public Intersection intersect(Ray ray)
    {
        var denom = Vector.dot(this._normal, ray.dir);
        if ((denom > 0))
            return null;

        var dist = (Vector.dot(this._normal, ray.start) + this._offset) / (-denom);
        return new Intersection(this, ray, dist);
    }

    public Vector normal(Vector pos)
    {
        return this._normal;
    }

    public Surface surface { get; set; }
}

class ShinySurface : Surface
{
    public ShinySurface()
    {
        roughness = 250.0;
    }

    public Color diffuse(Vector pos)
    {
        return Color.white;
    }

    public double reflect(Vector pos)
    {
        return 0.7;
    }

    public double roughness { get; set; }

    public Color specular(Vector pos)
    {
        return Color.grey;
    }
}

class CheckerboardSurface : Surface
{
    public CheckerboardSurface()
    {
        roughness = 150.0;
    }
    public Color diffuse(Vector pos)
    {
        if ((Math.Floor(pos.z) + Math.Floor(pos.x)) % 2 != 0) {
            return Color.white;
        } else {
            return Color.black;
        }
    }

    public double reflect(Vector pos)
    {
        if ((Math.Floor(pos.z) + Math.Floor(pos.x)) % 2 != 0) {
            return 0.1;
        } else {
            return 0.7;
        }
    }

    public double roughness { get; set; }

    public Color specular(Vector pos)
    {
        return Color.white;
    }
}

class Surfaces
{
    public static Surface shiny = new ShinySurface();
    public static Surface checkerboard = new CheckerboardSurface();
}

class DefaultScene : Scene
{
    public Camera camera { get; set; }

    private List<Light> _lights = new List<Light>();
    private List<Thing> _things = new List<Thing>();

    public DefaultScene()
    {
        this.camera = new Camera(new Vector(3.0, 2.0, 4.0), new Vector(-1.0, 0.5, 0.0));

        _things.Add(new Plane(new Vector(0.0, 1.0, 0.0), 0.0, Surfaces.checkerboard));
        _things.Add(new Sphere(new Vector(0.0, 1.0, -0.25), 1.0, Surfaces.shiny));
        _things.Add(new Sphere(new Vector(-1.0, 0.5, 1.5), 0.5, Surfaces.shiny));

        _lights.Add(new Light(new Vector(-2.0, 2.5, 0.0), new Color(0.49, 0.07, 0.07)));
        _lights.Add(new Light(new Vector(1.5, 2.5, 1.5), new Color(0.07, 0.07, 0.49)));
        _lights.Add(new Light(new Vector(1.5, 2.5, -1.5), new Color(0.07, 0.49, 0.071)));
        _lights.Add(new Light(new Vector(0.0, 3.5, 0.0), new Color(0.21, 0.21, 0.35)));
    }

    public List<Light> lights()
    {
        return _lights;
    }

    public List<Thing> things()
    {
        return _things;
    }
}

class RayTracerEngine
{

    private int maxDepth = 5;
    private Intersection intersections(Ray ray, Scene scene)
    {
        var closest = double.PositiveInfinity;
        Intersection closestInter = null;

        foreach (Thing item in scene.things()) {
            var inter = item.intersect(ray);
            if (inter != null && inter.dist < closest) {
                closestInter = inter;
                closest = inter.dist;
            }
        }
        return closestInter;

    }

    private double testRay(Ray ray, Scene scene)
    {
        Intersection isect = this.intersections(ray, scene);
        if (isect != null) {
            return isect.dist;
        } else {
            return double.NaN;
        }
    }

    private Color traceRay(Ray ray, Scene scene, int depth)
    {
        Intersection isect = this.intersections(ray, scene);
        if (isect == null)
            return Color.background;
        return this.shade(isect, scene, depth);
    }

    private Color shade(Intersection isect, Scene scene, int depth)
    {
        Vector d = isect.ray.dir;

        var pos = (isect.dist * d) + isect.ray.start;
        var normal = isect.thing.normal(pos);
        var reflectDir = d - (2 * Vector.dot(normal, d) * normal);

        var naturalColor = Color.background + this.getNaturalColor(isect.thing, pos, normal, reflectDir, scene);

        var reflectedColor = depth >= this.maxDepth ? Color.grey : this.getReflectionColor(isect.thing, pos, normal, reflectDir, scene, depth);
        return naturalColor + reflectedColor;
    }

    private Color getReflectionColor(Thing thing, Vector pos, Vector normal, Vector rd, Scene scene, int depth)
    {
        return thing.surface.reflect(pos) * this.traceRay(new Ray(pos, rd), scene, depth + 1);
    }


    private Color getNaturalColor(Thing thing, Vector pos, Vector norm, Vector rd, Scene scene)
    {

        Color c = Color.defaultcolor;
        foreach (Light item in scene.lights()) {
            c = this.addLight(c, item, pos, scene, norm, rd, thing);
        }
        return c;
    }

    private Color addLight(Color col, Light light, Vector pos, Scene scene, Vector norm, Vector rd, Thing thing)
    {
        var ldis = light.pos - pos;
        var livec = Vector.norm(ldis);
        var neatIsect = this.testRay(new Ray(pos, livec), scene);

        var isInShadow = double.IsNaN(neatIsect) ? false : (neatIsect <= Vector.mag(ldis));
        if (isInShadow)
            return col;

        var illum = Vector.dot(livec, norm);
        var lcolor = (illum > 0) ? illum * light.color : Color.defaultcolor;

        var specular = Vector.dot(livec, Vector.norm(rd));
        var scolor = specular > 0 ? (Math.Pow(specular, thing.surface.roughness) * light.color) : Color.defaultcolor;

        return col + (thing.surface.diffuse(pos) * lcolor) + (thing.surface.specular(pos) * scolor);
    }


    public delegate Vector GetPointDelegate(int x, int y, Camera camera);

    public void render(Scene scene, System.Drawing.Bitmap bmp)
    {
        int w = bmp.Width;
        int h = bmp.Height;
        GetPointDelegate getPoint = (int x, int y, Camera camera) =>
        {
            var recenterX = (x - (w / 2.0)) / 2.0 / w;
            var recenterY = -(y - (h / 2.0)) / 2.0 / h;
            return Vector.norm(camera.forward + (recenterX * camera.right) + (recenterY * camera.up));
        };

        BitmapData bitmapData = bmp.LockBits(new  System.Drawing.Rectangle(0, 0, w, h), ImageLockMode.ReadWrite, bmp.PixelFormat);

        unsafe
        {
            int PixelSize = 4;
            for (var y = 0; y < h ; ++y)
            {
                byte* row = (byte*)bitmapData.Scan0 + (y * bitmapData.Stride);

                for (var x = 0; x < w ; ++x)
                {
                    var color = this.traceRay(new Ray(scene.camera.pos, getPoint(x, y, scene.camera)), scene, 0);
                    var c = Color.ToDrawingColor(color);

                    row[x * PixelSize + 0] = c.B;
                    row[x * PixelSize + 1] = c.G;
                    row[x * PixelSize + 2] = c.R;
                    row[x * PixelSize + 3] = 255;
                }
            }
        }
        bmp.UnlockBits(bitmapData);
    }
}