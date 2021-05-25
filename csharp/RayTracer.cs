using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;

internal class Program
{
    private static void Main(string[] args)
    {
        var image = new Image(500, 500);
        Stopwatch sw = new Stopwatch();
        sw.Start();
        var rayTracer = new RayTracerEngine();
        var scene = new Scene();
        rayTracer.Render(scene, image);
        sw.Stop();
        image.Save("csharp-ray.bmp");
        Console.WriteLine("Completed in " + sw.ElapsedMilliseconds.ToString() + " ms");
    }
}

internal class Image
{
    private RGBColor[] data;
    public int Width { get; private set; }
    public int Height { get; private set; }

    [StructLayout(LayoutKind.Sequential)]
    private struct BITMAPINFOHEADER
    {
        public uint biSize;
        public int biWidth;
        public int biHeight;
        public ushort biPlanes;
        public ushort biBitCount;
        public uint biCompression;
        public uint biSizeImage;
        public int biXPelsPerMeter;
        public int biYPelsPerMeter;
        public uint biClrUsed;
        public uint biClrImportant;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 2)]
    private struct BITMAPFILEHEADER
    {
        public ushort bfType;
        public uint bfSize;
        public ushort bfReserved1;
        public ushort bfReserved2;
        public uint bfOffBits;
    }

    public Image(int width, int height)
    {
        this.Width = width;
        this.Height = height;
        this.data = new RGBColor[(width * height)];
    }

    public RGBColor this[int index]
    {
        get { return data[index]; }
        set { data[index] = value; }
    }

    public void Save(string fileName)
    {
        var infoHeaderSize = Marshal.SizeOf(typeof(BITMAPINFOHEADER));
        var fileHeaderSize = Marshal.SizeOf(typeof(BITMAPFILEHEADER));
        var offBits = infoHeaderSize + fileHeaderSize;

        BITMAPINFOHEADER infoHeader = new BITMAPINFOHEADER
        {
            biSize = (uint)infoHeaderSize,
            biBitCount = 32,
            biClrImportant = 0,
            biClrUsed = 0,
            biCompression = 0,
            biHeight = -Height,
            biWidth = Width,
            biPlanes = 1,
            biSizeImage = (uint)(Width * Height * 4)
        };

        BITMAPFILEHEADER fileHeader = new BITMAPFILEHEADER
        {
            bfType = 'B' + ('M' << 8),
            bfOffBits = (uint)offBits,
            bfSize = (uint)(offBits + infoHeader.biSizeImage)
        };

        using (var writer = new BinaryWriter(File.Open(fileName, FileMode.Create)))
        {
            writer.Write(GetBytes(fileHeader));
            writer.Write(GetBytes(infoHeader));
            foreach (var color in data)
            {
                writer.Write(color.B);
                writer.Write(color.G);
                writer.Write(color.R);
                writer.Write(color.A);
            }
        }
    }

    public byte[] GetBytes<T>(T data)
    {
        var length = Marshal.SizeOf(data);
        var ptr = Marshal.AllocHGlobal(length);
        var result = new byte[length];
        Marshal.StructureToPtr(data, ptr, true);
        Marshal.Copy(ptr, result, 0, length);
        Marshal.FreeHGlobal(ptr);
        return result;
    }
}

internal struct Vector
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

    public double Dot(Vector v) => X * v.X + Y * v.Y + Z * v.Z;

    public double Length() => Math.Sqrt(X * X + Y * Y + Z * Z);

    public static Vector operator -(Vector a, Vector b) => new Vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z);

    public static Vector operator +(Vector a, Vector b) => new Vector(a.X + b.X, a.Y + b.Y, a.Z + b.Z);

    public static Vector operator *(double k, Vector v) => new Vector(k * v.X, k * v.Y, k * v.Z);

    public Vector Norm()
    {
        var length = this.Length();
        var div = (length == 0) ? double.PositiveInfinity : 1.0 / length;
        return div * this;
    }

    public Vector Cross(Vector v)
    {
        return new Vector(
            Y * v.Z - Z * v.Y,
            Z * v.X - X * v.Z,
            X * v.Y - Y * v.X
        );
    }
}

internal struct RGBColor
{
    public byte B;
    public byte G;
    public byte R;
    public byte A;
}

internal struct Color
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

    public static Color operator *(double k, Color v) => new Color(k * v.R, k * v.G, k * v.B);

    public static Color operator +(Color a, Color b) => new Color(a.R + b.R, a.G + b.G, a.B + b.B);

    public static Color operator *(Color a, Color b) => new Color(a.R * b.R, a.G * b.G, a.B * b.B);

    public RGBColor ToRGBColor()
    {
        return new RGBColor
        {
            B = Clamp(this.B),
            G = Clamp(this.G),
            R = Clamp(this.R),
            A = 255
        };
    }

    public static byte Clamp(double c)
    {
        if (c > 1.0) return 255;
        if (c < 0.0) return 0;
        return (byte)(c * 255);
    }
}

internal class Camera
{
    public Vector Forward;
    public Vector Right;
    public Vector Up;
    public Vector Pos;

    public Camera(Vector pos, Vector lookAt)
    {
        var down = new Vector(0.0, -1.0, 0.0);
        Pos = pos;
        Forward = (lookAt - Pos).Norm();
        Right = 1.5 * Forward.Cross(down).Norm();
        Up = 1.5 * Forward.Cross(Right).Norm();
    }

    public Vector GetPoint(int x, int y, int w, int h)
    {
        var recenterX = (x - (w / 2.0)) / 2.0 / w;
        var recenterY = -(y - (h / 2.0)) / 2.0 / h;
        return (this.Forward + (recenterX * this.Right) + (recenterY * this.Up)).Norm();
    }
}

internal class Ray
{
    public Vector Start;
    public Vector Dir;

    public Ray(Vector start, Vector dir)
    {
        Start = start;
        Dir = dir;
    }
}

internal class Intersection
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

internal struct SurfaceProperties
{
    public Color Diffuse;
    public Color Specular;
    public double Reflect;
    public double Roughness;
}

internal interface ISurface
{
    SurfaceProperties GetSurfaceProperties(Vector pos);
}

internal interface IThing
{
    Intersection Intersect(Ray ray);

    Vector Normal(Vector pos);

    ISurface Surface { get; set; }
}

internal struct Light
{
    public Vector Pos;
    public Color Color;

    public Light(Vector pos, Color color)
    {
        Pos = pos;
        Color = color;
    }
}

internal class Sphere : IThing
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
        var v = eo.Dot(ray.Dir);
        var dist = 0.0;

        if (v >= 0)
        {
            var disc = m_Radius2 - (eo.Dot(eo) - v * v);
            if (disc >= 0)
            {
                dist = v - Math.Sqrt(disc);
            }
        }

        return dist == 0.0 ? null : new Intersection(this, ray, dist);
    }

    public Vector Normal(Vector pos) => (pos - m_Center).Norm();

    public ISurface Surface { get; set; }
}

internal class Plane : IThing
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
        var denom = m_Normal.Dot(ray.Dir);
        if (denom > 0)
        {
            return null;
        }

        var dist = (m_Normal.Dot(ray.Start) + m_Offset) / (-denom);
        return new Intersection(this, ray, dist);
    }

    public Vector Normal(Vector pos) => m_Normal;

    public ISurface Surface { get; set; }
}

internal class ShinySurface : ISurface
{
    public SurfaceProperties GetSurfaceProperties(Vector pos)
    {
        return new SurfaceProperties()
        {
            Diffuse = Color.White,
            Specular = Color.Grey,
            Reflect = 0.7,
            Roughness = 250
        };
    }
}

internal class CheckerboardSurface : ISurface
{
    public SurfaceProperties GetSurfaceProperties(Vector pos)
    {
        var condition = (Math.Floor(pos.Z) + Math.Floor(pos.X)) % 2 != 0;
        var color = condition ? Color.White : Color.Black;
        var reflect = condition ? 0.1 : 0.7;

        return new SurfaceProperties()
        {
            Diffuse = color,
            Specular = Color.White,
            Reflect = reflect,
            Roughness = 250
        };
    }
}

internal class Scene
{
    public Camera Camera { get; set; }
    public readonly Light[] Lights;
    public readonly IThing[] Things;

    public static ISurface Shiny = new ShinySurface();
    public static ISurface Checkerboard = new CheckerboardSurface();

    public Scene()
    {
        Camera = new Camera(new Vector(3.0, 2.0, 4.0), new Vector(-1.0, 0.5, 0.0));

        Things = new IThing[] {
            new Plane(new Vector(0.0, 1.0, 0.0), 0.0, Checkerboard),
            new Sphere(new Vector(0.0, 1.0, -0.25), 1.0, Shiny),
            new Sphere(new Vector(-1.0, 0.5, 1.5), 0.5, Shiny)
        };

        Lights = new Light[] {
            new Light(new Vector(-2.0, 2.5, 0.0), new Color(0.49, 0.07, 0.07)),
            new Light(new Vector(1.5, 2.5, 1.5), new Color(0.07, 0.07, 0.49)),
            new Light(new Vector(1.5, 2.5, -1.5), new Color(0.07, 0.49, 0.071)),
            new Light(new Vector(0.0, 3.5, 0.0), new Color(0.21, 0.21, 0.35))
        };
    }
}

internal class RayTracerEngine
{
    private const int maxDepth = 5;
    private Scene scene;

    private Intersection Intersections(Ray ray)
    {
        var closest = double.PositiveInfinity;
        Intersection closestInter = null;

        for (int i = 0; i < scene.Things.Length; ++i)
        {
            var inter = scene.Things[i].Intersect(ray);
            if (inter != null && inter.Dist < closest)
            {
                closestInter = inter;
                closest = inter.Dist;
            }
        }

        return closestInter;
    }

    private Color TraceRay(Ray ray, int depth)
    {
        var isect = Intersections(ray);
        return isect != null ? Shade(isect, depth) : Color.Background;
    }

    private Color Shade(Intersection isect, int depth)
    {
        Vector d = isect.Ray.Dir;

        var pos = (isect.Dist * d) + isect.Ray.Start;
        var normal = isect.Thing.Normal(pos);
        var reflectDir = d - (2 * normal.Dot(d) * normal);

        var surface = isect.Thing.Surface.GetSurfaceProperties(pos);
        var naturalColor = Color.Background + GetNaturalColor();

        var reflectedColor = depth >= maxDepth ? Color.Grey : GetReflectionColor();
        return naturalColor + reflectedColor;

        Color GetReflectionColor()
        {
            return surface.Reflect * TraceRay(new Ray(pos, reflectDir), depth + 1);
        }

        Color GetNaturalColor()
        {
            var result = Color.Defaultcolor;
            for (int i = 0; i < scene.Lights.Length; ++i)
            {
                result = AddLight(result, scene.Lights[i]);
            }
            return result;
        }

        Color AddLight(Color col, Light light)
        {
            var ldis = light.Pos - pos;
            var livec = ldis.Norm();
            var neatIsect = Intersections(new Ray(pos, livec));

            var isInShadow = (neatIsect != null) && (neatIsect.Dist <= ldis.Length());
            if (isInShadow)
            {
                return col;
            }
            var illum = livec.Dot(normal);
            var lcolor = (illum > 0) ? illum * light.Color : Color.Defaultcolor;

            var specular = livec.Dot(reflectDir.Norm());
            var scolor = specular > 0 ? (Math.Pow(specular, surface.Roughness) * light.Color) : Color.Defaultcolor;

            return col + (surface.Diffuse * lcolor) + (surface.Specular * scolor);
        }
    }

    public void Render(Scene scene, Image image)
    {
        this.scene = scene;
        int w = image.Width;
        int h = image.Height;
        Ray ray = new Ray(scene.Camera.Pos, new Vector(0, 0, 0));

        for (var y = 0; y < h; ++y)
        {
            int pos = y * h;
            for (var x = 0; x < w; ++x)
            {
                ray.Dir = scene.Camera.GetPoint(x, y, w, h);
                var color = TraceRay(ray, 0);
                image[pos + x] = color.ToRGBColor();
            }
        }
    }
}