@enum Surface begin
    Shiny        = 1
    CheckerBoard = 2
end

struct Vector
    x::Float64
    y::Float64
    z::Float64
end

struct Color
    r::Float64
    g::Float64
    b::Float64
end

struct RGBColor
    b::UInt8
    g::UInt8
    r::UInt8
    a::UInt8

    function RGBColor(b::UInt8, g::UInt8, r::UInt8, a::UInt8)
        new(b, g, r, a)
    end
end

struct Image
    width::Int
    height::Int
    data::Array{RGBColor,1}

    function Image(w::Int, h::Int)
        data = Array{RGBColor,1}(undef, w * h);
        new(w, h, data)
    end
end

struct Camera
    pos::Vector
    forward::Vector
    right::Vector
    up::Vector

    function Camera(pos::Vector, lookAt::Vector)
        _down = Vector(0.0, -1.0, 0.0);
        _forward = lookAt - pos
        pos = pos
        forward = Norm(_forward)
        right = Norm(Cross(forward, _down)) * 1.5
        up = Norm(Cross(forward, right)) * 1.5   
        new(pos, forward, right, up)
    end
end

struct Ray
    start::Vector
    dir::Vector
end

abstract type Thing end

struct Plane <: Thing
    normal::Vector
    offset::Float64
    surface::Surface
end

struct Sphere <: Thing
    center::Vector
    radius2::Float64
    surface::Surface
end

struct Intersection
    thing::Thing
    ray::Ray
    dist::Float64
end

struct Light
    pos::Vector
    color::Color
end

struct SurfaceProperties
    diffuse::Color
    specular::Color
    reflect::Float64
    roughness::Float64
end

const WORD  = UInt16
const DWORD = UInt32
const LONG  = Int32

struct BITMAPINFOHEADER
    biSize::DWORD
    biWidth::LONG
    biHeight::LONG
    biPlanes::WORD
    biBitCount::WORD
    biCompression::DWORD
    biSizeImage::DWORD
    biXPelsPerMeter::LONG
    biYPelsPerMeter::LONG
    biClrUsed::DWORD
    biClrImportant::DWORD

    function BITMAPINFOHEADER(w::LONG, h::LONG)
        size = sizeof(BITMAPINFOHEADER)
        sizeImage = w * h * 4
        new(size, w, -h, 1, 32, 0, sizeImage, 0, 0, 0, 0)
    end
end

struct BITMAPFILEHEADER
    bfType::WORD
    bfSize::DWORD
    bfReserved::DWORD
    bfOffBits::DWORD

    function BITMAPFILEHEADER(imageSize::DWORD)
        bfType =  0x4D42 # 'B' + ('M' << 8)
        offBits = 54
        size = convert(DWORD, offBits + imageSize);
        new(bfType, size, 0, offBits)
    end
end

struct Scene
    things::Array{Thing,1}
    lights::Array{Light,1}
    camera::Camera

    function Scene()
        things = [
            Plane(Vector(0.0, 1.0, 0.0), 0.0,  CheckerBoard)
            Sphere(Vector(0.0, 1.0, -0.25), 1.0, Shiny)
            Sphere(Vector(-1.0, 0.5, 1.5), 0.5*0.5, Shiny)
        ]
        lights = [
            Light(Vector(-2.0, 2.5, 0.0), Color(0.49, 0.07, 0.07))
            Light(Vector(1.5, 2.5, 1.5), Color(0.07, 0.07, 0.49))
            Light(Vector(1.5, 2.5, -1.5), Color(0.07, 0.49, 0.071))
            Light(Vector(0.0, 3.5, 0.0), Color(0.21, 0.21, 0.35))
        ]
        camera = Camera(Vector(3.0, 2.0, 4.0), Vector(-1.0, 0.5, 0.0));

        new(things, lights, camera)
    end
end

const maxDepth = 5
const White = Color(1.0, 1.0, 1.0)
const Grey  = Color(0.5, 0.5, 0.5)
const Black = Color(0.0, 0.0, 0.0)
const Background = Black
const Defaultcolor = Black

Length(v::Vector) = sqrt(v.x^2 + v.y^2 + v.z^2)
Scale(v::Vector, k::Float64) =  Vector(k * v.x, k * v.y, k * v.z)
Dot(a::Vector, b::Vector) =  a.x * b.x + a.y * b.y + a.z * b.z

Base.:*(v::Vector, k::Float64) = Scale(v, k)
Base.:*(a::Vector, b::Vector) = Dot(a, b)
Base.:+(a::Vector, b::Vector) = Vector(a.x + b.x, a.y + b.y, a.z + b.z)
Base.:-(a::Vector, b::Vector) = Vector(a.x - b.x, a.y - b.y, a.z - b.z)

function Norm(v::Vector)
    len = Length(v)
    div = (len == 0) ? floatmax(Float32) : 1.0 / len
    Scale(v, div)
end

function Cross(a::Vector, b::Vector)
    return Vector(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    )
end

Base.:+(a::Color, b::Color) = Color(a.r + b.r, a.g + b.g, a.b + b.b)
Base.:-(a::Color, b::Color) = Color(a.r - b.r, a.g - b.g, a.b - b.b)
Base.:*(a::Color, b::Color) = Color(a.r * b.r, a.g * b.g, a.b * b.b)

Scale(v::Color, k::Float64) = Color(k * v.r, k * v.g, k * v.b)
GetNormal(p::Plane, pos::Vector) = p.normal
GetNormal(s::Sphere, pos::Vector) = Norm(pos - s.center)

function ToRgbColor(c::Color)::RGBColor
    b = floor(UInt8, clamp(c.b, 0.0, 1.0) * 255.0)
    g = floor(UInt8, clamp(c.g, 0.0, 1.0) * 255.0)
    r = floor(UInt8, clamp(c.r, 0.0, 1.0) * 255.0)
    a = convert(UInt8, 255)
    return RGBColor(b, g, r, a)
end

function GetPoint(camera::Camera, x::Int, y::Int, screenWidth::Int, screenHeight::Int)
    recenterX = (x - (screenWidth / 2.0)) / 2.0 / screenWidth
    recenterY = -(y - (screenHeight / 2.0)) / 2.0 / screenHeight
    return Norm(camera.forward + ((camera.right * recenterX) + (camera.up * recenterY)))
end

function GetInteresection(p::Plane, ray::Ray)::Union{Intersection,Nothing}
    denom = Dot(p.normal, ray.dir)
    if (denom > 0.0)
        return nothing
    end
    dist = (Dot(p.normal, ray.start) + p.offset) / (-denom)
    Intersection(p, ray, dist)
end

function GetInteresection(s::Sphere, ray::Ray)::Union{Intersection,Nothing}
    eo = (s.center - ray.start)
    v = Dot(eo, ray.dir)
    dist = 0.0
    if (v >= 0.0)
        disc = s.radius2 - (Dot(eo, eo) - v * v)
        dist = (disc >= 0.0) ? v - sqrt(disc) : dist
    end
    (dist == 0.0) ? nothing : Intersection(s, ray, dist)
end

function GetSurfaceProperties(s::Surface, pos::Vector)::SurfaceProperties
    if s == Shiny
        return SurfaceProperties(White, Grey, 0.7, 250.0)
    else
        condition = Int32(floor(pos.x) + floor(pos.z)) & 1 != 0
        color = condition ? White : Black
        reflect = condition ? 0.1 : 0.7
        SurfaceProperties(color, White, reflect, 250.0)
    end
end

function Save(image::Image, fileName::String)

    w = convert(LONG, image.width)
    h = convert(LONG, image.height)

    infoHeader = BITMAPINFOHEADER(w, h)

    offBits = convert(DWORD, 54)
    size  = convert(DWORD, offBits + infoHeader.biSizeImage)

    fileHeader = BITMAPFILEHEADER(infoHeader.biSizeImage) 

    f = open(fileName, "w")
    write(f, fileHeader.bfType)
    write(f, fileHeader.bfSize)
    write(f, fileHeader.bfReserved)
    write(f, fileHeader.bfOffBits)
  
    write(f, infoHeader.biSize)
    write(f, infoHeader.biWidth)
    write(f, infoHeader.biHeight)
    write(f, infoHeader.biPlanes)
    write(f, infoHeader.biBitCount)
    write(f, infoHeader.biCompression)
    write(f, infoHeader.biSizeImage)
    write(f, infoHeader.biXPelsPerMeter)
    write(f, infoHeader.biYPelsPerMeter)
    write(f, infoHeader.biClrUsed)
    write(f, infoHeader.biClrImportant)

    for c in image.data
        write(f, c.b)
        write(f, c.g)
        write(f, c.r)
        write(f, c.a)
    end
    close(f)
end

function GetClosestIntersection(scene::Scene, ray::Ray)::Union{Intersection,Nothing}
    closest = floatmax(Float64)
    closestInter = nothing

    for thing in scene.things
        inter = GetInteresection(thing, ray)
        if (inter != nothing && inter.dist < closest) 
            closestInter = inter
            closest = inter.dist
        end
    end
    return closestInter;
end

function TraceRay(scene::Scene, ray::Ray, depth::Int)
    isect = GetClosestIntersection(scene, ray);
    isect != nothing ? Shade(scene, isect, depth) : Background
end 

function Shade(scene::Scene, isect::Intersection, depth::Int)
    d = isect.ray.dir;
    pos = (d * isect.dist) + isect.ray.start;
    normal = GetNormal(isect.thing, pos);
    reflectDir = Norm(d - ((normal * (normal * d)) * 2.0))

    surface =  GetSurfaceProperties(isect.thing.surface, pos);

    naturalColor = Background + GetNaturalColor(scene, surface, pos, normal, reflectDir);
    reflectedColor = (depth >= maxDepth) ? Grey : GetReflectionColor(scene, surface, pos, reflectDir, depth);

    return naturalColor + reflectedColor;
end 

function GetReflectionColor(scene::Scene, surface::SurfaceProperties, pos::Vector, reflectDir::Vector, depth::Int)
    ray = Ray(pos, reflectDir)
    color = TraceRay(scene, ray, depth + 1)
    return Scale(color, surface.reflect)
end 

function GetNaturalColor(scene::Scene, surface::SurfaceProperties, pos::Vector, norm::Vector, reflectDir::Vector)
    result = Black

    for light in scene.lights
        ldist = light.pos - pos
        livec = Norm(ldist)
        ray = Ray(pos, livec)

        neatIsect = GetClosestIntersection(scene, ray)
        isInShadow = neatIsect != nothing && neatIsect.dist < Length(ldist)

        if (!isInShadow) 
            illum    = livec * norm
            specular = livec * reflectDir

            lcolor = (illum > 0) ? Scale(light.color, illum) : Defaultcolor
            scolor = (specular > 0) ? Scale(light.color, specular^surface.roughness) : Defaultcolor
            result = result + (lcolor * surface.diffuse) + (scolor * surface.specular)            
        end
    end
    return result
end 

function Render(scene::Scene)  
    camera = scene.camera
    image = Image(500, 500)

    w = image.width - 1
    h = image.height - 1

    for y in 0:h, x in 0:w
        pt    = GetPoint(camera, x, y, w, h)
        ray   = Ray(scene.camera.pos, pt)
        color = TraceRay(scene, ray, 0)
        image.data[y * image.width + x + 1] = ToRgbColor(color)
    end
    return image
end

scene = Scene()
image = Render(scene)
@time begin
    scene = Scene()
    image = Render(scene)
end
Save(image, "julia-ray.bmp")
