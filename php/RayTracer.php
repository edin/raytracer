<?php

namespace RayTracer;

class RGBColor
{
    public $r = 0;
    public $g = 0;
    public $b = 0;
}

class Image 
{
    private $img;
    
    public function __construct($w, $h)
    {
        $this->img = imagecreatetruecolor($w, $h);    
    }
    
    public function __destruct()
    {
        imagedestroy($this->img);    
    }
    
    public function setPixel($x, $y, RGBColor $color)
    {
        $gdColor = imagecolorallocate($this->img, $color->r, $color->g, $color->b);
        imagesetpixel($this->img, $x, $y, $gdColor);
        imagecolordeallocate($this->img, $gdColor);      
    } 
    
    public function saveAsPng($fileName)
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
        $scene = new DefaultScene();
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
    public $x;
    public $y;
    public $z;
    
    public function __construct($x, $y, $z)
    {
        $this->x = $x;
        $this->y = $y;
        $this->z = $z;
    }

    public static function times($k,Vector $v)
    { 
        return new Vector($k * $v->x, $k * $v->y, $k * $v->z); 
    }
    
    public static function minus(Vector $v1,Vector $v2) 
    { 
        return new Vector($v1->x - $v2->x, $v1->y - $v2->y, $v1->z - $v2->z); 
    }
    
    public static function plus(Vector $v1,Vector  $v2) 
    { 
        return new Vector($v1->x + $v2->x, $v1->y + $v2->y, $v1->z + $v2->z); 
    }
    
    public static function dot(Vector $v1, Vector $v2)
    { 
        return $v1->x * $v2->x + $v1->y * $v2->y + $v1->z * $v2->z; 
    }
    
    public static function mag(Vector $v)
    {
        return sqrt($v->x * $v->x + $v->y * $v->y + $v->z * $v->z);
    }
    
    public static function norm(Vector $v) 
    {
        $mag = Vector::mag($v);
        $div = ($mag == 0) ? INF : 1.0 / $mag;
        return Vector::times($div, $v);
    }
    
    public static function cross(Vector $v1,Vector $v2) 
    {
        return new Vector($v1->y * $v2->z - $v1->z * $v2->y,
                          $v1->z * $v2->x - $v1->x * $v2->z,
                          $v1->x * $v2->y - $v1->y * $v2->x);
    }
}

class Color 
{
    public $r;
    public $g;
    public $b;
    
    public static $white;      
    public static $grey;       
    public static $black;      
    public static $background; 
    public static $defaultColor;
            
    public function __construct($r,$g,$b) 
    {
        $this->r = $r;
        $this->g = $g;
        $this->b = $b;
    }
      
    public static function scale($k,Color $v)
    { 
        return new Color($k * $v->r, $k * $v->g, $k * $v->b); 
    }
    
    public static function plus(Color $v1, Color $v2)
    { 
        return new Color($v1->r + $v2->r, $v1->g + $v2->g, $v1->b + $v2->b); 
    }
    
    public static function times(Color $v1, Color $v2)
    { 
        return new Color($v1->r * $v2->r, $v1->g * $v2->g, $v1->b * $v2->b); 
    }

    public static function toDrawingColor(Color $c)
    {
        $color = new RGBColor;
        $color->r = self::legalize($c->r);
        $color->g = self::legalize($c->g);
        $color->b = self::legalize($c->b);
        return $color;
    }
    
    static function legalize($c) 
    {
        if ($c < 0) $c = 0;   
        if ($c > 1) $c = 1;
        return (int)($c*255);
    }
}

Color::$white        = new Color(1.0, 1.0, 1.0);
Color::$grey         = new Color(0.5, 0.5, 0.5);
Color::$black        = new Color(0.0, 0.0, 0.0);
Color::$background   = Color::$black;
Color::$defaultColor = Color::$black;      

class Camera 
{
    public $forward;
    public $right;
    public $up;
    public $pos;

    public function __construct(Vector $pos, Vector $lookAt) 
    {
        $this->pos     = $pos;
        $down          = new Vector(0.0, -1.0, 0.0);
        $this->forward = Vector::norm(Vector::minus($lookAt, $this->pos));
        $this->right   = Vector::times(1.5, Vector::norm(Vector::cross($this->forward, $down)));
        $this->up      = Vector::times(1.5, Vector::norm(Vector::cross($this->forward, $this->right)));
    }
}

class Ray 
{
    public $start;
    public $dir;
    
    public function __construct(Vector $start=null, Vector $dir=null)
    {
        $this->start = $start;
        $this->dir = $dir;
    }
}

class Intersection 
{
    public $thing;
    public $ray;
    public $dist;
    
    public function __construct(Thing $thing, Ray $ray, $dist)
    {
        $this->thing = $thing;
        $this->ray = $ray;
        $this->dist = $dist;
    }
}

interface Surface 
{
    function diffuse(Vector $pos);
    function specular(Vector $pos);
    function reflect(Vector $pos);
    function roughness();
}

interface Thing 
{
    /** @return Intersection */
    function intersect(Ray $ray);
    /** @return Vector  */
    function normal (Vector $pos);
    /** @return Surface */
    function surface();
}

class Light 
{
    public $pos;
    public $color;
    public function __construct(Vector $pos, Color $color)
    {
        $this->pos = $pos;
        $this->color = $color;
    }
}

interface Scene 
{
    public function things();
    public function lights();
    public function camera();
}

class Sphere implements Thing 
{
    public $radius2;
    public $center;
    public $surface;

    public function __construct(Vector $center, $radius, Surface $surface)
    {
        $this->radius2 = $radius * $radius;
        $this->center  = $center;
        $this->surface = $surface;
    }
    
    public function normal(Vector $pos) 
    {
        return Vector::norm(Vector::minus($pos, $this->center));
    }
    
    public function intersect(Ray $ray)
    {
        $eo = Vector::minus($this->center, $ray->start);
        $v = Vector::dot($eo, $ray->dir);
        $dist = 0;
        if ($v >= 0) {
            $disc = $this->radius2 - (Vector::dot($eo, $eo) - $v * $v);
            if ($disc >= 0) {
                $dist = $v - sqrt($disc);
            }
        }
        
        if ($dist == 0) {
            return null;
        }
        return new Intersection($this, $ray, $dist);
    }

    public function surface() 
    {
        return $this->surface;
    }
}

class Plane implements Thing 
{
    private $norm;
    public  $surface;
    private $offset;
    
    public function normal(Vector $pos) 
    {
        return $this->norm;
    }
    
    public function intersect(Ray $ray)
    {
        $denom = Vector::dot($this->norm, $ray->dir);
        if ($denom > 0) {
            return null;
        }
        $dist = (Vector::dot($this->norm, $ray->start) + $this->offset) / (-$denom);
        return new Intersection($this, $ray, $dist);      
    }

    public function __construct(Vector $norm, $offset, $surface) 
    {
        $this->surface = $surface;
        $this->norm = $norm;
        $this->offset = $offset;
    }

    public function surface() 
    {
        return $this->surface;
    }
}

class Surfaces 
{
    public static $shiny;
    public static $checkerboard;
}

class ShinySurface implements Surface
{
    public function diffuse(Vector $pos) 
    {
        return Color::$white;
    }

    public function specular(Vector $pos) 
    {
        return Color::$grey;
    }

    public function reflect(Vector $pos) 
    {
        return 0.7;
    }

    public function roughness() 
    {
        return 250.0;
    }   
}

class CheckerboardSurface implements Surface
{
    public function diffuse(Vector $pos) 
    {
        if ((floor($pos->z) + floor($pos->x)) % 2 != 0) {
            return Color::$white;
        }
        return Color::$black;
    }

    public function specular(Vector $pos) 
    {
        return Color::$white;
    }

    public function reflect(Vector $pos) 
    {
        if ((floor($pos->z) + floor($pos->x)) % 2 != 0) {
            return 0.1;
        }
        return 0.7;
    }

    public function roughness() 
    {
        return 150.0;
    }    
}

Surfaces::$shiny = new ShinySurface();
Surfaces::$checkerboard = new CheckerboardSurface();

class DefaultScene implements Scene
{
    private $things;
    private $lights;
    private $camera;
    
    public function __construct()
    {
        $this->things = [
            new Plane(new Vector(0.0, 1.0, 0.0), 0.0, Surfaces::$checkerboard),
            new Sphere(new Vector(0.0, 1.0, -0.25), 1.0, Surfaces::$shiny),
            new Sphere(new Vector(-1.0, 0.5, 1.5), 0.5, Surfaces::$shiny)
        ];
             
        $this->lights = [
            new Light(new Vector(-2.0, 2.5, 0.0), new Color(0.49, 0.07, 0.07)),
            new Light(new Vector(1.5, 2.5, 1.5),  new Color(0.07, 0.07, 0.49)),
            new Light(new Vector(1.5, 2.5, -1.5), new Color(0.07, 0.49, 0.071)),
            new Light(new Vector(0.0, 3.5, 0.0),  new Color(0.21, 0.21, 0.35))
        ];
        
        $this->camera= new Camera(new Vector(3.0, 2.0, 4.0), new Vector(-1.0, 0.5, 0.0));       
    }

    public function things() 
    {
        return $this->things;
    }

    public function lights() 
    {
        return $this->lights;
    }
    
    public function camera() 
    {
        return $this->camera;
    }
}
    
class RayTracerEngine 
{
    private $maxDepth = 5;

    private function intersections(Ray $ray,Scene $scene) 
    {
        $closest = INF;
        $closestInter = null;
        foreach ($scene->things() as $thing) 
        {
            $inter = $thing->intersect($ray);
            if ($inter != null && $inter->dist < $closest) 
            {
                $closestInter = $inter;
                $closest = $inter->dist;
            }
        }
        return $closestInter;
    }

    private function testRay(Ray $ray,Scene $scene) {
        $isect = $this->intersections($ray, $scene);
        if ($isect != null) {
            return $isect->dist;
        }
        return null;
    }

    private function traceRay(Ray $ray, Scene $scene, $depth) {
        $isect = $this->intersections($ray, $scene);
        if ($isect == null) {
            return Color::$background;
        }
        return $this->shade($isect, $scene, $depth);
    }

    private function shade(Intersection $isect,Scene $scene, $depth) 
    {      
        $d      = $isect->ray->dir;
        $pos    = Vector::plus(Vector::times($isect->dist, $d), $isect->ray->start);
        $normal = $isect->thing->normal($pos);
        $reflectDir   = Vector::minus($d, Vector::times(2.0, Vector::times(Vector::dot($normal, $d), $normal)));
        $naturalColor = Color::plus(Color::$background, $this->getNaturalColor($isect->thing, $pos, $normal, $reflectDir, $scene));
        
        $reflectedColor = ($depth >= $this->maxDepth) ? Color::$grey : $this->getReflectionColor($isect->thing, $pos, $normal, $reflectDir, $scene, $depth);
        return Color::plus($naturalColor, $reflectedColor);
    }

    private function getReflectionColor(Thing $thing, Vector $pos, Vector $normal, Vector $reflectDir, Scene $scene,$depth) 
    {
        return Color::scale($thing->surface()->reflect($pos), $this->traceRay(new Ray($pos, $reflectDir), $scene, $depth + 1));
    }

    private function getNaturalColor(Thing $thing, Vector $pos, Vector $norm, Vector $reflectDir, Scene $scene) 
    {
        $natColor = Color::$black;       
        foreach ($scene->lights() as $item)
        {
            $natColor = self::addLight($natColor, $item, $pos, $scene, $thing, $reflectDir, $norm);
        }
        return $natColor;
    }
    
    public function addLight(Color $col, Light $light, Vector $pos, Scene $scene, Thing $thing, Vector $reflectDir, Vector $norm)
    {
        $ldis  = Vector::minus($light->pos, $pos);
        $livec = Vector::norm($ldis);
        $neatIsect = $this->testRay(new Ray($pos,  $livec), $scene);

        $isInShadow = (($neatIsect != null) && ($neatIsect <= Vector::mag($ldis)));
        if ($isInShadow) {
            return $col;
        } 
        
        $illum = Vector::dot($livec, $norm);
        $lcolor = Color::$defaultColor;
        
        if ($illum > 0) {
            $lcolor = Color::scale($illum, $light->color);
        }
       
        $specular = Vector::dot($livec, Vector::norm($reflectDir));
        $scolor   = Color::$defaultColor;
        $surface  = $thing->surface();
        

        if ($specular > 0) {
            $scolor = Color::scale(pow($specular, $surface->roughness()), $light->color);
        }
        
        return Color::plus($col, Color::plus(Color::times($surface->diffuse($pos), $lcolor), 
                                 Color::times($surface->specular($pos), $scolor)));       
    }

    public function render(Scene $scene, Image $image, $w, $h) 
    {
		$camera = $scene->camera();
		$camPos = $camera->pos;
	
        for ($y = 0; $y < $h; ++$y) 
        for ($x = 0; $x < $w; ++$x) 
        {
            $ray      = new Ray($camPos, self::getPoint($x, $y, $camera, $w, $h));	
            $color    = Color::toDrawingColor($this->traceRay($ray, $scene, 0));     
            $image->setPixel($x, $y, $color);
        }
    }
    
    static function getPoint($x, $y, Camera $camera, $screenWidth, $screenHeight)
    {
        $recenterX =   ($x - ($screenWidth / 2.0)) / 2.0 / $screenWidth;
        $recenterY = - ($y - ($screenHeight / 2.0)) / 2.0 / $screenHeight;
		
		$a = Vector::times($recenterX, $camera->right);
		$b = Vector::times($recenterY, $camera->up);
		$c = Vector::plus($a,$b);
		
        return Vector::norm(Vector::plus($camera->forward, $c) );        
    }
}

RayTracer::run();