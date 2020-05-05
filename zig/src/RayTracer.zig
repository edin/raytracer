const std = @import("std");
const Allocator = std.mem.Allocator;

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
    x: f64,
    y: f64,
    z: f64,

    pub fn init(x: f64, y: f64, z: f64) Vector {
        return Vector{ .x = x, .y = y, .z = z };
    }

    pub fn scale(self: Vector, k: f64) Vector {
        return Vector.init(k * self.x, k * self.y, k * self.z);
    }

    pub fn add(self: Vector, v: Vector) Vector {
        return Vector.init(self.x + v.x, self.y + v.y, self.z + v.z);
    }

    pub fn sub(self: Vector, v: Vector) Vector {
        return Vector.init(self.x - v.x, self.y - v.y, self.z - v.z);
    }

    pub fn dot(self: Vector, v: Vector) f64 {
        return self.x * v.x + self.y * v.y + self.z * v.z;
    }

    pub fn mag(self: Vector) f64 {
        return std.math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn norm(self: Vector) Vector {
        var magnitude = self.mag();
        var div: f64 = 0.0;
        if (magnitude == 0.0) {
            div = FarAway;
        } else {
            div = 1.0 / magnitude;
        }
        return self.scale(div);
    }

    pub fn cross(self: Vector, v: Vector) Vector {
        return Vector.init(self.y * v.z - self.z * v.y, self.z * v.x - self.x * v.z, self.x * v.y - self.y * v.x);
    }
};

const Color = struct {
    r: f64 = 0,
    g: f64 = 0,
    b: f64 = 0,

    pub fn init(r: f64, g: f64, b: f64) Color {
        return Color{ .r = r, .g = g, .b = b };
    }

    pub fn scale(self: Color, k: f64) Color {
        return Color.init(k * self.r, k * self.g, k * self.b);
    }

    pub fn add(self: Color, color: Color) Color {
        return Color.init(self.r + color.r, self.g + color.g, self.b + color.b);
    }

    pub fn mul(self: Color, color: Color) Color {
        return Color.init(self.r * color.r, self.g * color.g, self.b * color.b);
    }

    pub fn toDrawingColor(self: Color) RGBColor {
        return RGBColor{
            .r = clamp(self.r),
            .g = clamp(self.g),
            .b = clamp(self.b),
            .a = 255,
        };
    }

    pub fn clamp(c: f64) u8 {
        if (c < 0.0) return 1;
        if (c > 1.0) return 255;
        return @floatToInt(u8, c * 255.0);
    }
};

const FarAway = 1000000.0;
const MaxDepth = 5;
const White = Color.init(1.0, 1.0, 1.0);
const Grey = Color.init(0.5, 0.5, 0.5);
const Black = Color.init(0.0, 0.0, 0.0);
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
        const right = forward.cross(down).norm().scale(1.5);
        const up = forward.cross(right).norm().scale(1.5);
        return Camera{
            .pos = pos,
            .forward = forward.norm(),
            .right = right,
            .up = up,
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
    dist: f64,

    pub fn init(thing: Thing, ray: Ray, dist: f64) Intersection {
        return Intersection{ .thing = thing, .ray = ray, .dist = dist };
    }
};

const SurfaceProperties = struct {
    diffuse: Color,
    specular: Color,
    reflect: f64,
    roughness: f64,
};

const Light = struct {
    pos: Vector,
    color: Color,
    pub fn init(pos: Vector, color: Color) Light {
        return Light{ .pos = pos, .color = color };
    }
};

const Surface = enum {
    ShinySurface,
    CheckerboardSurface,
};

const Thing = union(enum) {
    Plane: struct {
        norm: Vector, offset: f64, surface: Surface
    },
    Sphere: struct {
        center: Vector, radius2: f64, surface: Surface
    },
};

fn GetNormal(thing: Thing, pos: Vector) Vector {
    return switch (thing) {
        Thing.Plane => |plane| plane.norm,
        Thing.Sphere => |sphere| (pos.sub(sphere.center)).norm(),
    };
}

fn GetSurface(thing: Thing) Surface {
    return switch (thing) {
        Thing.Plane => |plane| plane.surface,
        Thing.Sphere => |sphere| sphere.surface,
    };
}

fn GetIntersection(thing: Thing, ray: Ray) ?Intersection {
    return switch (thing) {
        Thing.Plane => |plane| {
            var denom = plane.norm.dot(ray.dir);
            if (denom > 0) {
                return null;
            }
            var dist = (plane.norm.dot(ray.start) + plane.offset) / (-denom);
            return Intersection.init(thing, ray, dist);
        },
        Thing.Sphere => |sphere| {
            var eo = sphere.center.sub(ray.start);
            var v = eo.dot(ray.dir);
            var dist: f64 = 0.0;
            if (v >= 0) {
                var disc = sphere.radius2 - (eo.dot(eo) - v * v);
                if (disc >= 0) {
                    dist = v - std.math.sqrt(disc);
                }
            }
            if (dist == 0) {
                return null;
            }
            return Intersection.init(thing, ray, dist);
        },
    };
}

fn GetSurfaceProperties(surface: Surface, pos: Vector) SurfaceProperties {
    return switch (surface) {
        Surface.ShinySurface => {
            return SurfaceProperties{
                .diffuse = White,
                .specular = Grey,
                .reflect = 0.7,
                .roughness = 250.0,
            };
        },
        Surface.CheckerboardSurface => {
            var condition = @mod(@floatToInt(i32, std.math.floor(pos.z) + std.math.floor(pos.x)), 2) != 0;
            var color = Black;
            var reflect: f64 = 0.7;
            if (condition) {
                color = White;
                reflect = 0.1;
            }
            return SurfaceProperties{
                .diffuse = color,
                .specular = White,
                .reflect = reflect,
                .roughness = 150.0,
            };
        },
    };
}

const Scene = struct {
    things: [3]Thing,
    lights: [4]Light,
    camera: Camera,
    pub fn init() Scene {
        var things = [3]Thing{
            Thing{ .Plane =  .{ .norm   = Vector.init(0.0, 1.0, 0.0), .offset = 0.0, .surface = Surface.CheckerboardSurface } },
            Thing{ .Sphere = .{ .center = Vector.init(0.0, 1.0, -0.25), .radius2 = 1.0, .surface = Surface.ShinySurface } },
            Thing{ .Sphere = .{ .center = Vector.init(-1.0, 0.5, 1.5), .radius2 = 0.25, .surface = Surface.ShinySurface } },
        };
        var lights = [4]Light{
            Light.init(Vector.init(-2.0, 2.5, 0.0), Color.init(0.49, 0.07, 0.07)),
            Light.init(Vector.init(1.5, 2.5, 1.5), Color.init(0.07, 0.07, 0.49)),
            Light.init(Vector.init(1.5, 2.5, -1.5), Color.init(0.07, 0.49, 0.071)),
            Light.init(Vector.init(0.0, 3.5, 0.0), Color.init(0.21, 0.21, 0.35)),
        };
        var camera = Camera.init(Vector.init(3.0, 2.0, 4.0), Vector.init(-1.0, 0.5, 0.0));
        return Scene{ .things = things, .lights = lights, .camera = camera };
    }
};

const Image = struct {

    width: i32,
    height: i32,
    data: [*]RGBColor,

    pub fn init(allocator: *Allocator, w: i32, h: i32) Image {
        var size: usize = @intCast(usize, w*h);

        var data = try allocator.alloc(RGBColor, size);
        return Image{ .width = w, .height = h, .data = data };
    }

    pub fn setColor(self: Image, x: i32, y: i32, c: RGBColor) void {
        var idx: usize = @intCast(usize, y * self.width + x);
        self.data[idx] = c;
    }

    pub fn save(self:Image, fileName:[]const u8) void {
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
    var closest: f64 = FarAway;
    var closestInter: ?Intersection = null;

    for (scene.things) |thing| {
        var isect = GetIntersection(thing, ray);
        if (isect != null and isect.?.dist < closest) {
            closestInter = isect;
            closest = isect.?.dist;
        }
    }
    return closestInter;
}

pub fn TraceRay(scene: Scene, ray: Ray, depth: i32) Color {
    var isect = GetClosestIntersection(scene, ray);
    if (isect == null) {
        return Background;
    }
    return Shade(scene, isect.?, depth);
}

pub fn Shade(scene: Scene, isect: Intersection, depth: i32) Color {
    var d = isect.ray.dir;
    var pos = d.scale(isect.dist).add(isect.ray.start);
    var normal = GetNormal(isect.thing, pos);

    var vec = normal.scale(normal.dot(d) * 2.0);
    var reflectDir = d.sub(vec);

    var naturalColor = Background.add(GetNaturalColor(scene, isect.thing, pos, normal, reflectDir));
    var reflectedColor = Grey;
    if (depth < MaxDepth) {
        reflectedColor = GetReflectionColor(scene, isect.thing, pos, reflectDir, depth);
    }
    return naturalColor.add(reflectedColor);
}

pub fn GetReflectionColor(scene: Scene, thing: Thing, pos: Vector, reflectDir: Vector, depth: i32) Color {
    var ray = Ray.init(pos, reflectDir);
    var surface = GetSurfaceProperties(GetSurface(thing), pos);
    return TraceRay(scene, ray, depth + 1).scale(surface.reflect);
}

pub fn GetNaturalColor(scene: Scene, thing: Thing, pos: Vector, norm: Vector, rd: Vector) Color {
    var resultColor = Black;
    var surface = GetSurfaceProperties(GetSurface(thing), pos);
    var rayDirNormal = rd.norm();

    var colDiffuse = surface.diffuse;
    var colSpecular = surface.specular;

    for (scene.lights) |light| {
        var ldis = light.pos.sub(pos);
        var livec = ldis.norm();
        var ray = Ray.init(pos, livec);

        var isect = GetClosestIntersection(scene, ray);
        var isInShadow = isect != null and isect.?.dist < ldis.mag();

        if (!isInShadow) {
            var illum = livec.dot(norm);
            var specular = livec.dot(rayDirNormal);

            var lcolor = DefaultColor;
            var scolor = DefaultColor;

            if (illum > 0) {
                lcolor = light.color.scale(illum);
            }
            if (specular > 0) {
                scolor = light.color.scale(std.math.pow(f64, specular, surface.roughness));
            }

            lcolor = lcolor.mul(colDiffuse);
            scolor = scolor.mul(colSpecular);

            resultColor = resultColor.add(lcolor).add(scolor);
        }
    }

    return resultColor;
}

pub fn GetPoint(camera: Camera, x: i32, y: i32, screenWidth: i32, screenHeight: i32) Vector {
    var xf = @intToFloat(f64, x);
    var yf = @intToFloat(f64, y);
    var wf = @intToFloat(f64, screenWidth);
    var hf = @intToFloat(f64, screenHeight);

    var recenterX = (xf - (wf / 2.0)) / 2.0 / wf;
    var recenterY = -(yf - (hf / 2.0)) / 2.0 / hf;

    var vx = camera.right.scale(recenterX);
    var vy = camera.up.scale(recenterY);
    var v = vx.add(vy);

    return camera.forward.add(v).norm();
}

pub fn Render(scene: Scene, image: Image) void {
    var x: i32 = 0;
    var y: i32 = 0;

    while (y < image.height) {
        x = 0;
        while (x < image.width) {
            var pt = GetPoint(scene.camera, x, y, image.width, image.height);
            var ray = Ray.init(scene.camera.pos, pt);
            var color = TraceRay(scene, ray, 0).toDrawingColor();
            image.setColor(x, y, color);
            x += 1;
        }
        y += 1;
    }
}

pub fn main() !void {
    const stdout = std.io.getStdOut().outStream();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var data = allocator.alloc(RGBColor, 10);
    data[0] = RGBColor.init(0,0,0);

    try stdout.print("Data: {}!\n", .{ data });

    // var image = Image.init(allocator, 500, 500);
    // var scene = Scene.init();
    // Render(scene, image);
    // image.save("zig-ray.bmp");

    try stdout.print("Completed, {}!\n", .{"OK"});
}
