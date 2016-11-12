
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
        var rayTracer = new RayTracerEngine();
        var scene = new DefaultScene();
        rayTracer.Render(scene, bmp);
        sw.Stop();
        bmp.Save("csharp-ray-tracer.png");

        Console.WriteLine("");
        Console.WriteLine("Total time: " + sw.ElapsedMilliseconds.ToString() + " ms");
        Console.ReadLine();
    }
}

class Vector
{
    public double X;
    public double Y;
    public double Z;

    public Vector(double x, double y, double z)
    {
        X = x;
        Y = y;
        Z = z;
    }

    public static Vector operator -(Vector v1, Vector v2) => new Vector(v1.X - v2.X, v1.Y - v2.Y, v1.Z - v2.Z);

    public static double Dot(Vector v1, Vector v2) => v1.X * v2.X + v1.Y * v2.Y + v1.Z * v2.Z;

    public static double Mag(Vector v) => Math.Sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z);

    public static Vector operator +(Vector v1, Vector v2) => new Vector(v1.X + v2.X, v1.Y + v2.Y, v1.Z + v2.Z);

    public static Vector operator *(double k, Vector v) => new Vector(k * v.X, k * v.Y, k * v.Z);

    public static Vector Norm(Vector v)
    {
        var mag = Mag(v);
        var div = (mag == 0) ? double.PositiveInfinity : 1.0 / mag;
        return div * v;
    }

    public static Vector Cross(Vector v1, Vector v2) => new Vector(
        v1.Y * v2.Z - v1.Z * v2.Y,
        v1.Z * v2.X - v1.X * v2.Z,
        v1.X * v2.Y - v1.Y * v2.X);
}

class Color
{
    public double R;
    public double G;
    public double B;

    public static Color White = new Color(1.0, 1.0, 1.0);
    public static Color Grey = new Color(0.5, 0.5, 0.5);
    public static Color Black = new Color(0.0, 0.0, 0.0);
    public static Color Background = Color.Black;
    public static Color Defaultcolor = Color.Black;

    public Color(double r, double g, double b)
    {
        R = r;
        G = g;
        B = b;
    }

    public static Color operator *(double k, Color v)
    {
        return new Color(k * v.R, k * v.G, k * v.B);
    }

    public static Color operator +(Color a, Color b) => new Color(a.R + b.R, a.G + b.G, a.B + b.B);

    public static Color operator *(Color a, Color b) => new Color(a.R * b.R, a.G * b.G, a.B * b.B);

    public static System.Drawing.Color ToDrawingColor(Color c) => System.Drawing.Color.FromArgb(Clamp(c.R), Clamp(c.G), Clamp(c.B));

    public static byte Clamp(double c)
    {
        if (c > 1.0) return 255;
        if (c < 0.0) return 0;
        return (byte)(c * 255);
    }
}

class Camera
{
    public Vector Forward;
    public Vector Right;
    public Vector Up;
    public Vector Pos;

    public Camera(Vector pos, Vector lookAt)
    {
        var down = new Vector(0.0, -1.0, 0.0);
        Pos = pos;
        Forward = Vector.Norm(lookAt - Pos);
        Right = 1.5 * Vector.Norm(Vector.Cross(Forward, down));
        Up = 1.5 * Vector.Norm(Vector.Cross(Forward, Right));
    }
}

class Ray
{
    public Vector Start;
    public Vector Dir;

    public Ray(Vector start, Vector dir)
    {
        Start = start;
        Dir = dir;
    }
}

class Intersection
{
    public IThing Thing;
    public Ray Ray;
    public double Dist;

    public Intersection(IThing thing, Ray ray, double dist)
    {
        Thing = thing;
        Ray = ray;
        Dist = dist;
    }
}

interface ISurface
{
    Color Diffuse(Vector pos);
    Color Specular(Vector pos);
    double Reflect(Vector pos);
    double Roughness { get; set; }
}

interface IThing
{
    Intersection Intersect(Ray ray);
    Vector Normal(Vector pos);
    ISurface Surface { get; set; }
}

class Light
{
    public Vector Pos;
    public Color Color;

    public Light(Vector pos, Color color)
    {
        Pos = pos;
        Color = color;
    }
}

interface IScene
{
    List<IThing> Things();
    List<Light> Lights();
    Camera Camera { get; set; }
}

class Sphere : IThing
{
    private readonly double m_Radius2;
    private readonly Vector m_Center;

    public Sphere(Vector center, double radius, ISurface surface)
    {
        m_Radius2 = radius * radius;
        Surface = surface;
        m_Center = center;
    }

    public Intersection Intersect(Ray ray)
    {
        var eo = (m_Center - ray.Start);
        var v = Vector.Dot(eo, ray.Dir);
        var dist = 0.0;

        if (v >= 0) {
            var disc = m_Radius2 - (Vector.Dot(eo, eo) - v * v);
            if (disc >= 0) {
                dist = v - Math.Sqrt(disc);
            }
        }

        return dist == 0 ? null : new Intersection(this, ray, dist);
    }

    public Vector Normal(Vector pos) => Vector.Norm(pos - m_Center);

    public ISurface Surface { get; set; }
}

class Plane : IThing
{
    private readonly Vector m_Normal;
    private readonly double m_Offset;

    public Plane(Vector norm, double offset, ISurface surface)
    {
        m_Normal = norm;
        m_Offset = offset;
        Surface = surface;
    }

    public Intersection Intersect(Ray ray)
    {
        var denom = Vector.Dot(m_Normal, ray.Dir);
        if (denom > 0)
            return null;

        var dist = (Vector.Dot(m_Normal, ray.Start) + m_Offset) / (-denom);
        return new Intersection(this, ray, dist);
    }

    public Vector Normal(Vector pos) => m_Normal;

    public ISurface Surface { get; set; }
}

class ShinySurface : ISurface
{
    public Color Diffuse(Vector pos) => Color.White;

    public double Reflect(Vector pos) => 0.7;

    public double Roughness { get; set; } = 250.0;

    public Color Specular(Vector pos) => Color.Grey;
}

class CheckerboardSurface : ISurface
{
  
    public Color Diffuse(Vector pos) => (Math.Floor(pos.Z) + Math.Floor(pos.X)) % 2 != 0 ? Color.White : Color.Black;

    public double Reflect(Vector pos) => (Math.Floor(pos.Z) + Math.Floor(pos.X)) % 2 != 0 ? 0.1 : 0.7;

    public double Roughness { get; set; } = 150.0;

    public Color Specular(Vector pos) => Color.White;
}

class Surfaces
{
    public static ISurface Shiny = new ShinySurface();
    public static ISurface Checkerboard = new CheckerboardSurface();
}

class DefaultScene : IScene
{
    public Camera Camera { get; set; }

    private readonly List<Light> m_Lights = new List<Light>();
    private readonly List<IThing> m_Things = new List<IThing>();

    public DefaultScene()
    {
        Camera = new Camera(new Vector(3.0, 2.0, 4.0), new Vector(-1.0, 0.5, 0.0));

        m_Things.Add(new Plane(new Vector(0.0, 1.0, 0.0), 0.0, Surfaces.Checkerboard));
        m_Things.Add(new Sphere(new Vector(0.0, 1.0, -0.25), 1.0, Surfaces.Shiny));
        m_Things.Add(new Sphere(new Vector(-1.0, 0.5, 1.5), 0.5, Surfaces.Shiny));

        m_Lights.Add(new Light(new Vector(-2.0, 2.5, 0.0), new Color(0.49, 0.07, 0.07)));
        m_Lights.Add(new Light(new Vector(1.5, 2.5, 1.5), new Color(0.07, 0.07, 0.49)));
        m_Lights.Add(new Light(new Vector(1.5, 2.5, -1.5), new Color(0.07, 0.49, 0.071)));
        m_Lights.Add(new Light(new Vector(0.0, 3.5, 0.0), new Color(0.21, 0.21, 0.35)));
    }

    public List<Light> Lights() => m_Lights;

    public List<IThing> Things() => m_Things;
}

class RayTracerEngine
{
    private readonly int m_MaxDepth = 5;
    private Intersection Intersections(Ray ray, IScene scene)
    {
        var closest = double.PositiveInfinity;
        Intersection closestInter = null;

        foreach (IThing item in scene.Things()) {
            var inter = item.Intersect(ray);
            if (inter == null || !(inter.Dist < closest)) continue;
            closestInter = inter;
            closest = inter.Dist;
        }
        return closestInter;

    }

    private double TestRay(Ray ray, IScene scene)
    {
        Intersection isect = Intersections(ray, scene);
        return isect?.Dist ?? double.NaN;
    }

    private Color TraceRay(Ray ray, IScene scene, int depth)
    {
        var isect = Intersections(ray, scene);
        return isect == null ? Color.Background : Shade(isect, scene, depth);
    }

    private Color Shade(Intersection isect, IScene scene, int depth)
    {
        Vector d = isect.Ray.Dir;

        var pos = (isect.Dist * d) + isect.Ray.Start;
        var normal = isect.Thing.Normal(pos);
        var reflectDir = d - (2 * Vector.Dot(normal, d) * normal);

        var naturalColor = Color.Background + GetNaturalColor(isect.Thing, pos, normal, reflectDir, scene);

        var reflectedColor = depth >= m_MaxDepth ? Color.Grey : GetReflectionColor(isect.Thing, pos, normal, reflectDir, scene, depth);
        return naturalColor + reflectedColor;
    }

    private Color GetReflectionColor(IThing thing, Vector pos, Vector normal, Vector rd, IScene scene, int depth)
    {
        return thing.Surface.Reflect(pos) * TraceRay(new Ray(pos, rd), scene, depth + 1);
    }


    private Color GetNaturalColor(IThing thing, Vector pos, Vector norm, Vector rd, IScene scene)
    {
        var c = Color.Defaultcolor;
        foreach (var item in scene.Lights()) 
        {
            var newColor = AddLight(c, item, pos, scene, norm, rd, thing);
            c = newColor;
        }
        return c;
    }

    private Color AddLight(Color col, Light light, Vector pos, IScene scene, Vector norm, Vector rd, IThing thing)
    {
        var ldis = light.Pos - pos;
        var livec = Vector.Norm(ldis);
        var neatIsect = TestRay(new Ray(pos, livec), scene);

        var isInShadow = !double.IsNaN(neatIsect) && (neatIsect <= Vector.Mag(ldis));
        if (isInShadow)
        {
            return col;
        }
        var illum = Vector.Dot(livec, norm);
        var lcolor = (illum > 0) ? illum * light.Color : Color.Defaultcolor;

        var specular = Vector.Dot(livec, Vector.Norm(rd));
        var scolor = specular > 0 ? (Math.Pow(specular, thing.Surface.Roughness) * light.Color) : Color.Defaultcolor;

        return col + (thing.Surface.Diffuse(pos) * lcolor) + (thing.Surface.Specular(pos) * scolor);
    }


    public delegate Vector GetPointDelegate(int x, int y, Camera camera);

    public void Render(IScene scene, System.Drawing.Bitmap bmp)
    {
        int w = bmp.Width;
        int h = bmp.Height;
        
        GetPointDelegate getPoint = (int x, int y, Camera camera) =>
        {
            var recenterX = (x - (w / 2.0)) / 2.0 / w;
            var recenterY = -(y - (h / 2.0)) / 2.0 / h;
            return Vector.Norm(camera.Forward + (recenterX * camera.Right) + (recenterY * camera.Up));
        };

        BitmapData bitmapData = bmp.LockBits(new  System.Drawing.Rectangle(0, 0, w, h), ImageLockMode.ReadWrite, bmp.PixelFormat);

        unsafe
        {
            var pixelSize = 4;
            for (var y = 0; y < h ; ++y)
            {
                byte* row = (byte*)bitmapData.Scan0 + (y * bitmapData.Stride);

                for (var x = 0; x < w ; ++x)
                {
                    var color = TraceRay(new Ray(scene.Camera.Pos, getPoint(x, y, scene.Camera)), scene, 0);
                    var c = Color.ToDrawingColor(color);

                    row[x * pixelSize + 0] = c.B;
                    row[x * pixelSize + 1] = c.G;
                    row[x * pixelSize + 2] = c.R;
                    row[x * pixelSize + 3] = 255;
                }
            }
        }
        bmp.UnlockBits(bitmapData);
    }
}