#include <windows.h>
#include <math.h>
#include <vector>
#include <iostream>
#include <memory>
#include <fstream>


#ifdef _MSC_VER
    #ifndef INFINITY
        #define INFINITY (DBL_MAX+DBL_MAX)
        #define NAN (INFINITY-INFINITY)
    #endif
#endif

struct RgbColor 
{
    byte b;
    byte g;
    byte r;
    byte a;
};


class Vector
{
public:
    double x;
    double y;
    double z;

    Vector() : x(0), y(0), z(0)
    {
    }

    Vector(double x, double y, double z) 
    {
        this->x = x;
        this->y = y;
        this->z = z;
    }
    
    static Vector cross(const Vector &v1, const Vector &v2)
    {
        return Vector(v1.y * v2.z - v1.z * v2.y,
                      v1.z * v2.x - v1.x * v2.z,
                      v1.x * v2.y - v1.y * v2.x);
    }
    
	double mag() const
    {
        return sqrt(this->x * this->x + this->y * this->y + this->z * this->z);     
    }   
    
	Vector norm() const
    {
        double mag = this->mag();
        double div = (mag == 0) ? INFINITY : 1.0 / mag;
        return this->scale(div);       
    }
    
    Vector cross(const Vector &v2) const
    {
        return Vector(this->y * v2.z - this->z * v2.y,
                      this->z * v2.x - this->x * v2.z,
                      this->x * v2.y - this->y * v2.x);     
    }
    
	Vector scale(double k) const
    {
        return Vector(k * this->x, k * this->y, k * this->z);     
    }    
    
    Vector operator*(double k) 
    {
        return this->scale(k);
    }
        
    double operator*(const Vector& v2)
    {
        return this->x * v2.x + this->y * v2.y + this->z * v2.z;       
    }
        
	Vector operator+(const Vector& v2)
    {
        return Vector(this->x + v2.x, this->y + v2.y, this->z + v2.z);
    }
    
	Vector operator-(const Vector& v2)
    {
        return Vector(this->x - v2.x, this->y - v2.y, this->z - v2.z);
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

    Color() : r(0), g(0), b(0)
    {
    }

    Color(double r, double g, double b)
    {
        this->r = r;
        this->g = g;
        this->b = b;
    }

    Color scale(double k)
    {
        return Color(k * this->r, k * this->g, k * this->b);
    }

    static Color times(const Color &v1, const Color &v2)
    {
        return Color(v1.r * v2.r, v1.g * v2.g, v1.b * v2.b);
    }
    
    Color operator*(double k)
    {
        return this->scale(k);
    }     
    
    Color operator*(const Color& v2)
    {
        return Color(this->r * v2.r, this->g * v2.g, this->b * v2.b);
    }     
    
    Color operator+(const Color& v2)
    {
        return Color(this->r + v2.r, this->g + v2.g, this->b + v2.b);
    }    

    RgbColor toDrawingColor()
    {
        RgbColor color;
        color.r = (byte)legalize(this->r);
        color.g = (byte)legalize(this->g);
        color.b = (byte)legalize(this->b);
        color.a = 255;
        return color;
    }

    static int legalize(double c)
    {
        int x = (int)(c * 255);
        if (x < 0)   x = 0;
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

    Camera (Vector pos, Vector lookAt)
    {
        this->pos      = pos;
        Vector down    = Vector(0.0, -1.0, 0.0);
        Vector forward = lookAt - pos;
        this->forward  = forward.norm();
        this->right    = this->forward.cross(down).norm() * 1.5;
        this->up       = this->forward.cross(this->right).norm() * 1.5;
    }
};

class Ray
{
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

class Intersection
{
private:
	bool m_IsValid = false;
public:
    Thing* thing;
    Ray ray;
    double dist;

	Intersection()
	{
		m_IsValid = false;
	}

	Intersection(Thing* thing, Ray ray, double dist)
    {
        this->thing = thing;
        this->ray   = ray;
        this->dist  = dist;
		this->m_IsValid = true;
    }

	bool IsValid(){
		return m_IsValid;
	}
};


class Surface
{
public:
    virtual Color  diffuse(Vector& pos)  { return Color::black; };
    virtual Color  specular(Vector& pos) { return Color::black; };
    virtual double reflect(Vector& pos)  { return 0; };
    virtual double roughness()           { return 0; };
};


class Thing
{
public:
	virtual Intersection intersect(Ray& ray) = 0;
	virtual Vector normal(Vector& pos) = 0;
	virtual std::shared_ptr<Surface> surface() = 0;
};


class Light
{
public:
    Vector pos;
    Color color;

    Light(Vector pos, Color color)
    {
        this->pos = pos;
        this->color = color;
    }
};

class Sphere : public Thing
{
private:
	std::shared_ptr<Surface> m_surface;
    double   m_radius2;
    Vector   m_center;    
public:

	Sphere(Vector center, double radius, std::shared_ptr<Surface> const& surface)
    {
		this->m_radius2 = radius * radius;
		this->m_center  = center;
        this->m_surface = surface;
    }

	Vector normal(Vector& pos)
    { 
		return (pos - this->m_center).norm();
    }

	Intersection intersect(Ray& ray)
    {
		Vector eo = this->m_center - ray.start;
        double v    = eo * ray.dir;
        double dist = 0;
        
        if (v >= 0) {
			double disc = this->m_radius2 - ((eo * eo) - (v * v));
            if (disc >= 0) {
                dist = v - sqrt(disc);
            }
        }
        if (dist == 0) {
			return Intersection();
        }
		return Intersection(this, ray, dist);
    }

	std::shared_ptr<Surface> surface() 
    {
		return m_surface;
    }
};


class Plane : public Thing
{
private:
    Vector norm;
    double offset;
	std::shared_ptr<Surface> m_surface;
public:

	Vector normal(Vector& pos)
    {
        return this->norm;
    }

	Intersection intersect(Ray& ray) 
    {
        double denom = norm * ray.dir;
        if (denom > 0) {
			return Intersection();
        }
        double dist = ((norm * ray.start) + offset) / (-denom);
        return Intersection(this, ray, dist);
    }

	Plane(Vector norm, double offset, std::shared_ptr<Surface> surface)
    {
        this->m_surface = surface;
        this->norm = norm;
        this->offset = offset;
    }

	std::shared_ptr<Surface> surface()
    {
        return m_surface;
    }
};


class ShinySurface : public Surface
{
public:
    Color diffuse(Vector& pos)
    {
        return Color::white;
    }

    Color specular(Vector& pos)
    {
        return Color::grey;
    }

    double reflect(Vector& pos)
    {
        return 0.7;
    }
    
    double roughness()
    {
        return 250.0;
    }
};


class CheckerboardSurface : public Surface
{
public:
    Color diffuse(Vector& pos)
    {
        if (((int)(floor(pos.z) + floor(pos.x)))  % 2 != 0) 
        {
            return Color::white;
        }
        return Color::black;
    }

    Color specular(Vector& pos)
    {
        return Color::white;
    }

    double reflect(Vector& pos)
    {
        if (((int)(floor(pos.z) + floor(pos.x))) % 2 != 0) 
        {
            return 0.1;
        }
        return 0.7;
    }
    
    double roughness()
    {
        return 150.0;
    }
};


class Surfaces
{
public:
	static std::shared_ptr<ShinySurface> shiny;
	static std::shared_ptr<CheckerboardSurface> checkerboard;
};

std::shared_ptr<ShinySurface>        Surfaces::shiny        = std::make_shared<ShinySurface>();
std::shared_ptr<CheckerboardSurface> Surfaces::checkerboard = std::make_shared<CheckerboardSurface>();

class Scene
{
public:
	virtual std::vector<std::shared_ptr<Thing>> const&  things() = 0;
	virtual std::vector<std::shared_ptr<Light>> const&  lights() = 0;
	virtual std::shared_ptr<Camera> const&  camera() = 0;
};

class DefaultScene : public  Scene
{
private:
    std::vector<std::shared_ptr<Thing>> m_things;
    std::vector<std::shared_ptr<Light>> m_lights;
	std::shared_ptr<Camera> m_camera;
public:
    DefaultScene()
    {
		m_things.emplace_back(new Plane(Vector(0.0, 1.0, 0.0), 0.0, Surfaces::checkerboard));
		m_things.emplace_back(new Sphere(Vector(0.0, 1.0, -0.25), 1.0, Surfaces::shiny));
		m_things.emplace_back(new Sphere(Vector(-1.0, 0.5, 1.5), 0.5, Surfaces::shiny));

		m_lights.emplace_back(new Light(Vector(-2.0, 2.5, 0.0), Color(0.49, 0.07, 0.07)));
		m_lights.emplace_back(new Light(Vector(1.5, 2.5, 1.5), Color(0.07, 0.07, 0.49)));
		m_lights.emplace_back(new Light(Vector(1.5, 2.5, -1.5), Color(0.07, 0.49, 0.071)));
		m_lights.emplace_back(new Light(Vector(0.0, 3.5, 0.0), Color(0.21, 0.21, 0.35)));

        this->m_camera = std::make_shared<Camera>(Vector(3.0, 2.0, 4.0), Vector(-1.0, 0.5, 0.0));
    }

	std::vector<std::shared_ptr<Thing>> const& things()
    {
		return m_things;
    }

	std::vector<std::shared_ptr<Light>> const& lights()
    {
		return m_lights;
    }

	std::shared_ptr<Camera> const& camera()
    {
        return m_camera;
    }
};


class RayTracerEngine
{
private:
    static const int maxDepth = 5;

	 Intersection intersections(Ray& ray, Scene& scene)
     {
        double closest = INFINITY;
		Intersection closestInter;

		for (auto& thing : scene.things())
        {
			auto inter = thing->intersect(ray);
            if (inter.IsValid() && inter.dist < closest) 
            {
                closestInter = inter;
                closest = inter.dist;
            }
        }
        return closestInter;
    }

    double testRay(Ray& ray, Scene& scene)
    {
		auto isect = this->intersections(ray, scene);
        if (isect.IsValid())
        {
			return isect.dist;
        }
        return NAN;
    }

    Color traceRay(Ray& ray, Scene& scene, int depth) 
    {
		auto isect = this->intersections(ray, scene);
        if (isect.IsValid()) 
        {
			return this->shade(isect, scene, depth);
        }
		return Color::background;
    }

	Color shade(Intersection& isect, Scene& scene, int depth)
    {
        Vector d          = isect.ray.dir;
        Vector pos        = (d * isect.dist) + isect.ray.start;
        Vector normal     = isect.thing->normal(pos);
        Vector reflectDir = d -  ((normal * (normal * d)) * 2);
          
        Color naturalColor   = Color::background + this->getNaturalColor(isect.thing, pos, normal, reflectDir, scene);
        Color reflectedColor = (depth >= this->maxDepth) 
                               ? Color::grey 
                               : this->getReflectionColor(isect.thing, pos, normal, reflectDir, scene, depth);
                                
        return naturalColor + reflectedColor;
    }

	Color getReflectionColor(Thing* thing, Vector& pos, Vector& normal, Vector& rd, Scene& scene, int depth)
    {
        Ray    ray(pos, rd);
        Color  color  = this->traceRay(ray, scene, depth + 1);
        double factor = thing->surface()->reflect(pos);
        return color.scale(factor);
    }

	Color getNaturalColor(Thing* thing, Vector& pos, Vector& norm, Vector& rd, Scene& scene)
    {
        Color result = Color::black;
        auto items = scene.lights();

        for(auto& item: items)
        {
            addLight(result, item, pos, scene, thing, rd, norm);
        }
        return result;
    }

	void addLight(Color& resultColor, std::shared_ptr<Light> const& light, Vector& pos, Scene& scene, Thing* thing, Vector& rd, Vector& norm)
    {
        Vector ldis  = light->pos - pos;
        Vector livec = ldis.norm();
        Ray ray(pos, livec);
        double neatIsect = this->testRay(ray, scene);

        bool isInShadow = (neatIsect == NAN) ? false : (neatIsect <= ldis.mag());
		if (isInShadow) {
			return;
		}
		double illum = livec * norm;
		double specular = livec * rd.norm();

		Color lcolor = (illum > 0) ? (light->color * illum) : Color::defaultColor;
		Color scolor = (specular > 0) ? (light->color * pow(specular, thing->surface()->roughness())) : Color::defaultColor;
		resultColor = resultColor + lcolor * thing->surface()->diffuse(pos) + scolor * thing->surface()->specular(pos);
    }

    Vector getPoint(int x, int y, std::shared_ptr<Camera> const& camera, int screenWidth, int screenHeight)
    {
        double recenterX =  (x - (screenWidth / 2.0)) / 2.0 / screenWidth;
        double recenterY = -(y - (screenHeight / 2.0)) / 2.0 / screenHeight;
        return (camera->forward + ((camera->right * recenterX) + (camera->up * recenterY))).norm();
    }

public:
    void render(Scene& scene, byte* bitmapData, int stride, int w, int h)
    {
        Ray ray;
        ray.start   = scene.camera()->pos;
        auto camera = scene.camera();

        for (int y = 0; y < h; ++y)
        {
            RgbColor* pColor = (RgbColor*)(&bitmapData[y * stride]);
            for (int x = 0; x < w; ++x)
            {
                ray.dir = this->getPoint(x, y, camera, h, w);
                *pColor = this->traceRay(ray, scene, 0).toDrawingColor();
				pColor++;
            }
        }
    }
};

void SaveRGBBitmap(byte* pBitmapBits, LONG lWidth, LONG lHeight, WORD wBitsPerPixel, LPCSTR lpszFileName)
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

	std::ofstream file(lpszFileName, std::ios::binary | std::ios::trunc);
	file.write((const char*)&bfh, sizeof(bfh));
	file.write((const char*)&bmpInfoHeader, sizeof(bmpInfoHeader));
	file.write((const char*)pBitmapBits, bmpInfoHeader.biSizeImage);
	file.close();
}

int main()
{
    std::cout << "Started " << std::endl;
    long t1 = GetTickCount();

    DefaultScene    scene;
    RayTracerEngine rayTracer;

    int width  = 500;
    int height = 500;
    int stride = width * 4;
    
    std::vector<byte> bitmapData(stride * height);
    rayTracer.render(scene, &bitmapData[0], stride, width, height);

    long t2 = GetTickCount();
    long time = t2 - t1;

    std::cout << "Completed in " << time << " ms" << std::endl;
	SaveRGBBitmap(&bitmapData[0], width, height, 32, "cpp-raytracer.bmp");

    return 0;
};