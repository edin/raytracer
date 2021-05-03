open System
open System.Runtime.InteropServices
open System.Collections.Generic
open System.IO

[<StructAttribute>]
type Vector(x:double, y:double, z:double) =
    member v.X = x
    member v.Y = y
    member v.Z = z
    member v.Length() = sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z)
    member v.Dot(a: Vector) = v.X * a.X + v.Y * a.Y + v.Z * a.Z
    static member (*) (k: double, v: Vector) = Vector(k*v.X, k*v.Y, k*v.Z)
    static member (-) (a: Vector, b: Vector) = Vector(a.X - b.X, a.Y - b.Y , a.Z - b.Z)
    static member (+) (a: Vector, b: Vector) = Vector(a.X + b.X, a.Y + b.Y , a.Z + b.Z)
    member v.Norm(): Vector =
        let len = v.Length()
        let div = if (len = 0.0) then Double.PositiveInfinity
                  else 1.0 / len
        div * v
    member v.Cross(a: Vector): Vector =
        Vector(
            v.Y * a.Z - v.Z * a.Y,
            v.Z * a.X - v.X * a.Z,
            v.X * a.Y - v.Y * a.X
        )

[<StructAttribute>]
type RGBColor =
    val B: uint8
    val G: uint8
    val R: uint8
    val A: uint8
    new (r: uint8, g: uint8, b: uint8) = {R = r; G = g; B = b; A = 255uy;}

type Image(w: int, h: int) =
    let size = w * h
    let mutable data = new List<RGBColor>(size)
    member i.W = w
    member i.H = h
    member i.Data = data

[<StructAttribute>]
type Color(r:double, g:double, b:double) =
    member c.R = r
    member c.G = g
    member c.B = b
    member c.Scale(k:double) = Color(k * c.R, k * c.G, k * c.B)
    static member (+) (a: Color, b: Color) = Color(a.R + b.R, a.G + b.G , a.B + b.B)
    static member (-) (a: Color, b: Color) = Color(a.R - b.R, a.G - b.G , a.B - b.B)
    static member (*) (a: Color, b: Color) = Color(a.R * b.R, a.G * b.G,  a.B * b.B)
    static member Clamp(c: double): byte =
        let cf = c * 255.0
        if (cf > 255.0) then 255uy
        else if (cf < 0.0) then 0uy
        else (byte cf)
    member c.ToRGBColor(): RGBColor =
        RGBColor(Color.Clamp(c.R), Color.Clamp(c.G), Color.Clamp(c.B))

let White = Color(1.0, 1.0, 1.0);
let Grey =  Color(0.5, 0.5, 0.5);
let Black = Color(0.0, 0.0, 0.0);
let Background = Black;
let Defaultcolor = Black;

type Camera(pos: Vector, lookAt:Vector) =
    let down = new Vector(0.0, -1.0, 0.0);
    member c.Pos = pos;
    member c.Forward = (lookAt - c.Pos).Norm()
    member c.Right = 1.5 * c.Forward.Cross(down).Norm()
    member c.Up = 1.5 * c.Forward.Cross(c.Right).Norm()

    member c.GetPoint(x:int, y:int, w:int, h:int): Vector =
        let xf = double x
        let yf = double y
        let wf = double w
        let hf = double h
        let recenterX = (xf - (wf / 2.0)) / 2.0 / wf
        let recenterY = -(yf - (hf / 2.0)) / 2.0 / hf
        let result = (c.Forward + (recenterX * c.Right) + (recenterY * c.Up)).Norm()
        result

[<StructAttribute>]
type Ray(start: Vector, dir: Vector) =
    member r.Start = start
    member r.Dir = dir

[<StructAttribute>]
type SurfaceProperties(diffuse: Color, specular: Color, reflect: double, roughness: double) =
    member t.Diffuse = diffuse
    member t.Specular = specular
    member t.Reflect = reflect
    member t.Roughness = roughness

type Surface =
    | Shiny
    | Checkerboard

let GetSurfaceProperties(surface: Surface, pos: Vector) : SurfaceProperties =
    match surface with
    | Shiny -> SurfaceProperties(White, Grey, 0.7, 250.0)
    | Checkerboard ->
        let condition = (int(floor(pos.X) + floor(pos.Z)) % 2) <> 0
        let color = if condition then White else Black
        let reflect = if condition then 0.1 else 0.7
        SurfaceProperties(color, White, reflect, 250.0)

type Thing =
    | Plane of Normal : Vector * Offset : double * Surface: Surface
    | Sphere of Center : Vector * Radius2: double * Surface: Surface

type Intersection(thing: Thing, ray: Ray, dist: double) =
    member t.Thing = thing
    member t.Ray = ray
    member t.Dist = dist;

let GetIntersection(thing: Thing, ray: Ray): Option<Intersection> =
   match thing with
   | Plane(Normal = normal; Offset = offset) ->
        let denom = normal.Dot(ray.Dir)
        if denom > 0.0 then None
        else
            let dist = (normal.Dot(ray.Start) + offset) / (-denom)
            Some(Intersection(thing, ray, dist))
   | Sphere(Center = center; Radius2 = radius2) ->
        let eo = (center - ray.Start)
        let v = eo.Dot(ray.Dir)
        let dist =
            if (v >= 0.0) then
                let disc = radius2 - (eo.Dot(eo) - v * v)
                if (disc >= 0.0) then v - sqrt(disc) else 0.0
            else 0.0
        if (dist = 0.0) then None
        else Some(Intersection(thing, ray, dist))

let GetNormal(thing: Thing, pos: Vector) =
    match thing with
        | Plane(Normal = normal) -> normal
        | Sphere(Center = center) -> (pos - center).Norm()

type Light (pos: Vector, color: Color) =
    member t.Pos = pos
    member t.Color = color

type Scene() =
    member s.Camera = Camera(Vector(3.0, 2.0, 4.0), Vector(-1.0, 0.5, 0.0))
    member s.Things : Thing[] = [|
        Plane(Vector(0.0, 1.0, 0.0), 0.0, Checkerboard);
        Sphere(Vector(0.0, 1.0, -0.25), 1.0, Shiny);
        Sphere(Vector(-1.0, 0.5, 1.5), 0.5, Shiny)
    |]
    member s.Lights : Light[] = [|
        Light(Vector(-2.0, 2.5, 0.0), Color(0.49, 0.07, 0.07));
        Light(Vector(1.5, 2.5, 1.5),  Color(0.07, 0.07, 0.49));
        Light(Vector(1.5, 2.5, -1.5), Color(0.07, 0.49, 0.071));
        Light(Vector(0.0, 3.5, 0.0),  Color(0.21, 0.21, 0.35))
    |]

type DWORD = uint32
type LONG  = int32
type WORD  = int16

[<StructLayout(LayoutKind.Sequential, Pack=1)>]
[<StructAttribute>]
type BITMAPINFOHEADER =
    val biSize: DWORD
    val biWidth: LONG
    val biHeight: LONG
    val biPlanes: WORD
    val biBitCount: WORD
    val biCompression: DWORD
    val biSizeImage: DWORD
    val biXPelsPerMeter: LONG
    val biYPelsPerMeter: LONG
    val biClrUsed: DWORD
    val biClrImportant: DWORD
    new (size: DWORD, w: LONG, h: LONG, planes: WORD, bitCount: WORD, compression: DWORD, sizeImage: DWORD, xPerMeter: LONG, yPerMeter: LONG, clrUsed: DWORD, clrImportant: DWORD) =
        {biSize = size; biWidth = w; biHeight = h; biPlanes = planes; biBitCount = bitCount; biCompression = compression; biSizeImage = sizeImage; biXPelsPerMeter = xPerMeter; biYPelsPerMeter = yPerMeter; biClrUsed = clrUsed; biClrImportant = clrImportant }

[<type:StructLayout(LayoutKind.Sequential, Pack=1)>]
[<StructAttribute>]
type BITMAPFILEHEADER =
    val bfType: uint16
    val bfSize: uint32
    val bfOffBits: uint32 //Hack (reordered to generate correct header)
    val bfReserved1: uint16
    val bfReserved2: uint16
    new (pType: uint16, size: uint32, offBits: uint32) =
        {bfType = pType; bfSize = size; bfOffBits = offBits; bfReserved1 = 0us; bfReserved2 = 0us}

let GetBytes<'T>(data: 'T) : byte[] =
    let length = Marshal.SizeOf(data)
    let ptr = Marshal.AllocHGlobal(length)
    let myBuffer = Array.create<byte> length 0uy
    Marshal.StructureToPtr(data, ptr, true)
    Marshal.Copy(ptr, myBuffer, 0, length)
    Marshal.FreeHGlobal(ptr)
    myBuffer

let SaveImage(fileName: string, image: Image)  =

    let biSize = uint32 sizeof<BITMAPINFOHEADER>
    let bfOffBits = uint32 (sizeof<BITMAPFILEHEADER> + sizeof<BITMAPINFOHEADER>)
    let iSize = uint32( image.W * image.H * 4)
    let infoHeader = BITMAPINFOHEADER(biSize, image.W,  -image.H, 1s, 32s, 0u, iSize, 0,0, 0u, 0u)
    let fileHeader = BITMAPFILEHEADER(19778us, bfOffBits, bfOffBits + iSize)

    let writer = new BinaryWriter(File.Open(fileName, FileMode.Create))

    writer.Write(GetBytes(fileHeader));
    writer.Write(GetBytes(infoHeader))
    for item: RGBColor in image.Data do
        writer.Write(item.B)
        writer.Write(item.G)
        writer.Write(item.R)
        writer.Write(item.A)
    writer.Close() |> ignore

type Renderer(scene: Scene, maxDepth: int) =
    member r.Interesections (ray: Ray) : Option<Intersection> =
        let things = scene.Things
        let count = things.Length - 1

        let result =
            [0 .. count]
            |> List.map(fun(i) ->  things.[i] )
            |> List.map(fun(thing: Thing) -> GetIntersection(thing, ray))
            |> List.filter(fun(isect: Option<Intersection>) -> isect.IsSome)

        if result.IsEmpty then None
        else
            result |> List.minBy(fun(isect) -> isect.Value.Dist)

    member r.TraceRay(ray: Ray, depth: int): Color =
        let isect = r.Interesections(ray)
        match isect with
            | Some x -> r.Shade(x, depth)
            | None -> Background

    member r.Shade(isect: Intersection, depth: int) =
        let d = isect.Ray.Dir
        let pos = (isect.Dist * d) + isect.Ray.Start
        let normal = GetNormal(isect.Thing, pos)
        let reflectDir = d - (2.0 * normal.Dot(d) * normal)
        let surface =
            match isect.Thing with
                | Plane (Surface = s) -> GetSurfaceProperties(s, pos)
                | Sphere (Surface = s) -> GetSurfaceProperties(s, pos)

        let naturalColor = Background + r.GetNaturalColor(surface, pos, normal, reflectDir)
        let reflectedColor = if depth >= maxDepth then Grey else r.GetReflectionColor(surface, pos, reflectDir, depth)
        naturalColor + reflectedColor

    member r.GetReflectionColor(surface: SurfaceProperties, pos: Vector, reflectDir: Vector, depth: int): Color =
        let ray = Ray(pos, reflectDir)
        r.TraceRay(ray, depth + 1).Scale(surface.Reflect)

    member r.AddLight(col: Color, light: Light, surface: SurfaceProperties, pos: Vector, normal: Vector, reflectDir: Vector) =
        let ldis = light.Pos - pos
        let livec = ldis.Norm()
        let ray = Ray(pos, livec)
        let neatIsect = r.Interesections(ray)

        let isInShadow = neatIsect.IsSome && (neatIsect.Value.Dist <= ldis.Length())
        if (isInShadow) then col
        else
            let illum = livec.Dot(normal);
            let lcolor = if (illum > 0.0) then light.Color.Scale(illum) else Defaultcolor
            let specular = livec.Dot(reflectDir.Norm())
            let scolor = if specular > 0.0 then light.Color.Scale(Math.Pow(specular, surface.Roughness))  else Defaultcolor
            let result = col + (surface.Diffuse * lcolor) + (surface.Specular * scolor)
            result

    member r.GetNaturalColor(surface: SurfaceProperties, pos: Vector, normal: Vector, reflectDir: Vector) =
        let mutable result = Defaultcolor
        for light in scene.Lights do
            result <- r.AddLight(result, light, surface, pos, normal, reflectDir)
        result

    member r.Render(image: Image) =
        let w = image.W-1
        let h = image.H-1
        let data = image.Data
        for y in 0 .. h do
            for x in 0 .. w do
                let pt = scene.Camera.GetPoint(x, y, w, h)
                let ray = Ray(scene.Camera.Pos, pt)
                data.Add(r.TraceRay(ray, 0).ToRGBColor())

[<EntryPoint>]
let main argv =
    let sw = new System.Diagnostics.Stopwatch()
    sw.Start()
    let scene = Scene()
    let image = Image(500, 500)
    let renderr = new Renderer(scene, 5)
    renderr.Render(image)
    sw.Stop()
    let _ = SaveImage("fs-raytracer.bmp", image)
    printfn "Completed in %d ms" sw.ElapsedMilliseconds
    0