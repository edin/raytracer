const std = @import("std");

const RGBColor = struct {
    b: u8,
    g: u8,
    r: u8,
    a: u8,
};

const WORD = u16;
const DWORD = u32;
const LONG = i32;

const BITMAPINFOHEADER = struct {
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
    biClrImportant: DWORD,
};

const BITMAPFILEHEADER = packed struct {
    bfType: WORD,
    bfSize: DWORD,
    bfReserved1: WORD,
    bfReserved2: WORD,
    bfOffBits: DWORD,
};

const Vector = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vector {
        return Vector{ .x = x, .y = y, .z = z };
    }

    pub fn scale(self: Vector, k: f32) Vector {
        return Vector.init(k * self.x, k * self.y, k * self.z);
    }

    pub fn add(self: Vector, v: Vector) Vector {
        return Vector.init(self.x + v.x, self.y + v.y, self.z + v.z);
    }

    pub fn sub(self: Vector, v: Vector) Vector {
        return Vector.init(self.x - v.x, self.y - v.y, self.z - v.z);
    }

    pub fn dot(self: Vector, v: Vector) f32 {
        return self.x * v.x + self.y * v.y + self.z * v.z;
    }

    pub fn mag(self: Vector) f32 {
        return sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn norm(self: Vector) f32 {
        const magnitude = self.mag;
        const div = if (mag == 0.0) {
            double.infinity;
        } else {
            1.0 / magnitude;
        };
        return div * self;
    }

    pub fn cross(self: Vector, v: Vector) Vector {
        return Vector.init(self.y * v.z - self.z * v.y, self.z * v.x - self.x * v.z, self.x * v.y - self.y * v.x);
    }
};

const Color = struct {
    r: f32 = 0,
    g: f32 = 0,
    b: f32 = 0,

    pub fn init(r: f32, g: f32, b: f32) Color {
        return Color{ .r = r, .g = g, .b = b };
    }

    pub fn scale(self: Color, k: f32) Color {
        return Color.init(k * self.r, k * self.g, k * self.b);
    }

    pub fn add(self: Color, color: Color) Color {
        return Color.init(self.r + color.r, self.g + color.g, self.b + color.b);
    }

    pub fn scale(self: Color, c: Color) Color {
        self.r = self.r * c.r;
        self.g = self.g * c.g;
        self.b = self.b * c.b;
        return self;
    }

    pub fn add(self: Color, c: Color) Color {
        self.r = self.r + c.r;
        self.g = self.g + c.g;
        self.b = self.b + c.b;
        return self;
    }

    pub fn toDrawingColor(self: Color) RGBColor {
        return RGBColor{
            .r = clamp(r),
            .g = clamp(g),
            .b = clamp(b),
            .a = 255,
        };
    }

    pub fn clamp(c: f32) u8 {
        const x = i32(c * 255.0);
        if (x < 0) x = 0;
        if (x > 255) x = 255;
        return u8(x);
    }
};

const FarAway = 1000000.0;

const White = Color(1.0, 1.0, 1.0);
const Grey = Color(0.5, 0.5, 0.5);
const Black = Color(0.0, 0.0, 0.0);
const Background = Black;
const DefaultColor = Black;

const Camera = struct {
    forward: Vector,
    right: Vector,
    up: Vector,
    pos: Vector,

    pub fn init(pos: Vector, lookAt: Vector) Camera {
        const down = Vector.init(0.0, -1.0, 0.0);
        const forward = lookAt.sub(pos);

        return Camera{
            .pos = pos,
            .forward = forward.norm(),
            .right = forward.cross(down).norm.scale(1.5),
            .up = forward.cross(this.right).norm.scale(1.5),
        };
    }
};

const Ray = struct {
    start: Vector,
    dir: Vector,

    pub fn init(start: Vector, dir: Vector) Ray {
        return Ray{ .start = start, .dir = dir };
    }
};

const Intersection = struct {
    thing: Thing,
    ray: Ray,
    dist: f32,

    pub fn init(thing: Thing, ray: Ray, dist: f32) Intersection {
        return Intersection{ .thing = thing, .ray = ray, .dist = dist };
    }
};

const SurfaceProperties = struct {
    diffuse: Color,
    specular: Color,
    reflect: double,
    roughness: double,
};

const Light = struct {
    pos: Vector,
    color: Color,
    pub fn init(pos: Vector, color: Color) Light {
        return Light{ .pos = pos, .color = color };
    }
};

const ThingType = enum {
    Plane,
    Sphere,
};

const Surface = enum {
    ShinySurface,
    CheckerboardSurface,
};

const Thing = union(ThingType) {
    Plane: struct {
        norm: Vector, offset: double, surface: Surface
    },
    Sphere: struct {
        center: Vector, radius2: double, surface: Surface
    },
};

fn GetNormal(thing: Thing, pos: Vector) Vector {
    return switch (thing) {
        ThingType.Plane => |plane| p.norm,
        ThingType.Sphere => |sphere| (pos.sub(sphere.center)).norm(),
    };
}

fn GetIntersection(thing: Thing, ray: Ray) ?Intersection {
    return switch (thing) {
        ThingType.Plane => |plane| {
            denom = plane.norm.dot(ray.dir);
            if (denom > 0) {
                return null;
            }
            dist = (plane.norm.dot(ray.start) + plane.offset) / (-denom);
            return Intersection(this, ray, dist);
        },
        ThingType.Sphere => |sphere| {
            var eo = sphere.center.sub(ray.start);
            var v = eo.dot(ray.dir);
            var dist = 0;
            if (v >= 0) {
                var disc = sphere.radius2 - (eo.dot(eo) - v * v);
                if (disc >= 0) {
                    dist = v - sqrt(disc);
                }
            }
            if (dist == 0) {
                return null;
            }
            return Intersection(this, ray, dist);
        },
    };
}

fn GetSurfacePropertis(surface: Surface, pos: Vector) SurfaceProperties {
    return switch (surface) {
        Surface.ShinySurface => {
            SurfaceProperties{
                .diffuse = White,
                .specular = Grey,
                .reflect = 0.7,
                .roughness = 250.0,
            };
        },
        Surface.CheckerboardSurface => {
            var condition = int(floor(pos.z) + floor(pos.x)) % 2 != 0;
            var color = Black;
            var reflect = 0.7;
            if (condition) {
                color = White;
                reflect = 0.1;
            }
            return SurfaceProperties{
                .diffuse = color,
                .specular = white,
                .reflect = reflect,
                .roughness = 150.0,
            };
        },
    };
}

const Scene = struct {
    things: []Thing,
    lights: []Light,
    camera: Camera,
    pub fn init() Scene {
        things = []Thing{
            Plane(Vector(0.0, 1.0, 0.0), 0.0, Checkerboard),
            Sphere(Vector(0.0, 1.0, -0.25), 1.0, Shiny),
            Sphere(Vector(-1.0, 0.5, 1.5), 0.5, Shiny),
        };
        lights = []Light{
            Light(Vector(-2.0, 2.5, 0.0), Color(0.49, 0.07, 0.07)),
            Light(Vector(1.5, 2.5, 1.5), Color(0.07, 0.07, 0.49)),
            Light(Vector(1.5, 2.5, -1.5), Color(0.07, 0.49, 0.071)),
            Light(Vector(0.0, 3.5, 0.0), Color(0.21, 0.21, 0.35)),
        };
        camera = Camera(Vector(3.0, 2.0, 4.0), Vector(-1.0, 0.5, 0.0));
        return Scene{ .things = things, .lights = lights, .camera = camera };
    }
};

const Image = struct {
    width: int,
    height: int,
    data: [*]RGBColor,

    pub fn init(w: int, h: int) Image {
        var data = try std.heap.c_allocator.alloc(RGBColor, w * h);
        return Image{ .width = w, .height = h, .data = data };
    }

    pub fn setColor(self: Image, x: int, y: int, c: RGBColor) void {
        self.data.*[y * self.width + x] = c;
    }

    pub fn save(fileName: string) void {
        // bmpInfoHeader := BITMAPINFOHEADER{};
        // bmpInfoHeader.biSize = size_of(BITMAPINFOHEADER);
        // bmpInfoHeader.biBitCount = 32;
        // bmpInfoHeader.biClrImportant = 0;
        // bmpInfoHeader.biClrUsed = 0;
        // bmpInfoHeader.biCompression = 0;
        // bmpInfoHeader.biHeight = LONG(-image.height);
        // bmpInfoHeader.biWidth  = LONG(image.width);
        // bmpInfoHeader.biPlanes = 1;
        // bmpInfoHeader.biSizeImage = DWORD(image.width * image.height * 4);

        // bfh := BITMAPFILEHEADER{};
        // bfh.bfType = 'B' + ('M' << 8);
        // bfh.bfOffBits = size_of(BITMAPINFOHEADER) + size_of(BITMAPFILEHEADER);
        // bfh.bfSize = bfh.bfOffBits + bmpInfoHeader.biSizeImage;

        // f, err := os.open(fileName, os.O_WRONLY | os.O_CREATE);
        // if err == os.ERROR_NONE {
        //     os.write_ptr(f, &bfh, size_of(bfh));
        //     os.write_ptr(f, &bmpInfoHeader, size_of(bmpInfoHeader));
        //     os.write_ptr(f, &image.data[0], len(image.data) * size_of(RgbColor));
        // }
        // os.close(f);
    }
};

pub fn GetClosestIntersection(scene: Scene, ray: Ray) ?Intersection {
    var closest = FarAway;
    var closestInter: ?Intersection = null;

    for (scene.things) |thing| {
        var isect = GetIntersection(thing, ray);
        if (isect != null and isect.dist < closest) {
            closestInter = inter;
            closest = inter.dist;
        }
    }
    return closestInter;
}

pub fn TraceRay(scene: Scene, ray: Ray, depth: int) Color {
    var isect = GetClosestIntersection(scene, ray);
    if (isect == null) {
        return Color.background;
    }
    return Shade(isect, scene, depth);
}

pub fn Shade(scene: Scene, isect: Intersection, depth: int) Color {
    var d = isect.ray.dir;
    var pos = d.scale(isect.dist).add(isect.ray.start);
    var normal = GetNormal(isect.thing, pos);

    var vec = normal.scale(normal.dot(d) * 2.0);
    var reflectDir = d.sub(vec);

    var naturalColor = background.add(GetNaturalColor(scene, isect.thing, pos, normal, reflectDir, scene));
    var reflectedColor = Grey;
    if (depth < this.maxDepth) {
        reflectedColor = getReflectionColor();
    }
    return naturalColor.add(reflectedColor);
}

pub fn GetReflectionColor() Color {
    var ray = Ray(&pos, &reflectDir);
    var reflect = isect.thing.surface.reflect(pos);
    return this.traceRay(ray, scene, depth + 1).scale(reflect);
}

pub fn GetNaturalColor(thing: ThingType, pos: Vector, norm: Vector, rd: Vector, scene: Vector) Color {
    var resultColor = Black;
    var surface = thing.surface;
    var rayDirNormal = rd.norm();

    var colDiffuse = surface.diffuse(pos);
    var colSpecular = surface.specular(pos);

    for (scene.lights) |light| {
        var ldis = light.pos - pos;
        var livec = ldis.norm;
        var ray = Ray(pos, livec);

        var isect = GetClosestIntersection(scene, ray);
        var isInShadow = (isect == null) and (isect.dist <= ldis.mag());

        if (!isInShadow) {
            var illum = livec.dot(norm);
            var specular = livec.dot(rayDirNormal);

            var lcolor = DefaultColor;
            var scolor = DefaultColor;

            if (illum > 0) {
                lcolor = light.color.scale(illum);
            }
            if (specular > 0) {
                scolor = light.color.scale(pow(specular, surface.roughness));
            }

            lcolor.scale(colDiffuse);
            scolor.scale(colSpecular);

            resultColor.add(lcolor).add(scolor);
        }
    }

    return resultColor;
}

pub fn GetPoint(camera: Camera, x: int, y: int, screenWidth: int, screenHeight: int) Vector {
    var recenterX = (x - (screenWidth / 2.0)) / 2.0 / screenWidth;
    var recenterY = -(y - (screenHeight / 2.0)) / 2.0 / screenHeight;

    var vx = camera.right.scale(recenterX);
    var vy = camera.up.scale(recenterY);
    var v = vx.add(vy);

    return camera.forward.add(v).norm();
}

pub fn Render(scene: Scene, image: Image) void {
    var x: int = 0;
    var y: int = 0;

    while (y < image.height) {
        x = 0;
        while (x < image.width) {
            var pt = GetPoint(camera, x, y, w, h);
            var ray = Ray(scene.camera.pos, pt);
            var color = TraceRay(scene, ray, 0).toDrawingColor();
            image.setColor(x, y, color);
            x += 1;
        }
        y += 1;
    }
}

pub fn main() !void {
    const stdout = std.io.getStdOut().outStream();

    var image = Image(500, 500);
    var scene = Scene();
    Render(scene, image);
    image.save("zig-ray.bmp");

    try stdout.print("Completed, {}!\n", .{"OK"});
}
