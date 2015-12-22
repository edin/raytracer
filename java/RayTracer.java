import java.awt.Image;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.concurrent.TimeUnit;
import javax.imageio.ImageIO;

public class RayTracer
{
    public static void main(String[] args) throws IOException
    {
        BufferedImage b = new BufferedImage(500,500,BufferedImage.TYPE_INT_RGB);

        long t1 = System.nanoTime();
        Scene s = new DefaultScene();
        RayTracerEngine rt = new RayTracerEngine();
        rt.render(s, b);
        long t2 = System.nanoTime();
        long t = t2- t1 ;

        File outputfile = new File("java-ray-tracer.bmp");
        ImageIO.write(b, "bmp", outputfile);

        System.out.println("Time is " + TimeUnit.NANOSECONDS.toMillis(t) + " ms" );
    }
}

class Vector
{
    public double x;
    public double y;
    public double z;

    public Vector(double x, double y, double z)
    {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    static Vector times(double k,Vector v)   { return new Vector(k * v.x, k * v.y, k * v.z); }
    static Vector minus(Vector v1,Vector v2) { return new Vector(v1.x - v2.x, v1.y - v2.y, v1.z - v2.z); }
    static Vector plus(Vector v1,Vector  v2) { return new Vector(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z); }
    static double dot(Vector v1, Vector v2)  { return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z; }

    static double mag(Vector v)  {return Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);}
    static Vector norm(Vector v) {
        double mag = Vector.mag(v);
        double div = (mag == 0) ? Double.POSITIVE_INFINITY : 1.0 / mag;
        return Vector.times(div, v);
    }
    static Vector cross(Vector v1,Vector v2) {
        return new Vector(v1.y * v2.z - v1.z * v2.y,
                          v1.z * v2.x - v1.x * v2.z,
                          v1.x * v2.y - v1.y * v2.x);
    }
}

class Color
{
    public double r;
    public double g;
    public double b;

    public Color(double r,
                 double g,
                 double b) {
        this.r = r;
        this.g = g;
        this.b = b;
    }
    static Color scale(double k,Color v) { return new Color(k * v.r, k * v.g, k * v.b); }
    static Color plus(Color v1 ,Color v2) { return new Color(v1.r + v2.r, v1.g + v2.g, v1.b + v2.b); }
    static Color times(Color v1,Color v2) { return new Color(v1.r * v2.r, v1.g * v2.g, v1.b * v2.b); }
    static Color white = new Color(1.0, 1.0, 1.0);
    static Color grey = new Color(0.5, 0.5, 0.5);
    static Color black = new Color(0.0, 0.0, 0.0);
    static Color background = Color.black;
    static Color defaultColor = Color.black;

    static int toDrawingColor(Color c) {

        int r = legalize(c.r);
        int g = legalize(c.g);
        int b = legalize(c.b);

        java.awt.Color color = new java.awt.Color(r, g, b);
        return color.getRGB();
    }

    static int legalize(double c){
        int x = (int)(c*255);
        if (x < 0) x = 0;
        if (x > 255) x = 255;
        return x;
    }
}

class Camera
{
    public Vector forward;
    public Vector right;
    public Vector up;
    public Vector pos;

    public Camera(Vector pos, Vector lookAt) {
        this.pos = pos;
        Vector down = new Vector(0.0, -1.0, 0.0);
        this.forward = Vector.norm(Vector.minus(lookAt, this.pos));
        this.right = Vector.times(1.5, Vector.norm(Vector.cross(this.forward, down)));
        this.up = Vector.times(1.5, Vector.norm(Vector.cross(this.forward, this.right)));
    }
}

class Ray
{
    public Vector start;
    public Vector dir;

    public Ray(){}
    public Ray(Vector start, Vector dir)
    {
        this.start = start;
        this.dir = dir;
    }
}


class Intersection
{
    public Thing thing;
    public Ray ray;
    public double dist;

    public Intersection(Thing thing, Ray ray, double dist)
    {
        this.thing = thing;
        this.ray = ray;
        this.dist = dist;
    }
}


interface Surface
{
    public Color diffuse (Vector pos);
    public Color  specular(Vector pos);
    public double reflect(Vector pos);
    public double roughness();
}


interface Thing
{
    public Intersection intersect(Ray ray);
    public Vector normal(Vector pos);
    public Surface surface();
}


class Light
{
    Vector pos;
    Color color;
    public Light(Vector pos, Color color)
    {
        this.pos = pos;
        this.color = color;
    }
}


interface Scene
{
    public List<Thing> things();
    public List<Light> lights();
    Camera camera();
}

class Sphere implements Thing
{
    public double radius2;
    public Vector center;
    public Surface surface;


    public Sphere(Vector center, double radius, Surface surface)
    {
        this.radius2 = radius * radius;
        this.center = center;
        this.surface = surface;
    }
    public Vector normal(Vector pos) { return Vector.norm(Vector.minus(pos, this.center)); }
    public Intersection intersect(Ray ray)
    {
        Vector eo = Vector.minus(this.center, ray.start);
        double v = Vector.dot(eo, ray.dir);
        double dist = 0;
        if (v >= 0) {
            double disc = this.radius2 - (Vector.dot(eo, eo) - v * v);
            if (disc >= 0) {
                dist = v - Math.sqrt(disc);
            }
        }
        if (dist == 0) {
            return null;
        } else {
            return new Intersection(this, ray, dist);
        }
    }

    @Override
    public Surface surface()
    {
        return this.surface;
    }
}


class Plane implements Thing
{
    private Vector norm;
    public Surface surface;
    private double offset;

    public Vector normal(Vector pos) {
        return this.norm;
    }
    public Intersection intersect(Ray ray){
        double denom = Vector.dot(norm, ray.dir);
        if (denom > 0) {
            return null;
        } else {
            double dist = (Vector.dot(norm, ray.start) + offset) / (-denom);
            return new Intersection(this, ray, dist);
        }
    }

    public Plane(Vector norm, double offset, Surface surface)
    {
        this.surface = surface;
        this.norm = norm;
        this.offset = offset;
    }

    @Override
    public Surface surface() {
        return surface;
    }
}


class Surfaces {
    public static Surface shiny = new Surface() {
        @Override
        public Color diffuse(Vector pos) {
            return Color.white;
        }

        @Override
        public Color specular(Vector pos) {
            return Color.grey;
        }

        @Override
        public double reflect(Vector pos) {
            return 0.7;
        }

        @Override
        public double roughness() {
            return 250;
        }
    };


    public static Surface checkerboard = new Surface() {
        @Override
        public Color diffuse(Vector pos) {
            if ((Math.floor(pos.z) + Math.floor(pos.x)) % 2 != 0) {
                return Color.white;
            } else {
                return Color.black;
            }
        }

        @Override
        public Color specular(Vector pos) {
            return Color.white;
        }

        @Override
        public double reflect(Vector pos) {
            if ((Math.floor(pos.z) + Math.floor(pos.x)) % 2 != 0) {
                return 0.1;
            } else {
                return 0.7;
            }
        }

        @Override
        public double roughness() {
            return 150;
        }
    };
}


class DefaultScene implements Scene
{
    private List<Thing> things = new ArrayList<Thing>();
    private List<Light> lights = new ArrayList<Light>();
    private Camera camera;

    public DefaultScene()
    {
        this.things.add(new Plane(new Vector(0.0, 1.0, 0.0), 0.0, Surfaces.checkerboard));
        this.things.add(new Sphere(new Vector(0.0, 1.0, -0.25), 1.0, Surfaces.shiny));
        this.things.add(new Sphere(new Vector(-1.0, 0.5, 1.5), 0.5, Surfaces.shiny));


        Light a = new Light(new Vector(-2.0, 2.5, 0.0), new Color(0.49, 0.07, 0.07));
        Light b = new Light(new Vector(1.5, 2.5, 1.5),new Color(0.07, 0.07, 0.49));
        Light c = new Light(new Vector(1.5, 2.5, -1.5),new Color(0.07, 0.49, 0.071));
        Light d = new Light(new Vector(0.0, 3.5, 0.0),new Color(0.21, 0.21, 0.35) );

        this.lights.add(a);
        this.lights.add(b);
        this.lights.add(c);
        this.lights.add(d);

        this.camera= new Camera(new Vector(3.0, 2.0, 4.0), new Vector(-1.0, 0.5, 0.0));
    }

    @Override
    public List<Thing> things() {
        return things;
    }

    @Override
    public List<Light> lights() {
        return lights;
    }

    @Override
    public Camera camera() {
        return camera;
    }
}


class RayTracerEngine
{
    private int maxDepth = 5;


    private Intersection intersections(Ray ray,Scene scene) {
        double closest = Double.POSITIVE_INFINITY;
        Intersection closestInter = null;
        for (Thing thing : scene.things()) {
            Intersection inter = thing.intersect(ray);
            if (inter != null && inter.dist < closest) {
                closestInter = inter;
                closest = inter.dist;
            }
        }
        return closestInter;
    }


    private double testRay(Ray ray,Scene scene) {
        Intersection isect = this.intersections(ray, scene);
        if (isect != null) {
            return isect.dist;
        } else {
            return Double.NaN;
        }
    }


    private Color traceRay(Ray ray, Scene scene, int depth) {
        Intersection isect = this.intersections(ray, scene);
        if (isect == null) {
            return Color.background;
        } else {
            return this.shade(isect, scene, depth);
        }
    }


    private Color shade(Intersection isect,Scene scene, int depth) {
        Vector d = isect.ray.dir;
        Vector pos = Vector.plus(Vector.times(isect.dist, d), isect.ray.start);
        Vector normal = isect.thing.normal(pos);
        Vector reflectDir = Vector.minus(d, Vector.times(2, Vector.times(Vector.dot(normal, d), normal)));
        Color naturalColor = Color.plus(Color.background,
                                      this.getNaturalColor(isect.thing, pos, normal, reflectDir, scene));

        Color reflectedColor = (depth >= this.maxDepth) ? Color.grey : this.getReflectionColor(isect.thing, pos, normal, reflectDir, scene, depth);
        return Color.plus(naturalColor, reflectedColor);
    }


    private Color getReflectionColor(Thing thing,Vector pos,Vector normal,Vector rd, Scene scene,int depth)
    {

        return Color.scale(thing.surface().reflect(pos), this.traceRay(new Ray(pos, rd), scene, depth + 1));
    }


    private Color getNaturalColor(Thing thing, Vector pos,Vector norm,Vector rd,Scene scene)
    {
        Color c = Color.black;
        for(Light item : scene.lights())
        {
            Color newColor = addLight(c, item, pos, scene, thing, rd, norm);
            c = newColor;
        }
        return c;
    }

    public Color addLight(Color col, Light light, Vector pos, Scene scene, Thing thing, Vector rd, Vector norm)
    {
        Vector ldis = Vector.minus(light.pos, pos);
        Vector livec = Vector.norm(ldis);
        double neatIsect = this.testRay(new Ray(pos,  livec),  scene);

        boolean isInShadow = (neatIsect == Double.NaN) ? false : (neatIsect <= Vector.mag(ldis));
        if (isInShadow) {
            return col;
        } else {
            double illum = Vector.dot(livec, norm);
            Color lcolor = (illum > 0) ? Color.scale(illum, light.color)
                                      : Color.defaultColor;
            double specular = Vector.dot(livec, Vector.norm(rd));
            Color scolor = (specular > 0) ? Color.scale(Math.pow(specular, thing.surface().roughness()), light.color)
                                      : Color.defaultColor;
            return Color.plus(col, Color.plus(Color.times(thing.surface().diffuse(pos), lcolor),
                                              Color.times(thing.surface().specular(pos), scolor)));
        }
    }


    public void render(Scene scene, BufferedImage img)
    {
        int h = img.getHeight();
        int w = img.getWidth();

        for (int y = 0; y < h  ; y++)
        {
            for (int x = 0; x < w;  x++)
            {
                Color color = this.traceRay( new Ray(scene.camera().pos,  getPoint(x, y, scene.camera(),h,w)), scene, 0);
                int c = Color.toDrawingColor(color);
                img.setRGB(x, y, c);
            }
        }
    }

    private Vector getPoint(int x, int y,Camera camera, int screenWidth, int screenHeight)
    {
        double recenterX = (x - (screenWidth / 2.0)) / 2.0 / screenWidth;
        double recenterY = - (y - (screenHeight / 2.0)) / 2.0 / screenHeight;
        return Vector.norm(Vector.plus(camera.forward, Vector.plus(Vector.times(recenterX, camera.right), Vector.times(recenterY, camera.up))));
    }
}