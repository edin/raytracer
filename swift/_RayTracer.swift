struct Vector
{
    var X: Double
    var Y: Double
    var Z: Double

    func Dot(v: Vector) -> Double {
        return X * v.X + Y * v.Y + Z * v.Z
    }

    func Length() -> Double {
        return (X * X + Y * Y + Z * Z).squareRoot()
    }

    static func -(a: Vector, b: Vector) -> Vector {
        return Vector(X: a.X - b.X, Y: a.Y - b.Y, Z: a.Z - b.Z)
    }

    static func +(a: Vector, b: Vector) -> Vector {
        return Vector(X: a.X + b.X, Y: a.Y + b.Y, Z: a.Z + b.Z)
    }

    static func *(k: Double, v: Vector) -> Vector {
        return Vector(X: k * v.X, Y: k * v.Y, Z: k * v.Z)
    }

    func Norm() -> Vector
    {
        let length = self.Length()
        let div = (length == 0) ? Double.infinity : 1.0 / length
        return div * self
    }

    func Cross(v: Vector) -> Vector
    {
        return Vector(
            X: Y * v.Z - Z * v.Y,
            Y: Z * v.X - X * v.Z,
            Z: X * v.Y - Y * v.X
        )
    }
}

struct RGBColor {
    var B: UInt8
    var G: UInt8
    var R: UInt8
    var A: UInt8
}

struct Color
{
    var R: Double
    var G: Double
    var B: Double

    let White = Color(R: 1.0, G: 1.0, B: 1.0)
    let Grey  = Color(R: 0.5, G: 0.5, B: 0.5)
    let Black = Color(R: 0.0, G: 0.0, B: 0.0)
    let Background = Color.Black
    let Defaultcolor = Color.Black

    static func *(k: Double, v: Color) -> Color {
        return Color(k * v.R, k * v.G, k * v.B)
    }

    static func +(a: Color, b: Color) -> Color {
        return Color(a.R + b.R, a.G + b.G, a.B + b.B)
    }

    static func *(a: Color, b: Color) -> Color {
        return Color(a.R * b.R, a.G * b.G, a.B * b.B)
    }

    func ToDrawingColor() -> RGBColor {
        return RGBColor(Clamp(B), Clamp(G), Clamp(R), 255)
    }

    func Clamp(c: Double) -> UInt8
    {
        if (c > 1.0) return 255
        if (c < 0.0) return 0
        return (UInt8)(c * 255)
    }
}

struct Camera
{
    var Forward: Vector
    var Right: Vector
    var Up: Vector
    var Pos: Vector

    init(pos: Vector, lookAt: Vector) -> Camera
    {
        var down = Vector(R:0.0, G:-1.0, B:0.0)
        Pos = pos
        Forward = (lookAt - Pos).Norm()
        Right = 1.5 * Forward.Cross(down).Norm()
        Up = 1.5 * Forward.Cross(Right).Norm()
    }

    func GetPoint(x: Int, y: Int, w: Int, h: Int)
    {
        var recenterX = (x - (w / 2.0)) / 2.0 / w
        var recenterY = -(y - (h / 2.0)) / 2.0 / h
        return (self.Forward + (recenterX * self.Right) + (recenterY * self.Up)).Norm()
    }

}

struct Ray
{
    var Start: Vector
    var Dir: Vector
}

class Intersection
{
    var Thing: IThing
    var Ray: Ray
    var Dist: Double
}

protocol ISurface
{
    func Diffuse(pos: Vector)   -> Color
    func Specular(pos: Vector)  -> Color
    func Roughness(pos: Vector) -> Double
    func Reflect(pos: Vector )  -> Double
}

protocol IThing
{
    func Surface() -> ISurface
    func Intersect(ray: Ray) -> Intersection
    func Normal(pos: Vector) -> Vector
}

struct Light
{
    var Pos: Vector
    var Color: Color
}

class Sphere : IThing
{
    var m_Radius2: Double
    var m_Center: Vector
    var m_Surface: ISurface

    init (center: Vector, radius: Double, surface: ISurface) -> Sphere
    {
        m_Radius2 = radius * radius
        m_Surface = surface
        m_Center = center
    }

    func Intersect(ray: Ray) -> Intersection
    {
        var eo = (m_Center - ray.Start)
        var v = eo.Dot(ray.Dir)
        var dist = 0.0

        if (v >= 0)
        {
            var disc = m_Radius2 - (eo.Dot(eo) - v * v)
            if (disc >= 0)
            {
                dist = v - disc.squareRoot()
            }
        }
        return dist == 0 ? default : Intersection(this, ray, dist)
    }

    func Normal(pos: Vector) -> Vector {
        return (pos - m_Center).Norm()
    }

    ISurface Surface { get set }
}

class Plane : IThing
{
    var m_Normal: Vector
    var m_Offset: Double
    var m_Surface: ISurface

    init Plane(norm: Vector, offset: Double, surface: ISurface)
    {
        m_Normal = norm
        m_Offset = offset
        m_Surface = surface
    }

    init Intersect(ray: Ray) -> Intersection
    {
        var denom = m_Normal.Dot(ray.Dir)
        if (denom > 0) {
            return null
        }
        var dist = (m_Normal.Dot(ray.Start) + m_Offset) / (-denom)
        return Intersection(this, ray, dist)
    }

    func Normal(pos: Vector) -> Vector {
        return m_Normal
    }

     ISurface Surface { get set }
}

class ShinySurface : ISurface
{
    func Diffuse(pos: Vector) ->  Color  { return Color.White }
    func Specular(pos: Vector) -> Color  { return Color.Grey }
    func Reflect(pos: Vector ) -> Double { return 0.7 }
    func Roughness() -> Double { return 250.0 }
}

class CheckerboardSurface : ISurface
{
     func Diffuse(Vector pos) -> Color  { return (Math.Floor(pos.Z) + Math.Floor(pos.X)) % 2 != 0 ? Color.White : Color.Black }
     func Specular(Vector pos) -> Color { return Color.White }
     func Reflect(Vector pos) -> Double { return (Math.Floor(pos.Z) + Math.Floor(pos.X)) % 2 != 0 ? 0.1 : 0.7 }
     func Roughness () -> Double { return 150.0 }
}

class Surfaces
{
     let Shiny: ISurface = ShinySurface()
     let Checkerboard: ISurface = CheckerboardSurface()
}

class Scene
{
    var Camera: Camera
    var Lights: [Light]
    var Things: [IThing]

    Scene()
    {
        Camera = Camera(Vector(X:3.0, Y:2.0, Z:4.0), Vector(X:-1.0, Y:0.5, Z:0.0))
        Things = [
            Plane( Vector(0.0, 1.0,  0.0 ), 0.0, Surfaces.Checkerboard),
            Sphere(Vector(0.0, 1.0, -0.25), 1.0, Surfaces.Shiny),
            Sphere(Vector(-1.0, 0.5, 1.5 ), 0.5, Surfaces.Shiny)
        ]
        Lights = [
            Light(Vector(-2.0, 2.5, 0.0), Color(0.49, 0.07, 0.07)),
            Light(Vector(1.5, 2.5, 1.5),  Color(0.07, 0.07, 0.49)),
            Light(Vector(1.5, 2.5, -1.5), Color(0.07, 0.49, 0.071)),
            Light(Vector(0.0, 3.5, 0.0),  Color(0.21, 0.21, 0.35))
        ]
    }
}

class RayTracerEngine
{
    let m_MaxDepth: Int = 5
    var scene: Scene

    func Intersections(ray: Ray) -> Intersection
    {
        var closest = double.PositiveInfinity
        Intersection closestInter = null

        foreach (var item in scene.Things)
        {
            var inter = item.Intersect(ray)
            if (inter == null || !(inter.Dist < closest)) continue
            closestInter = inter
            closest = inter.Dist
        }

        return closestInter
    }

    func TraceRay(ray: Ray, depth: Int) -> Color
    {
        var isect = Intersections(ray)
        return isect == null ? Color.Background : Shade(isect, depth)
    }

    func Shade(isect: Intersection, depth: Int) -> Color
    {
        let d = isect.Ray.Dir

        var pos = (isect.Dist * d) + isect.Ray.Start
        var normal = isect.Thing.Normal(pos)
        var reflectDir = d - (2 * normal.Dot(d) * normal)
        var naturalColor = Color.Background + GetNaturalColor(isect.Thing, pos, normal, reflectDir)

        var reflectedColor = depth >= m_MaxDepth ? Color.Grey : GetReflectionColor(isect.Thing, pos, normal, reflectDir, depth)
        return naturalColor + reflectedColor
    }

    func GetReflectionColor(thing: IThing, pos: Vector, normal: Vector, rd: Vector, depth: Int) -> Color
    {
        return thing.Surface.Reflect(pos) * TraceRay(Ray(pos, rd), depth + 1)
    }

    func GetNaturalColor(thing: IThing, pos: Vector, norm: Vector, rd: Vector) -> Color
    {
        var result = Color.Defaultcolor
        foreach (var item in scene.Lights)
        {
            result = AddLight(result, item, pos, norm, rd, thing)
        }
        return result
    }

    func AddLight(col: Color, light: Light, pos: Vector, norm: Vector, rd: Vector, thing: IThing) -> Color
    {
        var ldis = light.Pos - pos
        var livec = ldis.Norm()
        var neatIsect = TestRay(Ray(pos, livec))

        var isInShadow = !double.IsNaN(neatIsect) && (neatIsect <= ldis.Length())
        if (isInShadow)
        {
            return col
        }
        var illum = livec.Dot(norm)
        var lcolor = (illum > 0) ? illum * light.Color : Color.Defaultcolor

        var specular = livec.Dot(rd.Norm())
        var scolor = specular > 0 ? (Math.Pow(specular, thing.Surface.Roughness) * light.Color) : Color.Defaultcolor

        return col + (thing.Surface.Diffuse(pos) * lcolor) + (thing.Surface.Specular(pos) * scolor)
    }

    func Render(scene: Scene, image: Image)
    {
        self.scene = scene
        let w = image.Width
        let h = image.Height

        for  y in 0..h {
            for x in 0..w {
                let pt = camera.GetPoint(x,y, w, h)
                let ray = Ray(scene.Camera.pos, pt)
                let color = TraceRay(ray, 0)
                image.setColor(x,y, color.ToDrawingColor())
            }
        }
    }
}

typealias WORD = UInt16
typealias DWORD = UInt32
typealias LONG = Int32

struct BITMAPINFOHEADER
{
    var biSize: DWORD
    var biWidth: LONG
    var biHeight: LONG
    var biPlanes: WORD
    var biBitCount: WORD
    var biCompression: DWORD
    var biSizeImage: DWORD
    var biXPelsPerMeter: LONG
    var biYPelsPerMeter: LONG
    var biClrUsed: DWORD
    var biClrImportant: DWORD
}

struct BITMAPFILEHEADER
{
    var bfType: WORD
    var bfSize: DWORD
    var bfReserved: DWORD
    var bfOffBits: DWORD
}

class Image
{
    var Data: []RGBColor
    var Width: Int
    var Height: Int

    public Image(width: Int, height: Int)
    {
        self.Width = width
        self.Height = height
        self.Data = RGBColor[(width * height)]
    }

    func setColor(x: Int, y: Int, color: RGBColor) {
        self.Data[y * self.width + x] = color
    }

    // public void Save(string fileName)
    // {
    //     var infoHeaderSize = Marshal.SizeOf(typeof(BITMAPINFOHEADER));
    //     var fileHeaderSize = Marshal.SizeOf(typeof(BITMAPFILEHEADER));
    //     var offBits = infoHeaderSize + fileHeaderSize;

    //     BITMAPINFOHEADER infoHeader = BITMAPINFOHEADER
    //     {
    //         biSize = (uint)infoHeaderSize,
    //         biBitCount = 32,
    //         biClrImportant = 0,
    //         biClrUsed = 0,
    //         biCompression = 0,
    //         biHeight = -Height,
    //         biWidth = Width,
    //         biPlanes = 1,
    //         biSizeImage = (uint)(Width * Height * 4)
    //     };

    //     BITMAPFILEHEADER fileHeader = BITMAPFILEHEADER
    //     {
    //         bfType = 'B' + ('M' << 8),
    //         bfOffBits = (uint)offBits,
    //         bfSize = (uint)(offBits + infoHeader.biSizeImage)
    //     };

    //     using (var writer = BinaryWriter(File.Open(fileName, FileMode.Create)))
    //     {
    //         writer.Write(GetBytes(fileHeader));
    //         writer.Write(GetBytes(infoHeader));
    //         foreach (var color in data)
    //         {
    //             writer.Write(color.B);
    //             writer.Write(color.G);
    //             writer.Write(color.R);
    //             writer.Write(color.A);
    //         }
    //     }
    // }
}

var image = Image(w:500, h:500)
var rayTracer = RayTracerEngine()
var scene = Scene()
rayTracer.Render(scene, image)
image.Save("swift-ray.bmp")
