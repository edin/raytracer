using Images

@enum Surface begin
    ShinySurface = 1
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
end

struct Image
    width:: Int
    height:: Int
    data:: Array{RGBColor,1}
end

struct Camera
    pos::Vector
    forward::Vector
    right::Vector
    up::Vector
end

struct Ray
    start::Vector
    dir::Vector
end

abstract type Thing end

struct Plane <: Thing
    normal::Vector
    offset::Float64
end

struct Sphere <: Thing
    center::Vector
    radius2::Float64
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

const White = Color(1.0, 1.0, 1.0)
const Grey  = Color(0.5, 0.5, 0.5)
const Black = Color(0.0, 0.0, 0.0)
const Background = Black
const Defaultcolor = Black

# Vector functions
Length(v::Vector) = sqrt(v.x^2 + v.y^2 + v.z^2)
Scale(v::Vector, k::Float64) =  Vector(k*v.x, k*v.y, k*v.z)
Dot(a::Vector, b::Vector) =  a.x*b.x + a.y*b.y + a.z*b.z

Base.:*(k::Float64, v::Vector) = Vector(k * v.x, k * v.y, k * v.z)
Base.:+(a::Vector,  b::Vector) = Vector(a.x + b.x, a.y + b.y, a.z + b.z)
Base.:-(a::Vector, b::Vector) =  Vector(a.x - b.x, a.y - b.y, a.z - b.z)

function Norm(v::Vector)
    len = Length(v)
    div = (len == 0) ? floatmax(Float32) : 1.0 / len
    Scale(v, div)
end

# Color functions
Base.:+(a::Color, b::Color) = Color(a.r + b.r, a.g + b.g, a.b + b.b)
Base.:-(a::Color, b::Color) = Color(a.x - b.x, a.y - b.y, a.z - b.z)
Base.:*(k::Float64, v::Color) = Color(k * v.x, k * v.y, k * v.z)
Scale(v::Color, k) = Color(k*v.x, k*v.y, k*v.z)

# Plane and sphere functions
GetNormal(p::Plane, pos::Vector) = p.normal
GetNormal(s::Sphere, pos::Vector) = Norm(pos - s.center)

function GetInteresection(p::Plane, ray::Ray)::Union{Intersection, Nothing}
    denom = Dot(p.normal, ray)
    if (denom > 0.0)
        return Nothing
    end
    dist = (Dot(p.normal, ray.start) + p.normal) / (-denom)
    Intersection(p, ray, dist)
end

function GetInteresection(s::Sphere, ray::Ray)::Union{Intersection, Nothing}
    eo = (s.center - ray.start)
    v = Dot(eo, ray.dir)
    dist = 0.0
    if (v >= 0.0)
        disc = s.radius2 - (Dot(eo, eo) - v*v)
        if (disc >= 0.0)
            dist = v - sqrt(disc)
        end
    end
    if dist == 0.0
        return Nothing
    end
    Intersection(s, ray, dist)
end

function GetSurfaceProperties(s::Surface, pos::Vector)::SurfaceProperties
    if s == ShinySurface
        return SurfaceProperties(White, Grey, 0.7, 250.0)
    else
        xz = floor(pos.x) + floor(pos.z)
        condition = mod(xz,2) != 0
        color = condition ? White : Black
        reflect = condition ? 0.1 : 0.7
        SurfaceProperties(color, White, reflect, 250.0)
    end
end

v =  3.0 * (Vector(1,2,3) + Vector(2,3,4))
println(GetSurfaceProperties(ShinySurface, v))
println(GetSurfaceProperties(CheckerBoard, v))


