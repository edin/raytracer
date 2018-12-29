struct RgbColor
{
    b: u8,
    g: u8,
    r: u8,
    a: u8,
}

#[derive(Debug)]
struct Vector
{
    x: f32,
    y: f32,
    z: f32,
}

impl Vector
{
    fn new(x: f32, y: f32, z: f32) -> Vector
    {
        Vector { x: x, y: y, z: z }
    }

    fn mag(&self) -> f32
    {
        let value = self.x * self.x + self.y * self.y + self.z * self.z;
        value.sqrt()
    }

    fn norm(&self) -> Vector
    {
        let mag = self.mag();
        let mut div = 0.0;
        if mag == 0.0 {
            div = 1000000.0
        } else {
            div = 1.0 / mag
        }
        return self.scale(div)
    }

    fn cross(&self, v: Vector) -> Vector
    {
        Vector::new(
            self.y * v.z - self.z * v.y,
            self.z * v.x - self.x * v.z,
            self.x * v.y - self.y * v.x
        )
    }

    fn scale(&self, k: f32) -> Vector
    {
        Vector::new(k * self.x, k * self.y, k * self.z)
    }

    fn mul(&self, v: Vector) -> Vector
    {
        Vector::new(self.x * v.x, self.y * v.y, self.z * v.z)
    }

    fn add(&self, v: Vector) -> Vector
    {
        Vector::new(self.x + v.x, self.y + v.y, self.z + v.z)
    }

    fn sub(&self, v: Vector) -> Vector
    {
        Vector::new(self.x- v.x, self.y - v.y, self.z - v.z)
    }
}

struct Color
{
    r: f32,
    g: f32,
    b: f32,
}

const ColorWhite: Color = Color{r:1.0, g:1.0, b:1.0};
const ColorGrey:  Color = Color{r:0.5, g:0.5, b:0.5};
const ColorBlack: Color = Color{r:0.0, g:0.0, b:0.0};
const ColorBackground:   Color = ColorBlack;
const ColorDefaultColor: Color = ColorBlack;

impl Color
{
    fn new(r: f32, g: f32, b: f32) -> Color
    {
        Color{ r: r, g: g, b: b }
    }

    fn scale(&self, k: f32) -> Color
    {
        Color::new(k * self.r, k * self.g, k * self.b)
    }

    fn times(&self, c: Color) -> Color
    {
        Color::new(self.r * c.r, self.g * c.g, self.b * c.b)
    }

    fn mul(&self, c: Color) -> Color
    {
        Color::new(self.r * c.r, self.g * c.g, self.b * c.b)
    }

    fn add(&self, c: Color) -> Color
    {
        Color::new(self.r + c.r, self.g + c.g, self.b + c.b)
    }

    fn to_drawing_color(&self) -> RgbColor
    {
        RgbColor{
            r: Color::legalize(self.r),
            g: Color::legalize(self.g),
            b: Color::legalize(self.b),
            a: 255
        }
    }

    fn legalize(c: f32) -> u8
    {
        let mut x = (c * 255.0) as i32;
        if x < 0   {x = 0}
        if x > 255 {x = 255}
        return x as u8;
    }
}

struct Camera
{
    forward: Vector,
    right: Vector,
    up: Vector,
    pos: Vector,
}

impl Camera
{
    fn new(pos: Vector, lookAt: Vector) -> Camera
    {
        let down = Vector::new(0.0, -1.0, 0.0);
        let forward = lookAt.sub(pos).norm();

        Camera {
            pos: pos,
            forward: forward,
            right: forward.cross(down).norm() * 1.5,
            up: forward.cross(self.right).norm() * 1.5
        }
    }
}

struct Ray {
    start: Vector,
    dir: Vector,
}

struct Intersection {
    thing: Thing,
    ray: Ray,
    dist: f32,
}

trait Surface {
    fn diffuse(&self, pos: Vector) -> Color;
    fn specular(&self, pos: Vector) -> Color;
    fn reflect(&self, pos: Vector) -> f32;
    fn roughness(&self) -> f32;
}

trait Thing {
   fn intersect(&self, ray: Vector) -> Intersection;
   fn normal(&self, pos: Vector) -> Vector;
   fn surface(&self) -> Surface;
}

struct Light {
    pos:   Vector,
    color: Color
}

struct Sphere
{
    surface: Surface,
    radius2: f32,
    center: Vector,
}

impl Sphere {
    fn new(center: Vector, radius: f32, surface: Surface)
    {
        Sphere {
            surface: surface,
            radius2: radius * radius,
            center: center
        }
    }
}

impl Thing for Sphere
{
   fn intersect(&self, ray: Vector) -> Intersection
   {
        let eo = self.center.sub(ray.start);
        let v = eo * ray.dir;
        let mut dist = 0.0;

        if v >= 0.0 {
            let disc = self.radius2 - ((eo.dot(eo)) - (v * v));
            if disc >= 0.0 {
                dist = v - sqrt(disc);
            }
        }

        if dist == 0.0 {
            return Intersection();
        }
        return Intersection(this, ray, dist);
   }

   fn normal(&self, pos: Vector) -> Vector
   {
       self.center.sub(pos).norm()
   }

   fn surface(&self) -> Surface
   {
       self.surface
   }
}

impl Thing for Plane
{
    norm: Vector;
    offset: f32
    surface: Surface
}

impl Thing {
    fn new(&self, norm: Vector, offset: f32, surface: Surface)
    {
        self.norm = norm;
        self.offset = offset;
        self.surface = surface;
    }
}

impl Thing for Plane
{
    Vector normal(const Vector& pos) const override
    {
        return self.norm;
    }

    Intersection intersect(const Ray& ray) const override
    {
        double denom = norm * ray.dir;
        if (denom > 0) {
            return Intersection();
        }
        double dist = ((norm * ray.start) + offset) / (-denom);
        return Intersection(this, ray, dist);
    }

    Surface& surface() const override
    {
        return m_surface;
    }
}

class ShinySurface : public Surface
{
public:
    Color diffuse(const Vector& pos) const
    {
        return Color::white;
    }

    Color specular(const Vector& pos) const
    {
        return Color::grey;
    }

    double reflect(const Vector& pos) const
    {
        return 0.7;
    }

    double roughness() const
    {
        return 250.0;
    }
};

class CheckerboardSurface : public Surface
{
public:
    Color diffuse(const Vector& pos) const
    {
        if (((int)(floor(pos.z) + floor(pos.x))) % 2 != 0)
        {
            return Color::white;
        }
        return Color::black;
    }

    Color specular(const Vector& pos) const
    {
        return Color::white;
    }

    double reflect(const Vector& pos) const
    {
        if (((int)(floor(pos.z) + floor(pos.x))) % 2 != 0)
        {
            return 0.1;
        }
        return 0.7;
    }

    double roughness() const
    {
        return 150.0;
    }
};

fn main()
{
    let v = Vector::new(0.0, 0.0, 0.0);

    println!("Result {:?}", v);
}






// using ThingList = std::vector<std::unique_ptr<Thing>>;
// using LightList = std::vector<Light>;

// class Scene
// {
// public:
//     virtual ThingList const& things() const = 0;
//     virtual LightList const& lights() const = 0;
//     virtual Camera const& camera() const = 0;
// };

// class DefaultScene : public  Scene
// {
// private:
//     ThingList m_things;
//     LightList m_lights;
//     Camera    m_camera;

//     ShinySurface        shiny;
//     CheckerboardSurface checkerboard;

// public:
//     DefaultScene()
//     {
//         m_things.push_back(std::make_unique<Plane>(Vector(0.0, 1.0, 0.0), 0.0, checkerboard));
//         m_things.push_back(std::make_unique<Sphere>(Vector(0.0, 1.0, -0.25), 1.0, shiny));
//         m_things.push_back(std::make_unique<Sphere>(Vector(-1.0, 0.5, 1.5), 0.5, shiny));

//         m_lights.push_back(Light(Vector(-2.0, 2.5, 0.0), Color(0.49, 0.07, 0.07)));
//         m_lights.push_back(Light(Vector(1.5, 2.5, 1.5), Color(0.07, 0.07, 0.49)));
//         m_lights.push_back(Light(Vector(1.5, 2.5, -1.5), Color(0.07, 0.49, 0.071)));
//         m_lights.push_back(Light(Vector(0.0, 3.5, 0.0), Color(0.21, 0.21, 0.35)));

//         self.m_camera = Camera(Vector(3.0, 2.0, 4.0), Vector(-1.0, 0.5, 0.0));
//     }

//     ThingList const& things() const override
//     {
//         return m_things;
//     }

//     LightList const& lights() const override
//     {
//         return m_lights;
//     }

//     Camera const& camera() const override
//     {
//         return m_camera;
//     }
// };

// class RayTracerEngine
// {
// private:
//     static const int maxDepth = 5;
//     Scene &scene;

//     Intersection intersections(const Ray& ray)
//     {
//         double closest = INFINITY;
//         Intersection closestInter;

//         auto& things = scene.things();

//         for (auto& thing : things)
//         {
//             auto inter = thing->intersect(ray);
//             if (inter.IsValid() && inter.dist < closest)
//             {
//                 closestInter = inter;
//                 closest = inter.dist;
//             }
//         }
//         return closestInter;
//     }

//     double testRay(const Ray& ray)
//     {
//         auto isect = self.intersections(ray);
//         if (isect.IsValid())
//         {
//             return isect.dist;
//         }
//         return NAN;
//     }

//     Color traceRay(const Ray& ray, int depth)
//     {
//         auto isect = self.intersections(ray);
//         if (isect.IsValid())
//         {
//             return self.shade(isect, depth);
//         }
//         return Color::background;
//     }

//     Color shade(const Intersection& isect, int depth)
//     {
//         Vector d = isect.ray.dir;
//         Vector pos = (d * isect.dist) + isect.ray.start;
//         Vector normal = isect.thing->normal(pos);
//         Vector reflectDir = d - ((normal * (normal * d)) * 2);

//         Color naturalColor = Color::background + self.getNaturalColor(isect.thing, pos, normal, reflectDir);
//         Color reflectedColor = (depth >= self.maxDepth)
//             ? Color::grey
//             : self.getReflectionColor(isect.thing, pos, normal, reflectDir, depth);

//         return naturalColor + reflectedColor;
//     }

//     Color getReflectionColor(const Thing* thing, const Vector& pos, const Vector& normal, const Vector& rd, int depth)
//     {
//         Ray    ray(pos, rd);
//         Color  color = self.traceRay(ray, depth + 1);
//         double factor = thing->surface().reflect(pos);
//         return color.scale(factor);
//     }

//     Color getNaturalColor(const Thing* thing, const Vector& pos, const Vector& norm, const Vector& rd)
//     {
//         Color result = Color::black;
//         auto& items = scene.lights();

//         for (auto& item : items)
//         {
//             addLight(result, item, pos, thing, rd, norm);
//         }
//         return result;
//     }

//     void addLight(Color& resultColor, const Light& light, const Vector& pos, const Thing* thing, const Vector& rd, const Vector& norm)
//     {
//         Vector ldis = light.pos - pos;
//         Vector livec = ldis.norm();
//         Ray ray{ pos, livec };

//         double neatIsect = self.testRay(ray);

//         bool isInShadow = (neatIsect == NAN) ? false : (neatIsect <= ldis.mag());
//         if (isInShadow) {
//             return;
//         }
//         double illum    = livec * norm;
//         double specular = livec * rd.norm();

//         auto& surface = thing->surface();

//         Color lcolor = (illum > 0) ? (light.color * illum) : Color::defaultColor;
//         Color scolor = (specular > 0) ? (light.color * pow(specular, surface.roughness())) : Color::defaultColor;
//         resultColor = resultColor + lcolor * surface.diffuse(pos) + scolor * surface.specular(pos);
//     }

//     Vector getPoint(int x, int y, const Camera& camera, int screenWidth, int screenHeight)
//     {
//         double recenterX = (x - (screenWidth / 2.0)) / 2.0 / screenWidth;
//         double recenterY = -(y - (screenHeight / 2.0)) / 2.0 / screenHeight;
//         return (camera.forward + ((camera.right * recenterX) + (camera.up * recenterY))).norm();
//     }

// public:

//     RayTracerEngine(Scene &scene) : scene{ scene } {}

//     void render(byte* bitmapData, int stride, int w, int h)
//     {
//         Ray ray;
//         ray.start = scene.camera().pos;
//         auto& camera = scene.camera();

//         for (int y = 0; y < h; ++y)
//         {
//             RgbColor* pColor = (RgbColor*)(&bitmapData[y * stride]);
//             for (int x = 0; x < w; ++x)
//             {
//                 ray.dir = self.getPoint(x, y, camera, h, w);
//                 *pColor = self.traceRay(ray, 0).toDrawingColor();
//                 pColor++;
//             }
//         }
//     }
// };

// void SaveRGBBitmap(byte* pBitmapBits, LONG lWidth, LONG lHeight, WORD wBitsPerPixel, LPCSTR lpszFileName)
// {
//     BITMAPINFOHEADER bmpInfoHeader = { 0 };
//     bmpInfoHeader.biSize = sizeof(BITMAPINFOHEADER);
//     bmpInfoHeader.biBitCount = wBitsPerPixel;
//     bmpInfoHeader.biClrImportant = 0;
//     bmpInfoHeader.biClrUsed = 0;
//     bmpInfoHeader.biCompression = BI_RGB;
//     bmpInfoHeader.biHeight = -lHeight;
//     bmpInfoHeader.biWidth = lWidth;
//     bmpInfoHeader.biPlanes = 1;
//     bmpInfoHeader.biSizeImage = lWidth* lHeight * (wBitsPerPixel / 8);

//     BITMAPFILEHEADER bfh = { 0 };
//     bfh.bfType = 'B' + ('M' << 8);
//     bfh.bfOffBits = sizeof(BITMAPINFOHEADER) + sizeof(BITMAPFILEHEADER);
//     bfh.bfSize = bfh.bfOffBits + bmpInfoHeader.biSizeImage;

//     std::ofstream file(lpszFileName, std::ios::binary | std::ios::trunc);
//     file.write((const char*)&bfh, sizeof(bfh));
//     file.write((const char*)&bmpInfoHeader, sizeof(bmpInfoHeader));
//     file.write((const char*)pBitmapBits, bmpInfoHeader.biSizeImage);
//     file.close();
// }

// int main()
// {
//     std::cout << "Started " << std::endl;
//     auto t1 = std::chrono::high_resolution_clock::now();

//     DefaultScene    scene;
//     RayTracerEngine rayTracer(scene);

//     int width = 500;
//     int height = 500;
//     int stride = width * 4;

//     std::vector<byte> bitmapData(stride * height);

//     rayTracer.render(&bitmapData[0], stride, width, height);

//     auto t2 = std::chrono::high_resolution_clock::now();
//     auto diff = std::chrono::duration_cast<std::chrono::milliseconds>((t2 - t1));

//     std::cout << "Completed in " << diff.count() << " ms" << std::endl;
//     SaveRGBBitmap(&bitmapData[0], width, height, 32, "cpp-raytracer.bmp");

//     return 0;
// };