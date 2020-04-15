<?php

namespace RayTracer;

class RGBColor
{
    public float $r = 0;
    public float $g = 0;
    public float $b = 0;
}

class Image
{
    private $img;

    public function __construct(int $w, int $h)
    {
        $this->img = imagecreatetruecolor($w, $h);
    }

    public function __destruct()
    {
        imagedestroy($this->img);
    }

    public function setPixel(int $x, int $y, RGBColor $color): void
    {
        $gdColor = imagecolorallocate($this->img, $color->r, $color->g, $color->b);
        imagesetpixel($this->img, $x, $y, $gdColor);
        imagecolordeallocate($this->img, $gdColor);
    }

    public function saveAsPng(string $fileName): void
    {
        imagepng($this->img, $fileName);
    }
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

        $image->saveAsPng("php-ray-tracer.png");
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
        }
        if ($c > 1.0) {
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
    public function diffuse(Vector $pos): Color;
    public function specular(Vector $pos): Color;
    public function reflect(Vector $pos): float;
    public function roughness(): float;
}

interface Thing
{
    public function intersect(Ray $ray): ?Intersection;
    public function normal(Vector $pos): Vector;
    public function surface(): Surface;
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

class Sphere implements Thing
{
    public float $radius2;
    public Vector $center;
    public Surface $surface;

    public function __construct(Vector $center, $radius, Surface $surface)
    {
        $this->radius2 = $radius * $radius;
        $this->center = $center;
        $this->surface = $surface;
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
            if ($disc >= 0) {
                $dist = $v - sqrt($disc);
            }
        }

        if ($dist == 0) {
            return null;
        }
        return new Intersection($this, $ray, $dist);
    }

    public function surface(): Surface
    {
        return $this->surface;
    }
}

class Plane implements Thing
{
    private Vector $norm;
    private float $offset;
    public Surface $surface;

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

    public function __construct(Vector $norm, $offset, $surface)
    {
        $this->surface = $surface;
        $this->norm = $norm;
        $this->offset = $offset;
    }

    public function surface(): Surface
    {
        return $this->surface;
    }
}

class Surfaces
{
    public static Surface $shiny;
    public static Surface $checkerboard;
}

class ShinySurface implements Surface
{
    public function diffuse(Vector $pos): Color
    {
        return Color::$white;
    }

    public function specular(Vector $pos): Color
    {
        return Color::$grey;
    }

    public function reflect(Vector $pos): float
    {
        return 0.7;
    }

    public function roughness(): float
    {
        return 250.0;
    }
}

class CheckerboardSurface implements Surface
{
    public function diffuse(Vector $pos): Color
    {
        if ((floor($pos->z) + floor($pos->x)) % 2 != 0) {
            return Color::$white;
        }
        return Color::$black;
    }

    public function specular(Vector $pos): Color
    {
        return Color::$white;
    }

    public function reflect(Vector $pos): float
    {
        if ((floor($pos->z) + floor($pos->x)) % 2 != 0) {
            return 0.1;
        }
        return 0.7;
    }

    public function roughness(): float
    {
        return 150.0;
    }
}

Surfaces::$shiny = new ShinySurface();
Surfaces::$checkerboard = new CheckerboardSurface();

class Scene
{
    public array $things;
    public array $lights;
    public Camera $camera;

    public function __construct()
    {
        $this->things = [
            new Plane(new Vector(0.0, 1.0, 0.0), 0.0, Surfaces::$checkerboard),
            new Sphere(new Vector(0.0, 1.0, -0.25), 1.0, Surfaces::$shiny),
            new Sphere(new Vector(-1.0, 0.5, 1.5), 0.5, Surfaces::$shiny),
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

    private function testRay(Ray $ray)
    {
        $isect = $this->intersections($ray);
        if ($isect != null) {
            return $isect->dist;
        }
        return null;
    }

    private function traceRay(Ray $ray, int $depth): Color
    {
        $isect = $this->intersections($ray);
        if ($isect == null) {
            return Color::$background;
        }
        return $this->shade($isect, $depth);
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
                          : $this->getReflectionColor($isect->thing, $pos, $normal, $reflectDir, $depth);

        return $naturalColor->plus($reflectedColor);
    }

    private function getReflectionColor(Thing $thing, Vector $pos, Vector $normal, Vector $reflectDir, int $depth): Color
    {
        $k = $thing->surface()->reflect($pos);
        $ray = new Ray($pos, $reflectDir);
        return $this->traceRay($ray, $depth + 1)->scale($k);
    }

    private function getNaturalColor(Thing $thing, Vector $pos, Vector $norm, Vector $reflectDir): Color
    {
        $natColor = new Color(0, 0, 0);
        $natColor->addColor(Color::$background);
        $surface = $thing->surface();
        $surf_diffuse = $surface->diffuse($pos);
        $surf_specular = $surface->specular($pos);
        $surf_roughness = $surface->roughness();

        foreach ($this->scene->lights as $light) {
            $ldis = $light->pos->minus($pos);
            $livec = $ldis->norm();
            $neatIsect = $this->testRay(new Ray($pos, $livec));
            $isInShadow = $neatIsect != null && $neatIsect <= $ldis->mag();

            if (!$isInShadow) {
                $illum = $livec->dot($norm);
                $lcolor = ($illum > 0) ? $light->color->scale($illum) : Color::$defaultColor;

                $specular = $livec->dot($reflectDir->norm());
                $scolor = ($specular > 0) ? $light->color->scale(pow($specular, $surf_roughness)) : Color::$defaultColor;

                $a = $surf_diffuse->times($lcolor);
                $b = $surf_specular->times($scolor);
                $natColor->addColor($a);
                $natColor->addColor($b);
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
                $ray = new Ray($camPos, self::getPoint($x, $y, $camera, $w, $h));
                $color = $this->traceRay($ray, 0)->toDrawingColor();
                $image->setPixel($x, $y, $color);
            }
        }
    }

    public static function getPoint($x, $y, Camera $camera, int $screenWidth, int $screenHeight)
    {
        $recenterX = ($x - ($screenWidth / 2.0)) / 2.0 / $screenWidth;
        $recenterY = -($y - ($screenHeight / 2.0)) / 2.0 / $screenHeight;

        $a = $camera->right->times($recenterX);
        $b = $camera->up->times($recenterY);
        $c = $a->plus($b);

        return $camera->forward->plus($c)->norm();
    }
}

RayTracer::run();
