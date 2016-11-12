package main

import "fmt"
import "time"
import "math"
import "image"
import "image/color"
import "image/png"
import "bufio"
import "os"

type Vector struct {
	x float64
	y float64
	z float64
}

type Color struct {
	r float64
	g float64
	b float64
}

type Ray struct {
	start Vector
	dir   Vector
}

type Intersection struct {
	thing Thing
	ray   *Ray
	dist  float64
}

type Colors struct {
	white        Color
	grey         Color
	black        Color
	background   Color
	defaultColor Color
}

func (isect *Intersection) isNull() bool {
	return isect.ray == nil
}

func (v Vector) mul(k float64) Vector {
	return Vector{k * v.x, k * v.y, k * v.z}
}

func (v Vector) add(v2 Vector) Vector {
	return Vector{v.x + v2.x, v.y + v2.y, v.z + v2.z}
}

func (v Vector) sub(v2 Vector) Vector {
	return Vector{v.x - v2.x, v.y - v2.y, v.z - v2.z}
}

func (v Vector) dot(v2 Vector) float64 {
	return v.x*v2.x + v.y*v2.y + v.z*v2.z
}

func (v Vector) mag() float64 {
	return math.Sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
}

func (v Vector) norm() Vector {
	var magnitude = v.mag()
	var div float64

	if magnitude == 0 {
		div = math.Inf(1)
	} else {
		div = 1.0 / magnitude
	}
	return v.mul(div)
}

func (v Vector) cross(v2 Vector) Vector {
	return Vector{v.y*v2.z - v.z*v2.y,
		v.z*v2.x - v.x*v2.z,
		v.x*v2.y - v.y*v2.x}
}

func (c Color) scale(k float64) Color {
	return Color{k * c.r, k * c.g, k * c.b}
}

func (c Color) add(color Color) Color {
	return Color{c.r + color.r, c.g + color.g, c.b + color.b}
}

func (c Color) toDrawingColor() color.Color {
	return color.RGBA{legalize(c.r), legalize(c.g), legalize(c.b), 255}
}

func (c Color) times(color Color) Color {
	return Color{c.r * color.r, c.g * color.g, c.b * color.b}
}

func legalize(c float64) uint8 {
	if c < 0.0 {
		return 0
	}
	if c > 1.0 {
		return 255
	}
	return byte(c * 255)
}

var gColors Colors

func init() {
	gColors.white = Color{1.0, 1.0, 1.0}
	gColors.grey = Color{0.5, 0.5, 0.5}
	gColors.black = Color{0.0, 0.0, 0.0}
	gColors.background = gColors.black
	gColors.defaultColor = gColors.black
}

func main() {
	fmt.Println("Starting")
	start := time.Now()

	width := 500
	height := 500
	img := image.NewRGBA(image.Rect(0, 0, width, height))

	var scene = CreateDefaultScene()
	var rayTracer = RayTracerEngine{maxDepth: 5}

	rayTracer.render(scene, img, width, height)

	elapsed := time.Since(start)

	var file, _ = os.Create("go-raytracer.png")
	var writer = bufio.NewWriter(file)

	png.Encode(writer, img)

	writer.Flush()

	fmt.Printf("Completed in %s", elapsed)
}

type Camera struct {
	forward Vector
	right   Vector
	up      Vector
	pos     Vector
}

func CreateCamera(pos Vector, lookAt Vector) Camera {
	var result = Camera{}
	result.pos = pos

	var down = Vector{0.0, -1.0, 0.0}
	var forward = lookAt.sub(pos)

	result.forward = forward.norm()

	var fwXdown = result.forward.cross(down)
	fwXdown = fwXdown.norm()
	result.right = fwXdown.mul(1.5)

	var fwXright = result.forward.cross(result.right)
	fwXright = fwXright.norm()
	result.up = fwXright.mul(1.5)

	return result
}

type Surface interface {
	diffuse(pos Vector) Color
	specular(pos Vector) Color
	reflect(pos Vector) float64
	roughness() float64
}

type Thing interface {
	intersect(ray Ray) Intersection
	normal(pos Vector) Vector
	surface() Surface
}

type Light struct {
	pos   Vector
	color Color
}

func CreateLight(pos Vector, color Color) Light {
	var result Light
	result.pos = pos
	result.color = color
	return result
}

type Scene interface {
	Things() []Thing
	Lights() []Light
	Camera() Camera
}

/*Thing*/
type Sphere struct {
	radius2  float64
	center   Vector
	mSurface Surface
}

func CreateSphere(center Vector, radius float64, surface Surface) *Sphere {
	return &Sphere{
		radius * radius,
		center,
		surface,
	}
}

func (sphere *Sphere) normal(pos Vector) Vector {
	var diff = pos.sub(sphere.center)

	return diff.norm()
}

func (sphere *Sphere) intersect(ray Ray) Intersection {
	var result Intersection

	var eo = sphere.center.sub(ray.start)
	var v = eo.dot(ray.dir)
	var dist float64

	if v >= 0 {
		var disc = sphere.radius2 - (eo.dot(eo) - v*v)
		if disc >= 0 {
			dist = v - math.Sqrt(disc)
		}
	}

	if dist == 0 {
		return result
	}
	result = Intersection{sphere, &ray, dist}
	return result
}

func (sphere *Sphere) surface() Surface {
	return sphere.mSurface
}

type Plane struct {
	norm     Vector
	offset   float64
	mSurface Surface
}

func (plane *Plane) normal(pos Vector) Vector {
	return plane.norm
}

func (plane *Plane) intersect(ray Ray) Intersection {
	var result Intersection

	var denom = plane.norm.dot(ray.dir)
	if denom > 0 {
		return result
	}
	var dist = (plane.norm.dot(ray.start) + plane.offset) / (-denom)

	result = Intersection{plane, &ray, dist}
	return result
}

func CreatePlane(norm Vector, offset float64, surface Surface) *Plane {
	return &Plane{
		norm,
		offset,
		surface,
	}
}

func (plane *Plane) surface() Surface {
	return plane.mSurface
}

/* ShinySurface */
type ShinySurface struct {
}

func (surface *ShinySurface) diffuse(pos Vector) Color {
	return gColors.white
}

func (surface *ShinySurface) specular(pos Vector) Color {
	return gColors.grey
}

func (surface *ShinySurface) reflect(pos Vector) float64 {
	return 0.7
}

func (surface *ShinySurface) roughness() float64 {
	return 250.0
}

/* CheckerboardSurface */
type CheckerboardSurface struct {
}

func (surface *CheckerboardSurface) diffuse(pos Vector) Color {
	var val = (math.Floor(pos.z) + math.Floor(pos.x))
	if math.Mod(val, 2.0) != 0 {
		return gColors.white
	}
	return gColors.black
}

func (surface *CheckerboardSurface) specular(pos Vector) Color {
	return gColors.white
}

func (surface *CheckerboardSurface) reflect(pos Vector) float64 {
	var val = (math.Floor(pos.z) + math.Floor(pos.x))
	if math.Mod(val, 2.0) != 0 {
		return 0.1
	}
	return 0.7
}

func (surface *CheckerboardSurface) roughness() float64 {
	return 150.0
}

type DefaultScene struct {
	things []Thing
	lights []Light
	camera Camera
}

func CreateDefaultScene() *DefaultScene {
	var result = &DefaultScene{}
	var shiny = &ShinySurface{}
	var checkerboard = &CheckerboardSurface{}

	var plane1 = CreatePlane(Vector{0.0, 1.0, 0.0}, 0.0, checkerboard)
	var sphere1 = CreateSphere(Vector{0.0, 1.0, -0.25}, 1.0, shiny)
	var sphere2 = CreateSphere(Vector{-1.0, 0.5, 1.5}, 0.5, shiny)

	result.things = []Thing{plane1, sphere1, sphere2}

	result.lights = []Light{
		CreateLight(Vector{-2.0, 2.5, 0.0}, Color{0.49, 0.07, 0.07}),
		CreateLight(Vector{1.5, 2.5, 1.5}, Color{0.07, 0.07, 0.49}),
		CreateLight(Vector{1.5, 2.5, -1.5}, Color{0.07, 0.49, 0.071}),
		CreateLight(Vector{0.0, 3.5, 0.0}, Color{0.21, 0.21, 0.35}),
	}

	result.camera = CreateCamera(Vector{3.0, 2.0, 4.0}, Vector{-1.0, 0.5, 0.0})
	return result
}

func (scene *DefaultScene) Things() []Thing {
	return scene.things
}

func (scene *DefaultScene) Lights() []Light {
	return scene.lights
}

func (scene *DefaultScene) Camera() Camera {
	return scene.camera
}

type RayTracerEngine struct {
	maxDepth int
}

func (rayTracer *RayTracerEngine) intersections(ray Ray, scene Scene) Intersection {
	var closest = math.Inf(1)
	var closestInter Intersection

	for _, thing := range scene.Things() {
		var inter = thing.intersect(ray)
		if !inter.isNull() && inter.dist < closest {
			closestInter = inter
			closest = inter.dist
		}
	}
	return closestInter
}

func (rayTracer *RayTracerEngine) testRay(ray Ray, scene Scene) float64 {
	var isect = rayTracer.intersections(ray, scene)
	if !isect.isNull() {
		return isect.dist
	}
	return math.NaN()
}

func (rayTracer *RayTracerEngine) traceRay(ray Ray, scene Scene, depth int) Color {
	var isect = rayTracer.intersections(ray, scene)
	if isect.isNull() {
		return gColors.background
	}
	return rayTracer.shade(isect, scene, depth)
}

func (rayTracer *RayTracerEngine) shade(isect Intersection, scene Scene, depth int) Color {
	var d = isect.ray.dir
	var pos = d.mul(isect.dist)
	pos = pos.add(isect.ray.start)
	var normal = isect.thing.normal(pos)

	var normalDotD = normal.dot(d)
	var vec = normal.mul(normalDotD)
	vec = vec.mul(2.0)

	var reflectDir = d.sub(vec)

	var naturalColor = rayTracer.getNaturalColor(isect.thing, pos, normal, reflectDir, scene)
	naturalColor = naturalColor.add(gColors.background)

	getReflectionColor := func() Color {
		var ray = Ray{pos, reflectDir}
		var reflect = isect.thing.surface().reflect(pos)
		var color = rayTracer.traceRay(ray, scene, depth+1)
		color = color.scale(reflect)
		return color
	}

	var reflectedColor Color
	if depth >= rayTracer.maxDepth {
		reflectedColor = gColors.grey
	} else {
		reflectedColor = getReflectionColor()
	}
	var resultColor = naturalColor.add(reflectedColor)
	return resultColor
}

func (rayTracer *RayTracerEngine) getNaturalColor(thing Thing, pos Vector, norm Vector, rd Vector, scene Scene) Color {
	var resultColor = gColors.black
	var surface = thing.surface()
	var rayDirNormal = rd.norm()

	var colDiffuse = surface.diffuse(pos)
	var colSpecular = surface.specular(pos)

	var lcolor Color
	var scolor Color

	var ray Ray
	ray.start = pos

	addLight := func(light Light) {
		var ldis = light.pos.sub(pos)
		var livec = ldis.norm()

		var neatIsect = rayTracer.testRay(Ray{pos, livec}, scene)
		var isInShadow bool
		if math.IsNaN(neatIsect) {
			isInShadow = false
		} else {
			isInShadow = neatIsect <= ldis.mag()
		}

		if isInShadow {
			return
		}

		var illum = livec.dot(norm)
		var specular = livec.dot(rayDirNormal)

		lcolor = gColors.defaultColor
		scolor = gColors.defaultColor

		if illum > 0 {
			lcolor = light.color.scale(illum)
		}
		if specular > 0 {
			scolor = light.color.scale(math.Pow(specular, surface.roughness()))
		}

		var diffuseColor = lcolor.times(colDiffuse)
		var specularColor = scolor.times(colSpecular)

		resultColor = resultColor.add(diffuseColor)
		resultColor = resultColor.add(specularColor)
	}

	for _, light := range scene.Lights() {
		addLight(light)
	}

	return resultColor
}

func (rayTracer *RayTracerEngine) getPoint(x int, y int, camera Camera, screenWidth int, screenHeight int, scale int) Vector {
	var recenterX = (float64(x) - (float64(screenWidth) / 2.0)) / 2.0 / float64(scale)
	var recenterY = -(float64(y) - (float64(screenHeight) / 2.0)) / 2.0 / float64(scale)

	var vx = camera.right.mul(recenterX)
	var vy = camera.up.mul(recenterY)
	var v = vx.add(vy)

	var z = camera.forward.add(v)

	z = z.norm()
	return z
}

func (rayTracer *RayTracerEngine) render(scene Scene, img *image.RGBA, w int, h int) {
	var camera = scene.Camera()
	var ray Ray
	ray.start = camera.pos

	var scale = h
	if scale > w {
		scale = w
	}

	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			var dir = rayTracer.getPoint(x, y, camera, w, h, scale)
			ray.dir = dir

			color := rayTracer.traceRay(ray, scene, 0)
			img.Set(x, y, color.toDrawingColor())
		}
	}
}
