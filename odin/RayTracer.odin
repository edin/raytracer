package main

import "core:fmt"
import "core:math"
import "core:os"

FarAway: f64 = 1_000_000.0;
MaxDepth: int = 5;

WORD  :: u16;
DWORD :: u32;
LONG  :: i32;

BITMAPINFOHEADER :: struct {
    biSize: DWORD,
    biWidth: LONG,
    biHeight: LONG,
    biPlanes: WORD,
    biBitCount: WORD,
    biCompression: DWORD,
    biSizeImage: DWORD,
    biXPelsPerMeter: LONG,
    biYPelsPerMeter: LONG,
    biClrUsed: DWORD,
    biClrImportant: DWORD
};

BITMAPFILEHEADER :: struct #packed {
    bfType: WORD,
    bfSize: DWORD,
    bfReserved1: WORD,
    bfReserved2: WORD,
    bfOffBits: DWORD,
};

Surface :: enum {
    Shiny,
    Checkerboard
};

SurfaceProperties :: struct {
    diffuse: Color,
    specular: Color,
    reflect: f64,
    roughness: f64
};

Vector :: [3]f64;
Color  :: [3]f64;

White := Color{1.0, 1.0, 1.0};
Grey  := Color{0.5, 0.5, 0.5};
Black := Color{0.0, 0.0, 0.0};
Background := Black;
DefaultColor := Black;

RgbColor :: struct {
    b: u8,
    g: u8,
    r: u8,
    a: u8
};

Image :: struct {
    width: int,
    height: int,
    data: [dynamic]RgbColor
};

Length :: proc (v: Vector) -> f64 {
    return math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z);
}

Norm :: proc (v: Vector) -> Vector {
    len := Length(v);
    div : f64 = (len == 0.0) ? FarAway : 1 / len;
    return v * div;
}

Cross :: proc (v: Vector, a:Vector) -> Vector {
    return Vector{
        v.y * a.z - v.z * a.y, 
        v.z * a.x - v.x * a.z, 
        v.x * a.y - v.y * a.x   
    };
}

Plane :: struct {
    norm: Vector,
    offset: f64,
    surface: Surface
};

Sphere :: struct {
    center: Vector,
    radius2: f64,
    surface: Surface
};

Thing :: union {Plane, Sphere};

Camera :: struct {
    pos : Vector,
    forward : Vector,
    right: Vector, 
    up: Vector
};

Ray :: struct {
    start : Vector,
    dir : Vector,
};

Intersection :: struct {
    thing : Thing,
    ray: Ray,
    dist: f64
};

Light :: struct {
    pos: Vector,
    color: Color
};

Scene :: struct {
    things: []Thing,
    lights: []Light,
    camera: Camera
}

Dot :: proc (a: Vector, b: Vector) -> f64 {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

Clamp :: proc(c: f64) -> u8 {
    if (c > 1.0) { return 255; }
    if (c < 0.0) { return 0; }
    return u8(c * 255.0);
}

ToRgbColor :: proc( c: Color) -> RgbColor {
    r := Clamp(c.x);
    g := Clamp(c.y);
    b := Clamp(c.z); 
    return RgbColor{b,g,r,255};
}

CreateCamera :: proc(pos: Vector, lookAt: Vector) -> Camera {
    down    := Vector{0.0, -1.0, 0.0};
    forward := Norm(lookAt - pos);
    right   := Norm(Cross(forward, down)) * 1.5;
    up      := Norm(Cross(forward, right)) * 1.5;
    return Camera{pos, forward, right, up};
}

GetPoint :: proc (camera: Camera, x: int, y: int, w: int, h: int) -> Vector {
    xf := f64(x);
    yf := f64(y);
    wf := f64(w);
    hf := f64(h);
    recenterX :=  (xf - (wf / 2.0)) / 2.0 / wf;
    recenterY := -(yf - (hf / 2.0)) / 2.0 / hf;
    return Norm(camera.forward + (camera.right * recenterX) + (camera.up * recenterY));
}

GetSurfaceProperties :: proc (surface: Surface, pos: Vector) -> SurfaceProperties {
    switch surface {
        case Surface.Shiny:
            return SurfaceProperties{White, Grey, 0.7, 250.0};
        case Surface.Checkerboard:
            cond := int(math.floor(pos.x)  + math.floor(pos.z)) % 2 != 0;
            if cond {
                return SurfaceProperties{White, White, 0.1, 150.0};
            } else {
                return SurfaceProperties{Black, White, 0.7, 150.0};
            }
    };
    return SurfaceProperties{White, Grey, 0.7, 250.0};
}

GetObjectNormal :: proc (thing: Thing, pos: Vector) -> Vector {
    switch this in thing {
    case Plane:
        return this.norm;
    case Sphere:
        return Norm(pos - this.center);
    };
    return Vector{};
}

GetIntersection :: proc(thing: Thing, ray: Ray) -> union{Intersection} {
    switch this in thing {
    case Plane: 
        denom := Dot(this.norm, ray.dir);
        if denom <= 0.0 {
            dist := (Dot(this.norm, ray.start) + this.offset) / (-denom);
            return Intersection{this, ray, dist};
        }
    case Sphere: 
        eo := this.center - ray.start;
        v := Dot(eo, ray.dir);
        if v >= 0.0 {
            disc := this.radius2 - (Dot(eo, eo) - (v * v));
            if (disc >= 0.0) {
                dist := v - math.sqrt(disc);
                return Intersection{this, ray, dist};
            }
        }
    };
    return nil;
};

GetClosestIntersection :: proc (scene: Scene, ray: Ray) -> union {Intersection} {
    closestInter : union {Intersection}  = nil;
    closest : f64 = FarAway;

    for thing in scene.things {
        switch v in GetIntersection(thing, ray) {
            case Intersection: 
                if v.dist < closest {
                    closestInter = v;
                    closest = v.dist;
                }
        }
    }
    return closestInter;
}

GetSurfaceType :: proc (thing: Thing) -> Surface {
    switch s in thing {
        case Plane: return s.surface;
        case Sphere: return s.surface;
    }
    return Surface.Shiny;
}

TraceRay :: proc (scene: Scene, ray: Ray, depth: int) -> Color {
    switch isect in GetClosestIntersection(scene, ray) {
        case Intersection:
            return Shade(scene, isect, depth);
        case: 
            return Background;
    }
}


Shade :: proc(scene: Scene, isect: Intersection, depth: int) -> Color {
    d          := isect.ray.dir;
    pos        := (d * isect.dist) + isect.ray.start;
    normal     := GetObjectNormal(isect.thing, pos);
    reflectDir := Norm(d - (normal * (Dot(normal, d) * 2.0)));

    surface    := GetSurfaceProperties(GetSurfaceType(isect.thing), pos);

    naturalColor   := GetNaturalColor(scene, surface, pos, normal, reflectDir) + Background;
    reflectedColor := Grey;

    if depth < MaxDepth {
        reflectedColor = GetReflectionColor(scene, surface, pos, reflectDir, depth);
    }

    return naturalColor + reflectedColor;
}

GetReflectionColor :: proc (scene: Scene, surface: SurfaceProperties, pos: Vector, reflectDir: Vector, depth: int) -> Color {
    ray := Ray{pos, reflectDir};
    color := TraceRay(scene, ray, depth + 1);
    return color * surface.reflect;
}

GetNaturalColor :: proc (scene: Scene, surface: SurfaceProperties, pos: Vector, norm: Vector, reflectDir: Vector) -> Color
{
    result: Color = Black;
    for light in scene.lights {
        ldis  := light.pos - pos;
        livec := Norm(ldis);
        ray   := Ray{ pos, livec };

        isInShadow := false;
        switch isect in GetClosestIntersection(scene, ray) {
            case Intersection: {
                isInShadow = isect.dist <= Length(ldis);
            }
        }

        if (!isInShadow) {
            illum    := Dot(livec, norm);
            specular := Dot(livec, reflectDir);
            lcolor   := DefaultColor;
            scolor   := DefaultColor;

            if (illum > 0) {
                lcolor = light.color * illum;
            }
            if (specular > 0) {
                scolor = light.color * math.pow(specular, surface.roughness);
            }
            result = result + (lcolor * surface.diffuse) + (scolor * surface.specular);
        }
    }
    return result;
}

CreateImage :: proc(w: int, h: int) -> Image {
    return Image{
        w,h, make([dynamic]RgbColor, w * h)
    };
};

CreateScene:: proc () -> Scene {
    things := []Thing{
        Plane{Vector{0.0, 1.0, 0.0}, 0.0, Surface.Checkerboard},
        Sphere{Vector{0.0, 1.0, -0.25}, 1.0, Surface.Shiny},
        Sphere{Vector{-1.0, 0.5, 1.5}, 0.5, Surface.Shiny}
    };

    lights := []Light{
        Light{Vector{-2.0, 2.5, 0.0}, Color{0.49, 0.07, 0.07}},
        Light{Vector{1.5, 2.5, 1.5}, Color{0.07, 0.07, 0.49}},
        Light{Vector{1.5, 2.5, -1.5}, Color{0.07, 0.49, 0.071}},
        Light{Vector{0.0, 3.5, 0.0}, Color{0.21, 0.21, 0.35}}
    };
    camera := CreateCamera(Vector{3.0, 2.0, 4.0}, Vector{-1.0, 0.5, 0.0});
    return Scene {things, lights, camera};
}

Render:: proc (scene: Scene, image: Image) {
    w := image.width;
    h := image.height;
    for y := 0; y < h; y += 1 {
        for x := 0; x < w; x += 1 {
            pt    := GetPoint(scene.camera, x, y, w, h);
            ray   := Ray {scene.camera.pos, pt};
            color := TraceRay(scene, ray, 0);
            image.data[y*h+x] = ToRgbColor(color);
        }
    }
}

Save :: proc (image: Image, fileName: string) {
    
    bmpInfoHeader := BITMAPINFOHEADER{};
    bmpInfoHeader.biSize = size_of(BITMAPINFOHEADER);
    bmpInfoHeader.biBitCount = 32;
    bmpInfoHeader.biClrImportant = 0;
    bmpInfoHeader.biClrUsed = 0;
    bmpInfoHeader.biCompression = 0;
    bmpInfoHeader.biHeight = LONG(-image.height);
    bmpInfoHeader.biWidth  = LONG(image.width);
    bmpInfoHeader.biPlanes = 1;
    bmpInfoHeader.biSizeImage = DWORD(image.width * image.height * 4);

    bfh := BITMAPFILEHEADER{};
    bfh.bfType = 'B' + ('M' << 8);
    bfh.bfOffBits = size_of(BITMAPINFOHEADER) + size_of(BITMAPFILEHEADER);
    bfh.bfSize = bfh.bfOffBits + bmpInfoHeader.biSizeImage;

    f, err := os.open(fileName, os.O_WRONLY | os.O_CREATE);
    if err == os.ERROR_NONE {
        os.write_ptr(f, &bfh, size_of(bfh));
        os.write_ptr(f, &bmpInfoHeader, size_of(bmpInfoHeader));
        os.write_ptr(f, &image.data[0], len(image.data) * size_of(RgbColor));
    }
    os.close(f);
};

main :: proc() {
    scene := CreateScene();
    image := CreateImage(500, 500);
    Render(scene, image);
    Save(image, "odin-ray.bmp");
}