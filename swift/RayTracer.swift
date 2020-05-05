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

extension Double {
    func toColorComponent() -> UInt8 {
        if (self > 1.0) {return 255}
        if (self < 0.0) {return 0}
        return (UInt8)(self * 255.0)
    }

    func floorAsInt() -> Int {
        var result = self;
        result.round(.down)
        return Int(result)
    }

    func power(_ power: Int) -> Double {
        precondition(power >= 0)
        var result = self
        for _ in 2 ... power {
            result = result * self
        }
        return result
    }
}

struct Color
{
    var R: Double
    var G: Double
    var B: Double

    static func *(k: Double, v: Color) -> Color {
        return Color(R:k * v.R, G:k * v.G, B:k * v.B)
    }

    static func +(a: Color, b: Color) -> Color {
        return Color(R: a.R + b.R, G: a.G + b.G, B: a.B + b.B)
    }

    static func *(a: Color, b: Color) -> Color {
        return Color(R: a.R * b.R, G: a.G * b.G, B: a.B * b.B)
    }

    func ToDrawingColor() -> RGBColor {
        return RGBColor(
            B: self.B.toColorComponent(),
            G: self.G.toColorComponent(),
            R: self.R.toColorComponent(),
            A: 255
        )
    }
}

let White = Color(R: 1.0, G: 1.0, B: 1.0)
let Grey  = Color(R: 0.5, G: 0.5, B: 0.5)
let Black = Color(R: 0.0, G: 0.0, B: 0.0)
let Background = Black
let Defaultcolor = Black

struct Camera
{
    var Forward: Vector
    var Right: Vector
    var Up: Vector
    var Pos: Vector

    init(pos: Vector, lookAt: Vector) {
        let down = Vector(X:0.0, Y:-1.0, Z:0.0)
        Pos = pos
        Forward = (lookAt - Pos).Norm()
        Right = 1.5 * Forward.Cross(v: down).Norm()
        Up = 1.5 * Forward.Cross(v: Right).Norm()
    }

    func GetPoint(x: Int, y: Int, w: Int, h: Int) -> Vector {
        let xf = Double(x);
        let yf = Double(y);
        let wf = Double(w);
        let hf = Double(h);
        let recenterX = (xf - (wf / 2.0)) / 2.0 / wf
        let recenterY = -(yf - (hf / 2.0)) / 2.0 / hf
        return (self.Forward + (recenterX * self.Right) + (recenterY * self.Up)).Norm()
    }
}

struct Ray
{
    var Start: Vector
    var Dir: Vector
}

struct Intersection
{
    var Thing: Thing
    var Ray: Ray
    var Dist: Double
}

protocol ISurface
{
    func Diffuse(pos: Vector)   -> Color
    func Specular(pos: Vector)  -> Color
    func Reflect(pos: Vector )  -> Double
    func Roughness() -> Double
}

protocol Thing
{
    func Surface() -> ISurface
    func Intersect(ray: Ray) -> Intersection?
    func Normal(pos: Vector) -> Vector
}

struct Light
{
    var Pos: Vector
    var Color: Color
}

class Sphere : Thing
{
    var m_Radius2: Double
    var m_Center: Vector
    var m_Surface: ISurface

    init (center: Vector, radius: Double, surface: ISurface)
    {
        m_Radius2 = radius * radius
        m_Surface = surface
        m_Center = center
    }

    func Intersect(ray: Ray) -> Intersection?
    {
        let eo = (m_Center - ray.Start)
        let v = eo.Dot(v: ray.Dir)
        if (v >= 0)
        {
            let disc = m_Radius2 - (eo.Dot(v: eo) - v * v)
            if (disc >= 0)
            {
                let dist = v - disc.squareRoot()
                return Intersection(Thing: self, Ray: ray, Dist: dist)
            }
        }
        return nil;
    }

    func Normal(pos: Vector) -> Vector {
        return (pos - m_Center).Norm()
    }

    func Surface() -> ISurface { return m_Surface }
}

class Plane : Thing
{
    var m_Normal: Vector
    var m_Offset: Double
    var m_Surface: ISurface

    init(norm: Vector, offset: Double, surface: ISurface)
    {
        m_Normal = norm
        m_Offset = offset
        m_Surface = surface
    }

    func Intersect(ray: Ray) -> Intersection?
    {
        let denom = m_Normal.Dot(v: ray.Dir)
        if (denom <= 0) {
            let dist = (m_Normal.Dot(v: ray.Start) + m_Offset) / (-denom)
            return Intersection(Thing: self, Ray: ray, Dist: dist)
        }
        return nil
    }

    func Normal(pos: Vector) -> Vector {
        return m_Normal
    }

    func Surface() -> ISurface { return m_Surface }
}

class ShinySurface : ISurface
{
    func Diffuse(pos: Vector) ->  Color  { return White }
    func Specular(pos: Vector) -> Color  { return Grey }
    func Reflect(pos: Vector ) -> Double { return 0.7 }
    func Roughness() -> Double { return 250.0 }
}

class CheckerboardSurface : ISurface
{
     func Condition(pos: Vector) -> Bool {
        return (pos.Z.floorAsInt() + pos.X.floorAsInt()) % 2 != 0;
     }

     func Diffuse(pos: Vector) -> Color  { return self.Condition(pos: pos) ? White : Black }
     func Specular(pos: Vector) -> Color { return White }
     func Reflect(pos: Vector) -> Double { return self.Condition(pos: pos) ? 0.1 : 0.7 }
     func Roughness () -> Double { return 150.0 }
}

class Scene
{
    var camera: Camera
    var lights: [Light]
    var things: [Thing]

    init()
    {
        let Shiny = ShinySurface()
        let Checkerboard = CheckerboardSurface()
        things = [
            Plane( norm:   Vector(X: 0.0, Y:1.0, Z: 0.0 ), offset: 0.0, surface: Checkerboard),
            Sphere(center: Vector(X: 0.0, Y:1.0, Z:-0.25), radius: 1.0, surface: Shiny),
            Sphere(center: Vector(X:-1.0, Y:0.5, Z: 1.5 ), radius: 0.5, surface: Shiny)
        ]
        lights = [
            Light(Pos: Vector(X:-2.0, Y:2.5, Z:0.0),  Color: Color(R:0.49, G:0.07, B:0.07)),
            Light(Pos: Vector(X: 1.5, Y:2.5, Z:1.5),  Color: Color(R:0.07, G:0.07, B:0.49)),
            Light(Pos: Vector(X: 1.5, Y:2.5, Z:-1.5), Color: Color(R:0.07, G:0.49, B:0.071)),
            Light(Pos: Vector(X: 0.0, Y:3.5, Z:0.0),  Color: Color(R:0.21, G:0.21, B:0.35))
        ]
        self.camera = Camera(pos: Vector(X:3.0, Y:2.0, Z:4.0), lookAt: Vector(X:-1.0, Y:0.5, Z:0.0))
    }
}

let MaxDepth: Int = 5

func Intersections(scene: Scene, ray: Ray) -> Intersection?
{
    var closest = Double.infinity
    var closestInter : Intersection? = nil

    for item in scene.things
    {
        let inter = item.Intersect(ray: ray)
        if (inter != nil && inter!.Dist < closest) {
            closestInter = inter
            closest = inter!.Dist
        }
    }
    return closestInter
}

func TraceRay(scene: Scene, ray: Ray, depth: Int) -> Color
{
    let isect = Intersections(scene: scene, ray: ray)
    return isect == nil ? Background : Shade(scene: scene, isect: isect!, depth: depth)
}

func Shade(scene: Scene, isect: Intersection, depth: Int) -> Color
{
    let d = isect.Ray.Dir
    let pos = (isect.Dist * d) + isect.Ray.Start
    let normal = isect.Thing.Normal(pos: pos)
    let reflectDir = d - (2 * normal.Dot(v:d) * normal)
    let naturalColor = Background + GetNaturalColor(scene: scene, thing: isect.Thing, pos: pos, normal: normal, reflectDir: reflectDir)
    let reflectedColor = depth >= MaxDepth ? Grey : GetReflectionColor(scene: scene, thing: isect.Thing, pos: pos, normal: normal, reflectDir: reflectDir, depth: depth)
    return naturalColor + reflectedColor
}

func GetReflectionColor(scene: Scene, thing: Thing, pos: Vector, normal: Vector, reflectDir: Vector, depth: Int) -> Color
{
    let ray = Ray(Start: pos, Dir: reflectDir)
    let reflect = thing.Surface().Reflect(pos: pos)
    let color =  TraceRay(scene: scene, ray: ray, depth: depth + 1)
    return reflect * color
}

func GetNaturalColor(scene: Scene, thing: Thing, pos: Vector, normal: Vector, reflectDir: Vector) -> Color
{
    var result = Defaultcolor
    for 😎 in scene.lights
    {
        let ldis = 😎.Pos - pos
        let livec = ldis.Norm()
        let ray = Ray(Start:pos, Dir: livec)
        let neatIsect = Intersections(scene: scene, ray: ray)

        let isInShadow = neatIsect != nil && (neatIsect!.Dist <= ldis.Length())
        if (isInShadow)
        {
            let illum = livec.Dot(v: normal)
            let specular = livec.Dot(v: reflectDir.Norm())

            var lcolor = Defaultcolor
            var scolor = Defaultcolor
            if (illum > 0) {
                lcolor = illum * 😎.Color
            }
            if (specular > 0) {
                scolor = specular.power(Int(thing.Surface().Roughness())) * 😎.Color
            }
            result =  result + (thing.Surface().Diffuse(pos: pos) * lcolor) + (thing.Surface().Specular(pos: pos) * scolor)
        }
    }
    return result
}

func Render(scene: Scene, image: Image)
{
    let w = image.Width
    let h = image.Height

    for  y in 0 ... h-1 {
        for x in 0 ... w-1 {
            let pt = scene.camera.GetPoint(x: x, y: y, w: w, h: h)
            let ray = Ray(Start: scene.camera.Pos, Dir: pt)
            let color = TraceRay(scene: scene, ray: ray, depth: 0)
            image.setColor(x: x, y: y, color: color.ToDrawingColor())
        }
    }
}

typealias WORD  = UInt16
typealias DWORD = UInt32
typealias LONG  = Int32

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
    var data: [RGBColor]
    var Width: Int
    var Height: Int

    init(width: Int, height: Int)
    {
        self.Width = width
        self.Height = height
        self.data = Array(repeating: RGBColor(B: 0, G: 0, R: 0, A: 0), count: width*height)
    }

    func setColor(x: Int, y: Int, color: RGBColor) {
        self.data[y * self.Width + x] = color
    }

    func Save(fileName: String)
    {
        // let infoHeaderSize: Int = 40;
        // let fileHeaderSize: Int = 14;
        // let offBits = infoHeaderSize + fileHeaderSize;

        // let infoHeader = BITMAPINFOHEADER(
        //     biSize: DWORD(infoHeaderSize),
        //     biWidth: LONG(Width),
        //     biHeight: LONG(-Height),
        //     biPlanes: 1,
        //     biBitCount: 32,
        //     biCompression:  0,
        //     biSizeImage: DWORD(Width * Height * 4),
        //     biXPelsPerMeter: 0,
        //     biYPelsPerMeter: 0,
        //     biClrUsed: 0,
        //     biClrImportant: 0
        // )

        // let fileHeader = BITMAPFILEHEADER(
        //     bfType: 66 + (77 << 8),
        //     bfSize: DWORD(Int(offBits) + Int(infoHeader.biSizeImage)),
        //     bfReserved: 0,
        //     bfOffBits: DWORD(offBits)
        // )

        //let url = URL(fileURLWithPath: "SwiftRay.bmp")
        // let wArray = Array(repeating: 0, count: self.data.count * 4 + 54)
        // let wData = Data(bytes: &wArray, count: wArray.count)
        // try! wData.write(to: "SwiftRay.bmp")
    }
}

func main() {
    let image = Image(width: 500, height: 500)
    let scene = Scene()
    Render(scene: scene, image: image)

    print("Completed")
}

main()