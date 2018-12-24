const std = @import("std");

const RGBColor = struct {
    b: u8,
    g: u8,
    r: u8,
    a: u8,
}

const Vector = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vector
    {
        return Vector {.x = x, .y = y, .z = z}
    }

    pub fn scale(self: Vector, k: f32) Vector
    {
        return Vector.init(k * self.x, k * self.y, k * self.z);
    }

    pub fn add(self: Vector, v: Vector) Vector
    {
        return Vector.init(self.x + v.x, self.y + v.y, self.z + v.z);
    }

	pub fn sub(self: Vector, v: Vector) Vector
	{
		return Vector.init(self.x - v.x, self.y - v.y, self.z - v.z);
	}

	pub fn dot(self: Vector, v: Vector) f32
	{
		return self.x * v.x + self.y * v.y + self.z * v.z;
	}

    pub fn mag(self: Vector) f32
    {
        return sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn norm(self: Vector) f32
    {
        const magnitude = self.mag;
        const div = (mag == 0) ? double.infinity : 1.0 / magnitude;
        return div * self;
    }

	pub fn cross(self: Vector, v: Vector) Vector
	{
		return Vector.init(self.y * v.z - self.z * v.y,
					       self.z * v.x - self.x * v.z,
					       self.x * v.y - self.y * v.x);
	}
}

const Color = struct {
    r: f32 = 0,
    g: f32 = 0,
    b: f32 = 0,

    // static immutable Color white = Color(1.0, 1.0, 1.0);
    // static immutable Color grey  = Color(0.5, 0.5, 0.5);
    // static immutable Color black = Color(0.0, 0.0, 0.0);
    // static immutable Color background   = black;
    // static immutable Color defaultColor = black;

    pub fn init(r: f32, g: f32, b: f32) Vector
    {
        return Color{.r = r, .g = g, .b = b};
    }

	pub fn scale(self: Color, k: f32)
	{
		return Color.init(k * self.r, k * self.g, k * self.b);
	}

	pub fn add(self: Color, color: Color) Color
	{
		return Color.init(self.r + color.r, self.g + color.g, self.b + color.b);
	}

	pub fn scale(self: Color, c: Color) Color
	{
		self.r = self.r * c.r;
		self.g = self.g * c.g;
		self.b = self.b * c.b;
		return self;
	}

	pub fn add(self: Color, c: Color) Color
	{
		self.r = self.r + c.r;
		self.g = self.g + c.g;
		self.b = self.b + c.b;
		return self;
	}

    pub fn toDrawingColor(self: Color) ColorRGB
    {
        // RGBColor color;
        // color.r = to!ubyte(legalize(r));
        // color.g = to!ubyte(legalize(g));
        // color.b = to!ubyte(legalize(b));
        // color.a = 255;
        // return color;
    }

    pub fn legalize(c: f32) u8
    {
        const x = i32(c * 255.0);
        if (x < 0) x = 0;
        if (x > 255) x = 255;
        return x;
    }
}

const Camera = struct {
    forward: Vector,
    right: Vector,
    up: Vector,
    pos: Vector,

    pub fn init(pos: Vector, lookAt: Vector) Camera
    {
        const down    = Vector.init(0.0, -1.0, 0.0);
        const forward = lookAt.sub(pos);

        return Camera{
            .pos = pos,
            .forward = forward.norm(),
            .right   = forward.cross(down).norm.scale(1.5);
            .up      = forward.cross(this.right).norm.scale(1.5);
        };
    }
}

const Ray = struct {
    start: Vector,
    dir: Vector,

    pub fn init(start: Vector, dir: Vector) Ray
    {
        return Ray{.start = start, .dir = dir};
    }
}

const Intersection = struct {
    thing: Thing,
    ray: Ray,
    dist: f32,

    pub fn init(thing: Thing, ray: Ray, dist: f32) Intersection
    {
        return Intersection{.thing = thing, .ray = ray, .dist = dist};
    }
}

class Surface
{
public:
    Color  diffuse(ref Vector pos)  { return Color.black; };
    Color  specular(ref Vector pos) { return Color.black; };
    double reflect(ref Vector pos)  { return 0; };
    double roughness()              { return 0; };
}

// interface Thing
// {
//     Nullable!Intersection intersect(ref Ray ray);
//     Vector normal(ref Vector pos);
//     Surface surface();
// }

const Light = struct {
    Vector pos;
    Color color;

    pub fn init(pos: Vector, color: Color) Light
    {
        return Light{.pos = pos, .color = color};
    }
}

// interface Scene
// {
//     Thing[] things();
//     Light[] lights();
//     Camera camera();
// }

class Sphere : Thing
{
public:
    double radius2;
    Vector center;
    Surface _surface;

    this(Vector center, double radius, Surface surface)
    {
        this.radius2 = radius * radius;
        this.center = center;
        this._surface = surface;
    }

    Vector normal(ref Vector pos)
    {
        return (pos - this.center).norm;
    }

    Nullable!Intersection intersect(ref Ray ray)
    {
        Nullable!Intersection result;

        Vector eo = this.center - ray.start;
        double v  = eo.dot(ray.dir);
        double dist = 0;
        if (v >= 0)
        {
            double disc = this.radius2 - (eo.dot(eo) - v * v);
            if (disc >= 0)
            {
                dist = v - sqrt(disc);
            }
        }

        if (dist == 0)
        {
            return result;
        }
        result = Intersection(this, ray, dist);
        return result;
    }

    Surface surface()
    {
        return _surface;
    }
}

class Plane: Thing
{
private:
    Vector norm;
    double offset;
	Surface _surface;

public:
    Vector normal(ref Vector pos)
    {
        return this.norm;
    }

    Nullable!Intersection intersect(ref Ray ray)
    {
        Nullable!Intersection result;

        double denom = norm.dot(ray.dir);
        if (denom > 0)
        {
            return result;
        }
        double dist = (norm.dot(ray.start) + offset) / (-denom);
        result = Intersection(this, ray, dist);
        return result;
    }

    this(Vector norm, double offset, Surface surface)
    {
        this._surface = surface;
        this.norm = norm;
        this.offset = offset;
    }

    Surface surface()
    {
        return _surface;
    }
}

class ShinySurface: Surface
{
    override Color diffuse(ref Vector pos)
    {
        return Color.white;
    }

    override Color specular(ref Vector pos)
    {
        return Color.grey;
    }

    override double reflect(ref Vector pos)
    {
        return 0.7;
    }

    override double roughness()
    {
        return 250.0;
    }
}

class CheckerboardSurface : Surface
{
public:
    override Color diffuse(ref Vector pos)
    {
        if (to!int(floor(pos.z) + floor(pos.x))  % 2 != 0)
        {
            return Color.white;
        }
        return Color.black;
    }

    override Color specular(ref Vector pos)
    {
        return Color.white;
    }

    override double reflect(ref Vector pos)
    {
        if (to!int(floor(pos.z) + floor(pos.x)) % 2 != 0)
        {
            return 0.1;
        }
        return 0.7;
    }

    override double roughness()
    {
        return 150.0;
    }
}

class DefaultScene: Scene
{
//private:
    Thing[] m_things;
    Light[] m_lights;
    Camera  m_camera;
public:
    this()
    {
        ShinySurface        shiny        = new ShinySurface();
        CheckerboardSurface checkerboard = new CheckerboardSurface();

        m_things = [
            cast(Thing)new Plane (Vector(0.0, 1.0, 0.0),   0.0, checkerboard),
            cast(Thing)new Sphere(Vector(0.0, 1.0, -0.25), 1.0, shiny),
            cast(Thing)new Sphere(Vector(-1.0, 0.5, 1.5),  0.5, shiny)
        ];

        m_lights = [
            new Light(Vector(-2.0, 2.5, 0.0), Color(0.49, 0.07, 0.07)),
            new Light(Vector(1.5, 2.5, 1.5),  Color(0.07, 0.07, 0.49)),
            new Light(Vector(1.5, 2.5, -1.5), Color(0.07, 0.49, 0.071)),
            new Light(Vector(0.0, 3.5, 0.0),  Color(0.21, 0.21, 0.35)),
        ];

        m_camera = new Camera(Vector(3.0, 2.0, 4.0), Vector(-1.0, 0.5, 0.0));
    }

    Thing[] things()
    {
        return m_things;
    }

    Light[] lights()
    {
        return m_lights;
    }

    Camera camera()
    {
        return m_camera;
    }
}

class RayTracerEngine
{
private:
    static const int maxDepth = 5;

    Nullable!Intersection intersections(ref Ray ray, Scene scene)
    {
        double closest = double.infinity;
        Nullable!Intersection closestInter;

        foreach (thing; scene.things())
        {
            auto inter = thing.intersect(ray);
            if (!inter.isNull && inter.dist < closest)
            {
                closestInter = inter;
                closest = inter.dist;
            }
        }
        return closestInter;
    }

    double testRay(ref Ray ray, Scene scene)
    {
        Nullable!Intersection isect = this.intersections(ray, scene);
        if (!isect.isNull)
        {
            return isect.dist;
        }
        return double.nan;
    }

    Color traceRay(ref Ray ray, Scene scene, int depth)
    {
        Nullable!Intersection isect = this.intersections(ray, scene);
        if (isect.isNull)
        {
            return Color.background;
        }
        return this.shade(isect, scene, depth);
    }

    Color shade(ref Intersection isect, Scene scene, int depth)
    {
        Vector d      = isect.ray.dir;
        Vector pos    = isect.dist * d + isect.ray.start;
        Vector normal = isect.thing.normal(pos);

		Vector vec         = 2.0 * (normal.dot(d) * normal);
		Vector reflectDir  = d - vec;

        Color naturalColor = this.getNaturalColor(isect.thing, pos, normal, reflectDir, scene) + Color.background;

		Color getReflectionColor()
		{
			Ray ray = Ray(&pos, &reflectDir);
			return isect.thing.surface.reflect(pos) * this.traceRay(ray, scene, depth + 1);
		}

		Color reflectedColor;
		if (depth >= this.maxDepth) {
			reflectedColor = Color.grey;
		} else {
			reflectedColor = getReflectionColor();
		}
		return naturalColor + reflectedColor;
    }

    Color getNaturalColor(Thing thing, ref Vector pos, ref Vector norm, ref Vector rd, Scene scene)
    {
		Color   resultColor = Color.black;
		Surface surface = thing.surface;
		Vector  rayDirNormal = rd.norm();

		Color colDiffuse  = surface.diffuse(pos);
		Color colSpecular = surface.specular(pos);

		Color lcolor;
		Color scolor;
		//Vector ldis;
		//Vector livec;

		Ray ray;
		ray.start = &pos;

		void addLight(Light light)
		{
			Vector ldis    = light.pos - pos;
			Vector livec   = ldis.norm;
			ray.dir = &livec;

			double neatIsect  = testRay(ray, scene);
			bool   isInShadow = (neatIsect == double.nan) ? false : (neatIsect <= ldis.mag);

			if (isInShadow) {
				return;
			}

			double illum    = livec.dot(norm);
			double specular = livec.dot(rayDirNormal);

			lcolor = (illum > 0)    ? illum                            * light.color : Color.defaultColor;
			scolor = (specular > 0) ? pow(specular, surface.roughness) * light.color : Color.defaultColor;

			lcolor.scale(colDiffuse);
			scolor.scale(colSpecular);

			resultColor.add(lcolor).add(scolor);
		}

		foreach (item; scene.lights)
		{
		    addLight(item);
		}

        return resultColor;
    }


    inout Vector getPoint(int x, int y, Camera camera, int screenWidth, int screenHeight, int scale)
    {
        double recenterX =  (x - (screenWidth / 2.0)) / 2.0 / scale;
        double recenterY = -(y - (screenHeight / 2.0)) / 2.0 / scale;

		Vector vx = recenterX * camera.right;
		Vector vy = recenterY * camera.up;
		Vector v  = vx + vy;

        return (camera.forward + v).norm;
    }

public:
    void render(Scene scene, ubyte[] bitmapData, int stride, int w, int h)
    {
        import std.algorithm.comparison;

        Camera camera = scene.camera;
		Ray ray;
		ray.start = &camera.pos;

        int scale = min(w,h);

		Color result;

        for (int y = 0; y < h; ++y)
        {
            int pos = y * stride;
            RGBColor* ptrColor = (cast(RGBColor*)&bitmapData[pos]);

            for (int x = 0; x < w; ++x) {
				Vector dir   = this.getPoint(x, y, camera, w, h, scale);
				ray.dir      = &dir;
                *ptrColor++  = this.traceRay(ray, scene, 0).toDrawingColor;
            }
        }
    }
}

void SaveRGBBitmap(ubyte[] pBitmapBits, int lWidth, int lHeight, int wBitsPerPixel, string fileName )
{
    const BI_RGB = 0;

    BITMAPINFOHEADER bmpInfoHeader = {};
    bmpInfoHeader.biSize = BITMAPINFOHEADER.sizeof;
    bmpInfoHeader.biBitCount = cast(WORD)wBitsPerPixel;
    bmpInfoHeader.biClrImportant = 0;
    bmpInfoHeader.biClrUsed = 0;
    bmpInfoHeader.biCompression = BI_RGB;
    bmpInfoHeader.biHeight = -lHeight;
    bmpInfoHeader.biWidth = lWidth;
    bmpInfoHeader.biPlanes = 1;
    bmpInfoHeader.biSizeImage = lWidth* lHeight * (wBitsPerPixel/8);

    struct BITMAPFILEHEADER
    {
        //align(1):
        WORD  bfType;
        DWORD bfSize;
        WORD  bfReserved1;
        WORD  bfReserved2;
        DWORD bfOffBits;
    };

    BITMAPFILEHEADER bfh = {};
    bfh.bfType    = 'B' + ('M' << 8);
    bfh.bfOffBits = BITMAPINFOHEADER.sizeof + 14; // BITMAPFILEHEADER.sizeof;
    bfh.bfSize    = bfh.bfOffBits + bmpInfoHeader.biSizeImage;

    auto file = File(fileName, "wb");

    file.rawWrite((cast(ubyte*)&bfh)[0..2]); //Skip padded bytes
    file.rawWrite((cast(ubyte*)&bfh)[4..16]);
    file.rawWrite((cast(ubyte*)&bmpInfoHeader)[0 .. 40]);
    file.rawWrite(pBitmapBits);
    file.close();
}

int main(string[] argv)
{
    writeln("Starting");
    StopWatch sw;
    sw.start();

    int width  = 500;
    int height = 500;
    int stride = width * 4;
    ubyte[] bitmapData = new ubyte[stride * height];

    Scene scene = new DefaultScene();
    RayTracerEngine rayTracer = new RayTracerEngine();

    rayTracer.render(scene, bitmapData, stride,width,height);
    sw.stop();

    SaveRGBBitmap(bitmapData, width,height, 32, "d-raytracer.bmp");

    writeln("Completed in: ", sw.peek.msecs, " [ms]");

    readln;
    return 0;
}

pub fn main() !void {
    // If this program is run without stdout attached, exit with an error.
    var stdout_file = try std.io.getStdOut();
    // If this program encounters pipe failure when printing to stdout, exit
    // with an error.
    try stdout_file.write("Hello, world!\n");
}