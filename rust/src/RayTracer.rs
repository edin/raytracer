
const FarAway: f32 = 1000000.0;

struct RgbColor
{
    b: u8, g: u8, r: u8, a: u8,
}

#[derive(Debug, Copy, Clone)]
struct Vector { x: f32, y: f32, z: f32 }

impl Vector
{
    fn new(x: f32, y: f32, z: f32) -> Vector
    {
        Vector { x: x, y: y, z: z }
    }

    fn mag(&self) -> f32
    {
        let value = self.x * self.x + self.y * self.y + self.z * self.z;
        return value.sqrt()
    }

    fn norm(&self) -> Vector
    {
        let mag = self.mag();
        let div = if mag == 0.0 { 1000000.0 } else { 1.0 / mag };
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

    fn dot(&self, v: Vector) -> f32
    {
        self.x * v.x + self.y * v.y + self.z * v.z
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

struct Color {
    r: f32, g: f32, b: f32,
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
        return Color{ r: r, g: g, b: b }
    }

    fn scale(&self, k: f32) -> Color
    {
        return Color::new(k * self.r, k * self.g, k * self.b)
    }

    fn times(&self, c: Color) -> Color
    {
        return Color::new(self.r * c.r, self.g * c.g, self.b * c.b)
    }

    fn add(&self, c: Color) -> Color
    {
        return Color::new(self.r + c.r, self.g + c.g, self.b + c.b)
    }

    fn to_drawing_color(&self) -> RgbColor
    {
        return RgbColor{
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

impl Camera  {
    fn new(pos: Vector, lookAt: Vector) -> Camera
    {
        let down = Vector::new(0.0, -1.0, 0.0);
        let forward = lookAt.sub(pos).norm();
        let right = forward.cross(down).norm().scale(1.5);

        return Camera {
            pos: pos,
            forward: forward,
            right: right,
            up: forward.cross(right).norm().scale(1.5)
        }
    }
}

struct Ray {
    start: Vector,
    dir: Vector,
}

struct Intersection {
    thing: *const Thing,
    ray: Ray,
    dist: f32,
}

impl Intersection {
    fn new(thing: *const Thing, ray: Ray, dist: f32) -> Intersection
    {
        Intersection {
            thing: thing,
            ray: ray,
            dist: dist,
        }
    }
}

trait Surface {
    fn diffuse(&self, pos: Vector) -> Color;
    fn specular(&self, pos: Vector) -> Color;
    fn reflect(&self, pos: Vector) -> f32;
    fn roughness(&self) -> f32;
}

trait Thing {
   fn intersect(&self, ray: Ray) -> Option<Intersection>;
   fn normal(&self, pos: Vector) -> Vector;
   fn surface(&self) -> Box<Surface>;
}

struct Light {
    pos:   Vector,
    color: Color
}

struct Sphere {
    surface: Box<Surface>,
    radius2: f32,
    center: Vector,
}

impl Sphere {
    fn new(center: Vector, radius: f32, surface: Box<Surface>) -> Sphere
    {
        Sphere {
            surface: surface,
            radius2: radius * radius,
            center: center,
        }
    }
}

impl Thing for Sphere
{
   fn intersect(&self, ray: Ray) -> Option<Intersection>
   {
        let eo = self.center.sub(ray.start);
        let v = eo.dot(ray.dir);

        if v >= 0.0 {
            let disc = self.radius2 - ((eo.dot(eo)) - (v * v));
            if disc >= 0.0 {
                let dist = v - disc.sqrt();
                Some(Intersection::new(self, ray, dist));
            }
        }
        return None;
   }

   fn normal(&self, pos: Vector) -> Vector
   {
       self.center.sub(pos).norm()
   }

   fn surface(&self) -> Box<Surface>
   {
       self.surface
   }
}

struct Plane
{
    norm: Vector,
    offset: f32,
    surface: Box<Surface>,
}

impl Plane {
    fn new(norm: Vector, offset: f32, surface: Box<Surface>) -> Plane
    {
        return Plane {
            norm: norm,
            offset: offset,
            surface: surface
        }
    }
}

impl Thing for Plane
{
    fn intersect(&self, ray: Ray) -> Option<Intersection>
    {
        let denom = self.norm.dot(ray.dir);
        if denom > 0.0 {
            return None;
        }
        let dist = (self.norm.dot(ray.start) + self.offset) / (-denom);
        return Some(Intersection::new(self, ray, dist));
    }

    fn normal(&self, _pos: Vector) -> Vector
    {
        return self.norm;
    }

    fn surface(&self) -> Box<Surface>
    {
        return self.surface;
    }
}

struct ShinySurface{}
struct CheckerboardSurface{}

impl Surface for ShinySurface
{
    fn diffuse(&self, _pos: Vector) -> Color
    {
        return ColorWhite
    }

    fn specular(&self, _pos: Vector) -> Color
    {
        return ColorGrey
    }

    fn reflect(&self, _pos: Vector) -> f32
    {
        return 0.7;
    }

    fn roughness(&self) -> f32
    {
        return 250.0;
    }
}

impl Surface for CheckerboardSurface
{
    fn diffuse(&self, pos: Vector) -> Color
    {
        if (pos.z.floor() + pos.x.floor()) as i32 % 2 != 0
        {
            return ColorWhite;
        }
        return ColorBlack;
    }

    fn specular(&self, _pos: Vector) -> Color
    {
        return ColorWhite;
    }

    fn reflect(&self, pos: Vector) -> f32
    {
        if (pos.z.floor() + pos.x.floor()) as i32 % 2 != 0
        {
            return 0.1;
        }
        return 0.7;
    }

    fn roughness(&self) -> f32
    {
        return 150.0;
    }
}

struct Scene {
    things: Vec<Box<Thing>>,
    lights: Vec<Light>,
    camera: Camera,
}

impl Scene
{
    fn new() -> Scene
    {
        return Scene {
            things: vec![
                Box::new(Plane::new(Vector::new(0.0, 1.0, 0.0), 0.0, Box::new(CheckerboardSurface{}))),
                Box::new(Sphere::new(Vector::new(0.0, 1.0, -0.25), 1.0, Box::new(ShinySurface{}))),
                Box::new(Sphere::new(Vector::new(-1.0, 0.5, 1.5), 0.5, Box::new(ShinySurface{})))
            ],
            lights: vec![
                Light{pos: Vector::new(-2.0, 2.5, 0.0), color: Color::new(0.49, 0.07, 0.07)},
                Light{pos: Vector::new(1.5, 2.5, 1.5),  color: Color::new(0.07, 0.07, 0.49)},
                Light{pos: Vector::new(1.5, 2.5, -1.5), color: Color::new(0.07, 0.49, 0.071)},
                Light{pos: Vector::new(0.0, 3.5, 0.0),  color: Color::new(0.21, 0.21, 0.35)}
            ],
            camera: Camera::new(Vector::new(3.0, 2.0, 4.0), Vector::new(-1.0, 0.5, 0.0))
        }
    }
}

struct RayTracerEngine {
    maxDepth: i32,
    scene: Scene
}

impl RayTracerEngine
{
    fn intersections(&self, ray: Ray) -> Option<Intersection>
    {
        let closest = FarAway;
        let mut closestInter: Option<Intersection>;

        for thing in self.scene.things
        {
            let inter = thing.intersect(ray);
            match inter {
                Some(result) => {
                    if result.dist < closest {
                        closestInter = inter;
                        closest = result.dist;
                    }
                }
            }
        }
        return closestInter;
    }

    fn testRay(&self, ray: Ray) -> Option<f32>
    {
        let isect = self.intersections(ray);
        return match isect {
            Some(result) => Some(result.dist),
            None => None
        }
    }

    fn traceRay(&self, ray: Ray, depth: i32) -> Color
    {
        let isect = self.intersections(ray);
        return match isect {
            Some(result) => self.shade(result, depth),
            None => ColorBackground
        }
    }

    fn shade(&self, isect: Intersection, depth: i32) -> Color
    {
        let d: Vector = isect.ray.dir;
        let pos: Vector = d.scale(isect.dist).add(isect.ray.start);
        let normal: Vector = isect.thing.normal(pos);
        let reflectDir: Vector = d.sub((normal * (normal * d)) * 2);

        let naturalColor = ColorBackground.add(self.getNaturalColor(isect.thing, pos, normal, reflectDir));
        let reflectedColor = if depth >= self.maxDepth { ColorGrey } else { self.getReflectionColor(isect.thing, pos, normal, reflectDir, depth) };

        return naturalColor.add(reflectedColor);
    }

    fn getReflectionColor(&self, thing: &Thing, pos: Vector, normal: Vector, rd: Vector, depth: i32) -> Color
    {
        let ray  = Ray{start: pos, dir: rd};
        let color = self.traceRay(ray, depth + 1);
        let factor = thing.surface().reflect(pos);
        return color.scale(factor);
    }

    fn getNaturalColor(&self, thing: *const Thing, pos: Vector, norm: Vector, rd: Vector) -> Color
    {
        let mut result = ColorBlack;

        for light in self.scene.lights
        {
            let ldis = light.pos.sub(pos);
            let livec = ldis.norm();
            let ray = Ray{start: pos, dir: livec };

            let neatIsect = self.testRay(ray);

            let isInShadow = if neatIsect == NAN {false} else { neatIsect <= ldis.mag() };
            if !isInShadow {
                let illum    = livec * norm;
                let specular = livec * rd.norm();

                let surface = thing.surface();

                let lcolor = if illum > 0    {(light.color * illum)} else { DefaultColor };
                let scolor = if specular > 0 {(light.color * pow(specular, surface.roughness())) } else { DefaultColor };
                result = result + lcolor * surface.diffuse(pos) + scolor * surface.specular(pos);
            }
        }
        return result;
    }

    fn getPoint(x: i32, y: i32, camera: Camera, screenWidth: i32, screenHeight: i32) -> Vector
    {
        let recenterX =  (x as f32 - (screenWidth as f32  / 2.0)) / 2.0 / screenWidth as f32;
        let recenterY = -(y as f32 - (screenHeight as f32 / 2.0)) / 2.0 / screenHeight as f32;
        return (camera.forward.add(camera.right.scale(recenterX)).add(camera.up.scale(recenterY))).norm();
    }

    pub fn render(&self, bitmapData: *mut u8, stride: i32, w: i32, h: i32)
    {
        let ray = Ray{start: self.scene.camera.pos, dir: Vector::new(0.0, 0.0, 0.0)};
        let camera = self.scene.camera;

        for y in 0 .. h
        {
            RgbColor* pColor = (RgbColor*)(&bitmapData[y * stride]);
            for  x in 0 .. x
            {
                ray.dir = self.getPoint(x, y, camera, h, w);
                *pColor = self.traceRay(ray, 0).toDrawingColor();
                pColor++;
            }
        }
    }
}

fn main() {
    let width  = 500;
    let height = 500;
    let rayTracer = RayTracerEngine{maxDepth: 5, scene: Scene::new() };
    // rayTracer.render(image, width, height);
}