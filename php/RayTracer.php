<?php

namespace RayTracer;

include "Bitmap.php";

class RGBColor
{
    public int $r = 0;
    public int $g = 0;
    public int $b = 0;
}

class RayTracer
{
    public static function run()
    {
        $w = 500;
        $h = 500;

        $image = new Image($w, $h);

        $t1 = microtime(true);
        $scene = new Scene();
        $rayTracer = new RayTracerEngine();
        $rayTracer->render($scene, $image, $w, $h);
        $t2 = microtime(true);

        $image->save("php-ray-tracer.bmp");
        $t = $t2 - $t1;

        echo "Rendered in $t seconds, image size is $w x $h \n";
    }
}

class Vector
{
    public float $x;
    public float $y;
    public float $z;

    public function __construct(float $x, float $y, float $z)
    {
        $this->x = $x;
        $this->y = $y;
        $this->z = $z;
    }

    public function times(float $k): Vector
    {
        return new Vector($k * $this->x, $k * $this->y, $k * $this->z);
    }

    public function minus(Vector $v): Vector
    {
        return new Vector($this->x - $v->x, $this->y - $v->y, $this->z - $v->z);
    }

    public function plus(Vector $v): Vector
    {
        return new Vector($this->x + $v->x, $this->y + $v->y, $this->z + $v->z);
    }

    public function dot(Vector $v): float
    {
        return $this->x * $v->x + $this->y * $v->y + $this->z * $v->z;
    }

    public function mag(): float
    {
        return sqrt($this->x ** 2 + $this->y ** 2 + $this->z ** 2);
    }

    public function norm(): Vector
    {
        $mag = $this->mag();
        $div = ($mag == 0) ? INF : 1.0 / $mag;
        return $this->times($div);
    }

    public function cross(Vector $v): Vector
    {
        return new Vector(
            $this->y * $v->z - $this->z * $v->y,
            $this->z * $v->x - $this->x * $v->z,
            $this->x * $v->y - $this->y * $v->x
        );
    }
}

class Color
{
    public float $r;
    public float $g;
    public float $b;

    public static Color $white;
    public static Color $grey;
    public static Color $black;
    public static Color $background;
    public static Color $defaultColor;

    public function __construct(float $r, float $g, float $b)
    {
        $this->r = $r;
        $this->g = $g;
        $this->b = $b;
    }

    public function scale(float $k): Color
    {
        return new Color($k * $this->r, $k * $this->g, $k * $this->b);
    }

    public function plus(Color $c): Color
    {
        return new Color($this->r + $c->r, $this->g + $c->g, $this->b + $c->b);
    }

    public function times(Color $c): Color
    {
        return new Color($this->r * $c->r, $this->g * $c->g, $this->b * $c->b);
    }

    public function addColor(Color $c)
    {
        $this->r += $c->r;
        $this->g += $c->g;
        $this->b += $c->b;
    }

    public function toDrawingColor(): RGBColor
    {
        $color = new RGBColor;
        $color->r = self::legalize($this->r);
        $color->g = self::legalize($this->g);
        $color->b = self::legalize($this->b);
        return $color;
    }

    public static function legalize(float $c): int
    {
        if ($c < 0.0) {
            $c = 0;
        } elseif ($c > 1.0) {
            $c = 1;
        }
        return (int) ($c * 255);
    }
}

Color::$white = new Color(1.0, 1.0, 1.0);
Color::$grey = new Color(0.5, 0.5, 0.5);
Color::$black = new Color(0.0, 0.0, 0.0);
Color::$background = Color::$black;
Color::$defaultColor = Color::$black;

class Camera
{
    public Vector $forward;
    public Vector $right;
    public Vector $up;
    public Vector $pos;

    public function __construct(Vector $pos, Vector $lookAt)
    {
        $this->pos = $pos;
        $down = new Vector(0.0, -1.0, 0.0);
        $this->forward = $lookAt->minus($this->pos)->norm();
        $this->right = $this->forward->cross($down)->norm()->times(1.5);
        $this->up = $this->forward->cross($this->right)->norm()->times(1.5);
    }

    public function getPoint(int $x, int $y, int $screenWidth, int $screenHeight)
    {
        $recenterX = ($x - ($screenWidth / 2.0)) / 2.0 / $screenWidth;
        $recenterY = - ($y - ($screenHeight / 2.0)) / 2.0 / $screenHeight;

        $a = $this->right->times($recenterX);
        $b = $this->up->times($recenterY);
        $c = $a->plus($b);

        return $this->forward->plus($c)->norm();
    }
}

class Ray
{
    public Vector $start;
    public Vector $dir;

    public function __construct(Vector $start = null, Vector $dir = null)
    {
        $this->start = $start;
        $this->dir = $dir;
    }
}

class Intersection
{
    public Thing $thing;
    public Ray $ray;
    public float $dist;

    public function __construct(Thing $thing, Ray $ray, float $dist)
    {
        $this->thing = $thing;
        $this->ray = $ray;
        $this->dist = $dist;
    }
}

interface Surface
{
    public function getSurfaceProperties(Vector $pos): SurfaceProperties;
}

abstract class Thing
{
    public Surface $surface;
    abstract public function intersect(Ray $ray): ?Intersection;
    abstract public function normal(Vector $pos): Vector;
}

class Light
{
    public Vector $pos;
    public Color $color;
    public function __construct(Vector $pos, Color $color)
    {
        $this->pos = $pos;
        $this->color = $color;
    }
}

class Sphere extends Thing
{
    public float $radius2;
    public Vector $center;

    public function __construct(Vector $center, $radius, Surface $surface)
    {
        $this->surface = $surface;
        $this->radius2 = $radius * $radius;
        $this->center = $center;
    }

    public function normal(Vector $pos): Vector
    {
        return $pos->minus($this->center)->norm();
    }

    public function intersect(Ray $ray): ?Intersection
    {
        $eo = $this->center->minus($ray->start);
        $v = $eo->dot($ray->dir);
        $dist = 0;
        if ($v >= 0) {
            $disc = $this->radius2 - ($eo->dot($eo) - $v * $v);
            $dist = ($disc >= 0) ? $v - sqrt($disc) : $dist;
        }
        return ($dist == 0) ? null : new Intersection($this, $ray, $dist);
    }
}

class Plane extends Thing
{
    private Vector $norm;
    private float $offset;

    public function __construct(Vector $norm, $offset, $surface)
    {
        $this->surface = $surface;
        $this->norm = $norm;
        $this->offset = $offset;
    }

    public function normal(Vector $pos): Vector
    {
        return $this->norm;
    }

    public function intersect(Ray $ray): ?Intersection
    {
        $denom = $this->norm->dot($ray->dir);
        if ($denom > 0) {
            return null;
        }
        $dist = ($this->norm->dot($ray->start) + $this->offset) / (-$denom);
        return new Intersection($this, $ray, $dist);
    }
}

class SurfaceProperties
{
    public Color $diffuse;
    public Color $specular;
    public float $reflect;
    public float $roughness;

    public function __construct(Color $diffuse, Color $specular, float $reflect, float $roughness)
    {
        $this->diffuse = $diffuse;
        $this->specular = $specular;
        $this->reflect = $reflect;
        $this->roughness = $roughness;
    }
}

class ShinySurface implements Surface
{
    private SurfaceProperties $surfaceProperies;

    public function __construct()
    {
        $this->surfaceProperies = new SurfaceProperties(Color::$white, Color::$grey, 0.7, 250);
    }

    public function getSurfaceProperties(Vector $pos): SurfaceProperties
    {
        return $this->surfaceProperies;
    }
}

class CheckerboardSurface implements Surface
{
    private SurfaceProperties $surfaceProperies1;
    private SurfaceProperties $surfaceProperies2;

    public function __construct()
    {
        $this->surfaceProperies1 = new SurfaceProperties(Color::$white, Color::$white, 0.1, 150);
        $this->surfaceProperies2 = new SurfaceProperties(Color::$black, Color::$white, 0.7, 150);
    }

    public function getSurfaceProperties(Vector $pos): SurfaceProperties
    {
        $condition = ((floor($pos->z) + floor($pos->x)) % 2 != 0);
        return ($condition) ? $this->surfaceProperies1 : $this->surfaceProperies2;
    }
}

class Scene
{
    public array $things;
    public array $lights;
    public Camera $camera;

    public function __construct()
    {
        $shiny = new ShinySurface();
        $checkerboard = new CheckerboardSurface();

        $this->things = [
            new Plane(new Vector(0.0, 1.0, 0.0), 0.0, $checkerboard),
            new Sphere(new Vector(0.0, 1.0, -0.25), 1.0, $shiny),
            new Sphere(new Vector(-1.0, 0.5, 1.5), 0.5, $shiny),
        ];

        $this->lights = [
            new Light(new Vector(-2.0, 2.5, 0.0), new Color(0.49, 0.07, 0.07)),
            new Light(new Vector(1.5, 2.5, 1.5), new Color(0.07, 0.07, 0.49)),
            new Light(new Vector(1.5, 2.5, -1.5), new Color(0.07, 0.49, 0.071)),
            new Light(new Vector(0.0, 3.5, 0.0), new Color(0.21, 0.21, 0.35)),
        ];

        $this->camera = new Camera(new Vector(3.0, 2.0, 4.0), new Vector(-1.0, 0.5, 0.0));
    }
}

class RayTracerEngine
{
    private int $maxDepth = 5;
    private Scene $scene;

    private function intersections(Ray $ray)
    {
        // $intersections = array_map(fn ($thing) => $thing->intersect($ray), $this->scene->things);
        // $intersections = array_filter($intersections, fn($isect) => $isect != null)

        $closest = INF;
        $closestInter = null;
        foreach ($this->scene->things as $thing) {
            $inter = $thing->intersect($ray);
            if ($inter != null && $inter->dist < $closest) {
                $closestInter = $inter;
                $closest = $inter->dist;
            }
        }
        return $closestInter;
    }

    private function traceRay(Ray $ray, int $depth): Color
    {
        $isect = $this->intersections($ray);
        return ($isect == null) ? Color::$background : $this->shade($isect, $depth);
    }

    private function shade(Intersection $isect, int $depth): Color
    {
        $d = $isect->ray->dir;
        $pos = $d->times($isect->dist)->plus($isect->ray->start);
        $normal = $isect->thing->normal($pos);

        $reflectDir = $d->minus($normal->times($normal->dot($d))->times(2.0));

        $naturalColor = Color::$background->plus($this->getNaturalColor($isect->thing, $pos, $normal, $reflectDir));

        $reflectedColor = ($depth >= $this->maxDepth)
            ? Color::$grey
            : $this->getReflectionColor($isect->thing, $pos, $reflectDir, $depth);

        return $naturalColor->plus($reflectedColor);
    }

    private function getReflectionColor(Thing $thing, Vector $pos, Vector $reflectDir, int $depth): Color
    {
        $k = $thing->surface->getSurfaceProperties($pos)->reflect;
        $ray = new Ray($pos, $reflectDir);
        return $this->traceRay($ray, $depth + 1)->scale($k);
    }

    private function getNaturalColor(Thing $thing, Vector $pos, Vector $norm, Vector $reflectDir): Color
    {
        $natColor = new Color(0, 0, 0);
        $natColor->addColor(Color::$background);
        $surface = $thing->surface->getSurfaceProperties($pos);

        foreach ($this->scene->lights as $light) {
            $ldis = $light->pos->minus($pos);
            $livec = $ldis->norm();
            $neatIsect = $this->intersections(new Ray($pos, $livec));
            $isInShadow = $neatIsect != null && $neatIsect->dist <= $ldis->mag();

            if (!$isInShadow) {
                $illum = $livec->dot($norm);
                $lcolor = ($illum > 0) ? $light->color->scale($illum) : Color::$defaultColor;

                $specular = $livec->dot($reflectDir->norm());
                $scolor = ($specular > 0) ? $light->color->scale(pow($specular, $surface->roughness)) : Color::$defaultColor;

                $natColor->addColor($surface->diffuse->times($lcolor));
                $natColor->addColor($surface->specular->times($scolor));
            }
        }
        return $natColor;
    }

    public function render(Scene $scene, Image $image, int $w, int $h)
    {
        $this->scene = $scene;
        $camera = $scene->camera;
        $camPos = $camera->pos;

        for ($y = 0; $y < $h; ++$y) {
            for ($x = 0; $x < $w; ++$x) {
                $ray = new Ray($camPos, $camera->getPoint($x, $y, $w, $h));
                $color = $this->traceRay($ray, 0)->toDrawingColor();
                $image->setColor($x, $y, $color);
            }
        }
    }
}

RayTracer::run();
