#include <windows.h>
#include <math.h>
#include <vector>
#include <iostream>
#include <stdio.h>


#ifdef _MSC_VER
	#ifndef INFINITY
		#define INFINITY (DBL_MAX+DBL_MAX)
		#define NAN (INFINITY-INFINITY)
	#endif
#endif

struct RGB_COLOR
{
	byte r;
	byte g;
	byte b;
};

class Vector 
{
public:
	double x;
	double y;
	double z;

	Vector() {
		x = 0;
		y = 0;
		z = 0;
	}

	Vector(double x, double y, double z)
	{
		this->x = x;
		this->y = y;
		this->z = z;
	}

	static Vector times(double k, const Vector &v)         { return Vector(k * v.x, k * v.y, k * v.z); }
	static Vector minus(const Vector &v1, const Vector &v2) { return Vector(v1.x - v2.x, v1.y - v2.y, v1.z - v2.z); }
	static Vector plus(const Vector &v1, const Vector &v2)  { return Vector(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z); }
	static double dot(const Vector &v1, const Vector &v2)   { return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z; }

	static double mag(const Vector &v)  { return sqrt(v.x * v.x + v.y * v.y + v.z * v.z); }

	static Vector norm(const Vector &v) 
	{
		double mag = Vector::mag(v);
		double div = (mag == 0) ? INFINITY : 1.0 / mag;
		return Vector::times(div, v);
	}
	static Vector cross(const Vector &v1,const Vector &v2) {
		return Vector(v1.y * v2.z - v1.z * v2.y,
			v1.z * v2.x - v1.x * v2.z,
			v1.x * v2.y - v1.y * v2.x);
	} 
};


class Color 
{
public:
	double r;
	double g;
	double b;

	static Color white;
	static Color grey;
	static Color black;
	static Color background;
	static Color defaultColor;

	Color(){
		r = 0;
		g = 0;
		b = 0;
	}

	Color(double r, double g, double b) {
		this->r = r;
		this->g = g;
		this->b = b;
	}
	static Color scale(double k,  const Color &v)  { return Color(k * v.r, k * v.g, k * v.b); }
	static Color plus(const Color  &v1, const Color &v2)  { return Color(v1.r + v2.r, v1.g + v2.g, v1.b + v2.b); }
	static Color times(const Color &v1, const Color &v2)  { return Color(v1.r * v2.r, v1.g * v2.g, v1.b * v2.b); }

	static 	RGB_COLOR toDrawingColor(const Color &c) 
	{
		RGB_COLOR color;
		color.r = (byte)legalize(c.r);
		color.g = (byte)legalize(c.g);
		color.b = (byte)legalize(c.b);

		return color;
	}

	static int legalize(double c){
		int x = (int)(c * 255);
		if (x < 0) x = 0;
		if (x > 255) x = 255;
		return x;
	}
};

Color Color::white = Color(1.0, 1.0, 1.0);
Color Color::grey  = Color(0.5, 0.5, 0.5);
Color Color::black = Color(0.0, 0.0, 0.0);
Color Color::background   = Color::black;
Color Color::defaultColor = Color::black;


class Camera 
{
public:
	Vector forward;
	Vector right;
	Vector up;
	Vector pos;

	Camera(){}

	Camera (Vector pos, Vector lookAt) {
		this->pos = pos;
		Vector down    = Vector(0.0, -1.0, 0.0);
		Vector forward = Vector::minus(lookAt, pos);
		this->forward  = Vector::norm(forward);
		this->right    = Vector::times(1.5, Vector::norm(Vector::cross(this->forward, down)));
		this->up       = Vector::times(1.5, Vector::norm(Vector::cross(this->forward, this->right)));
	}
};


class Ray {
public :
	Vector start;
	Vector dir;

	Ray(){}
	Ray(Vector start, Vector dir)
	{
		this->start = start;
		this->dir = dir;
	}
};

class Thing;

class Intersection {
public:
	Thing* thing;
	Ray ray;
	double dist;

	Intersection(Thing* thing, Ray ray, double dist)
	{
		this->thing = thing;
		this->ray = ray;
		this->dist = dist;
	}
};


class Surface {
public:
	virtual Color  diffuse(Vector pos)  { return Color::black; };
	virtual Color  specular(Vector pos) { return Color::black; };
	virtual double reflect(Vector pos)  { return 0; };
	virtual double roughness()			{ return 0; };
};


class Thing {
public:
	virtual Intersection *intersect(Ray ray) = 0;
	virtual Vector normal(Vector pos) = 0;
	virtual Surface *surface()= 0;
};


class Light {
public:
	Vector pos;
	Color color;

	Light(Vector pos, Color color)
	{
		this->pos = pos;
		this->color = color;
	}
};


class Scene {
public:
	virtual std::vector<Thing*>* things() = 0;
	virtual std::vector<Light*>* lights() = 0;
	virtual Camera camera() = 0;
};

class Sphere : Thing {
public :
	double radius2;
	Vector center;
	Surface *_surface;

	Sphere(Vector center, double radius, Surface *surface)
	{
		this->radius2 = radius * radius;
		this->center = center;
		this->_surface = surface;
	}
	
	Vector normal(Vector pos) { return Vector::norm(Vector::minus(pos, this->center)); }

	Intersection* intersect(Ray ray)
	{
		Vector eo = Vector::minus(this->center, ray.start);
		double v = Vector::dot(eo, ray.dir);
		double dist = 0;
		if (v >= 0) {
			double disc = this->radius2 - (Vector::dot(eo, eo) - v * v);
			if (disc >= 0) {
				dist = v - sqrt(disc);
			}
		}
		if (dist == 0) {
			return nullptr;
		}
		else {
			return new Intersection(this, ray, dist);
		}
	}

	Surface* surface() {
		return _surface;
	}
};


class Plane: Thing
{
private:
	Vector norm;
	double offset;
public:
	Surface* _surface;

	Vector normal(Vector pos) {
		return this->norm;
	}
	
	Intersection* intersect(Ray ray){
		double denom = Vector::dot(norm, ray.dir);
		if (denom > 0) {
			return nullptr;
		}
		else {
			double dist = (Vector::dot(norm, ray.start) + offset) / (-denom);
			return new Intersection(this, ray, dist);
		}
	}

	Plane(Vector norm, double offset, Surface* surface)
	{
		this->_surface = surface;
		this->norm = norm;
		this->offset = offset;
	}

	Surface* surface() {
		return _surface;
	}
};


class ShinySurface: Surface 
{
public:
	Color  diffuse(Vector pos)
	{
		return Color::white;
	}

	Color specular(Vector pos){
		return Color::grey;
	}

	double reflect(Vector pos)
	{
		return 0.7;
	}
	double roughness(){
		return 250.0;
	}
};


class CheckerboardSurface : Surface
{
public:
	Color diffuse(Vector pos)
	{
		if ( ((int)(floor(pos.z) + floor(pos.x)))  % 2 != 0) {
			return Color::white;
		}
		else 
		{
			return Color::black;
		}
	}

	Color specular(Vector pos){
		return Color::white;
	}

	double reflect(Vector pos)
	{
		if ( ((int)(floor(pos.z) + floor(pos.x))) % 2 != 0) {
			return 0.1;
		} else {
			return 0.7;
		}
	}
	double roughness(){
		return 150.0;
	}
};

class Surfaces {
public:
	static ShinySurface* shiny;
	static CheckerboardSurface* checkerboard;
};

ShinySurface* Surfaces::shiny = new ShinySurface();
CheckerboardSurface* Surfaces::checkerboard =  new CheckerboardSurface();


class DefaultScene: Scene
{
private:
	std::vector<Thing*>* _things;
	std::vector<Light*>* _lights;
	Camera _camera;

public:
	DefaultScene()
	{
		_things = new std::vector<Thing*>();
		_lights = new std::vector<Light*>();

		_things->push_back((Thing*)new Plane(Vector(0.0, 1.0, 0.0), 0.0,    (Surface*)Surfaces::checkerboard));
		_things->push_back((Thing*)new Sphere(Vector(0.0, 1.0, -0.25), 1.0, (Surface*)Surfaces::shiny));
		_things->push_back((Thing*)new Sphere(Vector(-1.0, 0.5, 1.5), 0.5,  (Surface*)Surfaces::shiny));


		Light *a = new Light(Vector(-2.0, 2.5, 0.0), Color(0.49, 0.07, 0.07));
		Light *b = new Light(Vector(1.5, 2.5, 1.5),  Color(0.07, 0.07, 0.49));
		Light *c = new Light(Vector(1.5, 2.5, -1.5), Color(0.07, 0.49, 0.071));
		Light *d = new Light(Vector(0.0, 3.5, 0.0),  Color(0.21, 0.21, 0.35));

		_lights->push_back(a);
		_lights->push_back(b);
		_lights->push_back(c);
		_lights->push_back(d);

		this->_camera = Camera(Vector(3.0, 2.0, 4.0), Vector(-1.0, 0.5, 0.0));
	}

	std::vector<Thing*>* things() {
		return _things;
	}

	std::vector<Light*>* lights() {
		return _lights;
	}

	Camera camera() {
		return _camera;
	}
};


class RayTracerEngine
{
private:
	static const int maxDepth = 5;


	 Intersection* intersections(Ray ray, Scene* scene) {
		double closest = INFINITY;
		Intersection *closestInter = nullptr;
		std::vector<Thing*> *items = scene->things();
		for (std::vector<Thing*>::iterator thing = items->begin(); thing != items->end(); ++thing) 
		{
			Intersection* inter = (*thing)->intersect(ray);
			if (inter != nullptr && inter->dist < closest) {
				closestInter = inter;
				closest = inter->dist;
			}
		}
		return closestInter;
	}


	double testRay(Ray ray, Scene* scene) 
	{
		Intersection* isect = this->intersections(ray, scene);
		if (isect != nullptr) 
		{
			return isect->dist;
		}
		else 
		{
			return NAN;
		}
	}


	Color traceRay(Ray &ray, Scene* scene, int depth) {
		Intersection *isect = this->intersections(ray, scene);
		if (isect == nullptr) {
			return Color::background;
		}
		else {
			return this->shade(isect, scene, depth);
		}
	}


	Color shade(Intersection* isect, Scene* scene, int depth) 
	{
		Vector d      = isect->ray.dir;
		Vector pos    = Vector::plus(Vector::times(isect->dist, d), isect->ray.start);
		Vector normal = isect->thing->normal(pos);

		Vector reflectDir  = Vector::minus(d, Vector::times(2, Vector::times(Vector::dot(normal, d), normal)));
		Color naturalColor = Color::plus(Color::background,
			this->getNaturalColor(isect->thing, pos, normal, reflectDir, scene));

		Color reflectedColor = (depth >= this->maxDepth) ? Color::grey : this->getReflectionColor(isect->thing, pos, normal, reflectDir, scene, depth);
		return Color::plus(naturalColor, reflectedColor);
	}


	Color getReflectionColor(Thing* thing, Vector pos, Vector normal, Vector rd, Scene* scene, int depth)
	{
		Ray ray(pos, rd); 
		return Color::scale(thing->surface()->reflect(pos), this->traceRay(ray, scene, depth + 1));
	}


	Color getNaturalColor(Thing* thing, Vector pos, Vector norm, Vector rd, Scene* scene)
	{
		Color c = Color::black;

		std::vector<Light*> *items = scene->lights();

		for (std::vector<Light*>::iterator item = items->begin(); item != items->end(); ++item)
		{
			Color newColor = addLight(c, (*item), pos, scene, thing, rd, norm);
			c = newColor;
		}
		return c;
	}

	Color addLight(Color col, Light* light, Vector pos, Scene* scene, Thing* thing, Vector rd, Vector norm)
	{
		Vector ldis = Vector::minus(light->pos, pos);
		Vector livec = Vector::norm(ldis);
		double neatIsect = this->testRay(Ray(pos, livec), scene);

		boolean isInShadow = (neatIsect == NAN) ? false : (neatIsect <= Vector::mag(ldis));
		if (isInShadow) {
			return col;
		}
		else {
			double illum = Vector::dot(livec, norm);
			Color lcolor = (illum > 0) ? Color::scale(illum, light->color)
				: Color::defaultColor;
			double specular = Vector::dot(livec, Vector::norm(rd));
			Color scolor = (specular > 0) ? Color::scale(pow(specular, thing->surface()->roughness()), light->color)
				: Color::defaultColor;
			return Color::plus(col, Color::plus(Color::times(thing->surface()->diffuse(pos), lcolor),
				Color::times(thing->surface()->specular(pos), scolor)));
		}
	}

	Vector getPoint(int x, int y, Camera camera, int screenWidth, int screenHeight)
	{
		double recenterX = (x - (screenWidth / 2.0)) / 2.0 / screenWidth;
		double recenterY = -(y - (screenHeight / 2.0)) / 2.0 / screenHeight;
		return Vector::norm(Vector::plus(camera.forward, Vector::plus(Vector::times(recenterX, camera.right), Vector::times(recenterY, camera.up))));
	}

public:
	
	void render(Scene* scene, byte* bitmapData, int stride, int w, int h)
	{
		Ray ray;
		ray.start     = scene->camera().pos;	
		Camera camera = scene->camera();
		
		for (int y = 0; y < h; ++y) 
		{
			int pos = y * stride;
			for (int x = 0; x < w; ++x) 
			{
				ray.dir   = this->getPoint(x, y, camera, h, w);
				Color color = this->traceRay(ray, scene, 0);
				RGB_COLOR rgbColor = Color::toDrawingColor(color);
				bitmapData[pos]     = rgbColor.b;
				bitmapData[pos + 1] = rgbColor.g;
				bitmapData[pos + 2] = rgbColor.r;
				bitmapData[pos + 3] = 255;
				pos += 4;
			}	
		}
	}
	
};

void SaveRGBBitmap(byte* pBitmapBits, LONG lWidth, LONG lHeight, LONG wBitsPerPixel, LPCSTR lpszFileName )
{
    BITMAPINFOHEADER bmpInfoHeader = {0};
    bmpInfoHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmpInfoHeader.biBitCount = wBitsPerPixel;
    bmpInfoHeader.biClrImportant = 0;
    bmpInfoHeader.biClrUsed = 0;
    bmpInfoHeader.biCompression = BI_RGB;
    bmpInfoHeader.biHeight = -lHeight;
    bmpInfoHeader.biWidth = lWidth;
    bmpInfoHeader.biPlanes = 1;
    bmpInfoHeader.biSizeImage = lWidth* lHeight * (wBitsPerPixel/8);

    BITMAPFILEHEADER bfh = {0};
    bfh.bfType = 'B' + ('M' << 8);
    bfh.bfOffBits = sizeof(BITMAPINFOHEADER) + sizeof(BITMAPFILEHEADER);
    bfh.bfSize    = bfh.bfOffBits + bmpInfoHeader.biSizeImage;
	
	FILE * hFile;
  	hFile = fopen(lpszFileName,"wb");

    if(!hFile) {
        return;
    }

	fwrite (&bfh , sizeof(char), sizeof(bfh), hFile);
	fwrite (&bmpInfoHeader , sizeof(char), sizeof(bmpInfoHeader), hFile);
    fwrite(pBitmapBits, sizeof(char), bmpInfoHeader.biSizeImage, hFile );
    fclose(hFile);
}


int main()
{
	std::cout << "Started " << std::endl;
	long t1 = GetTickCount();

	Scene* scene = (Scene*) new DefaultScene();
	RayTracerEngine* rayTracer = new RayTracerEngine();
	
	int width  = 500;
	int height = 500;
	int stride = width * 4;
	byte *bitmapData = new byte[stride * height];	

	rayTracer->render(scene, bitmapData, stride,width,height);
		
	long t2 = GetTickCount();
	long time = t2 - t1;

	std::cout << "Completed in " << time << " ms" << std::endl;
	SaveRGBBitmap(bitmapData, 500,500, 32, "cpp-raytracer.bmp");
	
	delete rayTracer;
	delete scene;	
	delete [] bmp;
	return 0;
};