#![allow(unused_must_use, dead_code)]

extern crate bmp;
extern crate rayon;
use bmp::Image;
use bmp::Pixel;
use std::time::Instant;

use std::env;

use rayon::prelude::*;

const FAR_AWAY: f32 = 1000000.0;

#[derive(Debug, Copy, Clone)]
struct RgbColor {
    b: u8,
    g: u8,
    r: u8,
    a: u8,
}

#[derive(Debug, Copy, Clone)]
struct Vector {
    x: f32,
    y: f32,
    z: f32,
}

impl Vector {
    fn new(x: f32, y: f32, z: f32) -> Vector {
        Vector { x: x, y: y, z: z }
    }

    fn mag(&self) -> f32 {
        let value = self.x * self.x + self.y * self.y + self.z * self.z;
        value.sqrt()
    }

    fn norm(&self) -> Vector {
        let mag = self.mag();
        let div = if mag == 0.0 { FAR_AWAY } else { 1.0 / mag };
        self.scale(div)
    }

    fn cross(&self, v: Vector) -> Vector {
        Vector::new(
            self.y * v.z - self.z * v.y,
            self.z * v.x - self.x * v.z,
            self.x * v.y - self.y * v.x,
        )
    }

    fn scale(&self, k: f32) -> Vector {
        Vector::new(k * self.x, k * self.y, k * self.z)
    }

    fn dot(&self, v: Vector) -> f32 {
        self.x * v.x + self.y * v.y + self.z * v.z
    }

    fn add(&self, v: Vector) -> Vector {
        Vector::new(self.x + v.x, self.y + v.y, self.z + v.z)
    }

    fn sub(&self, v: Vector) -> Vector {
        Vector::new(self.x - v.x, self.y - v.y, self.z - v.z)
    }
}

#[derive(Debug, Copy, Clone)]
struct Color {
    r: f32,
    g: f32,
    b: f32,
}

const COLOR_WHITE: Color = Color {
    r: 1.0,
    g: 1.0,
    b: 1.0,
};
const COLOR_GREY: Color = Color {
    r: 0.5,
    g: 0.5,
    b: 0.5,
};
const COLOR_BLACK: Color = Color {
    r: 0.0,
    g: 0.0,
    b: 0.0,
};
const COLOR_BACKGROUND: Color = COLOR_BLACK;
const COLOR_DEFAULT_COLOR: Color = COLOR_BLACK;

impl Color {
    fn new(r: f32, g: f32, b: f32) -> Color {
        Color { r: r, g: g, b: b }
    }

    fn scale(&self, k: f32) -> Color {
        Color::new(k * self.r, k * self.g, k * self.b)
    }

    fn times(&self, c: Color) -> Color {
        Color::new(self.r * c.r, self.g * c.g, self.b * c.b)
    }

    fn add(&self, c: Color) -> Color {
        Color::new(self.r + c.r, self.g + c.g, self.b + c.b)
    }

    fn to_drawing_color(&self) -> RgbColor {
        RgbColor {
            r: (self.r.clamp(0.0, 1.0)*255.0) as u8, 
            g: (self.g.clamp(0.0, 1.0)*255.0) as u8,
            b: (self.b.clamp(0.0, 1.0)*255.0) as u8,
            a: 255
        }
    }
}

#[derive(Debug, Copy, Clone)]
struct Camera {
    forward: Vector,
    right: Vector,
    up: Vector,
    pos: Vector,
}

impl Camera {
    fn new(pos: Vector, look_at: Vector) -> Camera {
        let down = Vector::new(0.0, -1.0, 0.0);
        let forward = look_at.sub(pos).norm();
        let right = forward.cross(down).norm().scale(1.5);

        return Camera {
            pos: pos,
            forward: forward,
            right: right,
            up: forward.cross(right).norm().scale(1.5),
        };
    }
}

#[derive(Debug, Copy, Clone)]
struct Ray { start: Vector, dir: Vector }

#[derive(Debug, Copy, Clone)]
struct Intersection { thing: Thing, ray: Ray, dist: f32 }

impl Intersection {
    fn new(thing: Thing, ray: Ray, dist: f32) -> Intersection {
        Intersection {
            thing: thing,
            ray: ray,
            dist: dist,
        }
    }
}

#[derive(Debug, Copy, Clone)]
enum Surface {
    CheckerboardSurface,
    ShinySurface,
}

struct SurfaceProperties {
    diffuse: Color,
    specular: Color,
    reflect: f32,
    roughness: f32,
}

impl Surface {
    fn get_properties(&self, pos: Vector) -> SurfaceProperties {
        match *self {
            Surface::CheckerboardSurface => {
                let mut diffuse = COLOR_BLACK;
                let mut reflect = 0.7;

                if (pos.z.floor() + pos.x.floor()) as i32 % 2 != 0 {
                    diffuse = COLOR_WHITE;
                    reflect = 0.1;
                }
                return SurfaceProperties {
                    diffuse: diffuse,
                    specular: COLOR_WHITE,
                    reflect: reflect,
                    roughness: 150.0,
                };
            }
            Surface::ShinySurface => {
                return SurfaceProperties {
                    diffuse: COLOR_WHITE,
                    specular: COLOR_GREY,
                    reflect: 0.7,
                    roughness: 250.0,
                }
            }
        }
    }
}

#[derive(Debug, Copy, Clone)]
struct SphereInfo { surface: Surface, radius2: f32, center: Vector }

#[derive(Debug, Copy, Clone)]
struct PlaneInfo  { surface: Surface, offset: f32, normal: Vector }

#[derive(Debug, Copy, Clone)]
enum Thing {
    Plane(PlaneInfo),
    Sphere(SphereInfo),
}

struct Light {
    pos: Vector,
    color: Color,
}

impl Thing {
    fn new_sphere(center: Vector, radius: f32, surface: Surface) -> Thing {
        Thing::Sphere(SphereInfo {
            surface: surface,
            radius2: radius * radius,
            center: center,
        })
    }

    fn new_plane(normal: Vector, offset: f32, surface: Surface) -> Thing {
        Thing::Plane(PlaneInfo {
            surface: surface,
            offset: offset,
            normal: normal,
        })
    }

    fn normal(&self, pos: Vector) -> Vector {
        match self {
            Thing::Sphere(ref sphere) => pos.sub(sphere.center).norm(),
            Thing::Plane(ref plane) => plane.normal,
    }   }

    fn surface(&self) -> Surface {
        match self {
            Thing::Sphere(ref sphere) => sphere.surface,
            Thing::Plane(ref plane) => plane.surface,
    }    }

    fn intersect(&self, ray: &Ray) -> Option<Intersection> {
        match self {
            Thing::Sphere(ref sphere) => {
                let eo = sphere.center.sub(ray.start);
                let v  = eo.dot(ray.dir);

                if v >= 0.0 {
                    let disc = sphere.radius2 - ((eo.dot(eo)) - (v * v));
                    if disc >= 0.0 {
                        let dist = v - disc.sqrt();
                        return Some(Intersection::new(*self, *ray, dist));
                    }
                }
                None
            }
          
            Thing::Plane(ref plane) => {
                let denom = plane.normal.dot(ray.dir);
                if denom > 0.0 { return None; }
                let dist = (plane.normal.dot(ray.start) + plane.offset) / (-denom);
                Some(Intersection::new(*self, *ray, dist))
    }   }   }
}

struct Scene { things: Vec<Thing>, lights: Vec<Light>, camera: Camera }

impl Scene {
    fn new() -> Scene {
        return Scene {
            things: vec![
                Thing::new_plane(
                    Vector::new(0.0, 1.0, 0.0),
                    0.0,
                    Surface::CheckerboardSurface,
                ),
                Thing::new_sphere(Vector::new(0.0, 1.0, -0.25), 1.0, Surface::ShinySurface),
                Thing::new_sphere(Vector::new(-1.0, 0.5, 1.5), 0.5, Surface::ShinySurface),
            ],
            lights: vec![
                Light {
                    pos: Vector::new(-2.0, 2.5, 0.0),
                    color: Color::new(0.49, 0.07, 0.07),
                },
                Light {
                    pos: Vector::new(1.5, 2.5, 1.5),
                    color: Color::new(0.07, 0.07, 0.49),
                },
                Light {
                    pos: Vector::new(1.5, 2.5, -1.5),
                    color: Color::new(0.07, 0.49, 0.071),
                },
                Light {
                    pos: Vector::new(0.0, 3.5, 0.0),
                    color: Color::new(0.21, 0.21, 0.35),
                },
            ],
            camera: Camera::new(Vector::new(3.0, 2.0, 4.0), Vector::new(-1.0, 0.5, 0.0)),
        };
    }
}

struct RayTracerEngine {
    max_depth: i32,
    scene: Scene,
}


impl RayTracerEngine {
    fn intersections(&self, ray: &Ray) -> Option<Intersection> {
        let mut closest = FAR_AWAY;
        let mut closest_intersection: Option<Intersection> = None;

        for thing in &self.scene.things {
            let inter = thing.intersect(ray);
            match inter {
                Some(result) => {
                    if result.dist < closest {
                        closest_intersection = inter;
                        closest = result.dist;
                    }
                }
                None => {}
            }
        }
        return closest_intersection;
    }

    fn test_ray(&self, ray: &Ray) -> Option<f32> {
        let intersect = self.intersections(ray);
        return match intersect {
            Some(result) => Some(result.dist),
            None => None,
        };
    }

    fn trace_ray(&self, ray: &Ray, depth: i32) -> Color {
        let intersect = self.intersections(ray);
        return match intersect {
            Some(result) => self.shade(result, depth),
            None => COLOR_BACKGROUND,
        };
    }

    fn shade(&self, isect: Intersection, depth: i32) -> Color {
        let d: Vector = isect.ray.dir;
        let pos: Vector = d.scale(isect.dist).add(isect.ray.start);
        let normal: Vector = isect.thing.normal(pos);
        let reflect_dir: Vector = d.sub(normal.scale(normal.dot(d)).scale(2.0));

        let surface = isect.thing.surface().get_properties(pos);

        let natural_color =
            COLOR_BACKGROUND.add(self.get_natural_color(&surface, pos, normal, reflect_dir));
        let reflected_color = if depth >= self.max_depth {
            COLOR_GREY
        } else {
            self.get_reflection_color(&surface, pos, reflect_dir, depth)
        };

        natural_color.add(reflected_color)
    }

    fn get_reflection_color(
        &self,
        surface: &SurfaceProperties,
        pos: Vector,
        rd: Vector,
        depth: i32,
    ) -> Color {
        let ray = Ray {
            start: pos,
            dir: rd,
        };
        let color = self.trace_ray(&ray, depth + 1);
        let factor = surface.reflect;
        color.scale(factor)
    }

    fn get_natural_color(
        &self,
        surface: &SurfaceProperties,
        pos: Vector,
        norm: Vector,
        rd: Vector,
    ) -> Color {
        let mut result = COLOR_BLACK;
        let rd_norm = rd.norm();

        for light in &self.scene.lights {
            let ldis = light.pos.sub(pos);
            let livec = ldis.norm();
            let ray = Ray {
                start: pos,
                dir: livec,
            };

            let nearest_intersesct = self.test_ray(&ray);

            let is_in_shadow = match nearest_intersesct {
                Some(value) => value <= ldis.mag(),
                None => false,
            };

            if !is_in_shadow {
                let illum = livec.dot(norm);
                let specular = livec.dot(rd_norm);

                let lcolor = if illum > 0.0 {
                    light.color.scale(illum)
                } else {
                    COLOR_DEFAULT_COLOR
                };
                let scolor = if specular > 0.0 {
                    light.color.scale(specular.powf(surface.roughness))
                } else {
                    COLOR_DEFAULT_COLOR
                };
                result = result
                    .add(lcolor.times(surface.diffuse))
                    .add(scolor.times(surface.specular));
            }
        }
        return result;
    }

    pub fn get_point(
        &self,
        x: u32,
        y: u32,
        camera: Camera,
        screen_width: u32,
        screen_height: u32,
    ) -> Vector {
        let rx = (x as f32 - (screen_width as f32 / 2.0)) / 2.0 / screen_width as f32;
        let ry = -(y as f32 - (screen_height as f32 / 2.0)) / 2.0 / screen_height as f32;
        return (camera
            .forward
            .add(camera.right.scale(rx))
            .add(camera.up.scale(ry)))
        .norm();
    }

    pub fn render(&self, image: &mut Image, w: u32, h: u32) {
        let mut ray = Ray {
            start: self.scene.camera.pos,
            dir: Vector::new(0.0, 0.0, 0.0),
        };

        for y in 0..h {
            for x in 0..w {
                ray.dir = self.get_point(x, y, self.scene.camera, h, w);
                let color = self.trace_ray(&ray, 0).to_drawing_color();
                image.set_pixel(x, y, Pixel::new(color.r, color.g, color.b));
            }
        }
    }

    pub fn parallel_render(&self, image: &mut Image, w: u32, h: u32) {
        let mut vec: Vec<(u32, u32)> = Vec::with_capacity((w * h) as usize);
        for i in 0..h {
            for j in 0..w {
                vec.push((i, j));
            }
        }

        let data: Vec<(u32, u32, Pixel)> = vec
            .par_iter()
            .map(|(y, x)| {
                let dir = self.get_point(*x, *y, self.scene.camera, h, w);
                let ray = Ray {
                    start: self.scene.camera.pos,
                    dir,
                };
                let color = self.trace_ray(&ray, 0).to_drawing_color();

                (*y, *x, Pixel::new(color.r, color.g, color.b))
            })
            .collect();

        for (y, x, p) in data {
            image.set_pixel(x, y, p);
        }
    }
}

fn main() {
    let is_parallel = env::args_os()
        .nth(1)
        .and_then(|s| s.into_string().map(|s| s == "parallel").ok())
        .unwrap_or_else(|| false);

    let width: u32 = 500;
    let height: u32 = 500;

    let mut image = Image::new(width, height);

    let n = 100;

    if is_parallel {
        println!("Parallel!");
        let now = Instant::now();
      
        for _ in 0 .. n {
            let engine = RayTracerEngine {
                max_depth: 5,
                scene: Scene::new(),
            };
            engine.parallel_render(&mut image, width, height);
        }
        
      
    } else {
        println!("Not parallel!");
        let now = Instant::now();
      
        for _ in 0 .. n {
            let engine = RayTracerEngine {
                max_depth: 5,
                scene: Scene::new(),
            };
            engine.render(&mut image, width, height);
        }
    }
  
    let t = now.elapsed().as_millis();

    println!("total time for {:?} iterations = {:?} ms, avg time = {:?} ms", n, t, t/n); 

    image.save("RayTracer.bmp");
}
