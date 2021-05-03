import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

public class RayTracer {
    public static void main(String[] args) throws IOException {
        long start = System.nanoTime();
        Image image = new Image(500, 500);
        Scene scene = new Scene();
        RayTracerEngine tracer = new RayTracerEngine();
        tracer.render(scene, image);
        long t = System.nanoTime() - start;

        image.save("java-ray.bmp");
        System.out.println("Rendered in: " + TimeUnit.NANOSECONDS.toMillis(t) + " ms");
    }
}

class Vector {
    public double x;
    public double y;
    public double z;

    public Vector(double x, double y, double z) {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    public Vector times(double k) {
        return new Vector(k * x, k * y, k * z);
    }

    public Vector minus(Vector v) {
        return new Vector(x - v.x, y - v.y, z - v.z);
    }

    public Vector plus(Vector v) {
        return new Vector(x + v.x, y + v.y, z + v.z);
    }

    public double dot(Vector v) {
        return x * v.x + y * v.y + z * v.z;
    }

    public double mag() {
        return Math.sqrt(x * x + y * y + z * z);
    }

    public Vector norm() {
        double mag = this.mag();
        double div = (mag == 0) ? Double.POSITIVE_INFINITY : 1.0 / mag;
        return this.times(div);
    }

    public Vector cross(Vector v) {
        return new Vector(y * v.z - z * v.y, z * v.x - x * v.z, x * v.y - y * v.x);
    }
}

class RGBColor {
    public byte b;
    public byte g;
    public byte r;
    public byte a;
}

class Color {
    public double r;
    public double g;
    public double b;

    public Color(double r, double g, double b) {
        this.r = r;
        this.g = g;
        this.b = b;
    }

    public Color scale(double k) {
        return new Color(k * r, k * g, k * b);
    }

    public Color plus(Color v) {
        return new Color(r + v.r, g + v.g, b + v.b);
    }

    public Color times(Color v) {
        return new Color(r * v.r, g * v.g, b * v.b);
    }

    static Color white = new Color(1.0, 1.0, 1.0);
    static Color grey = new Color(0.5, 0.5, 0.5);
    static Color black = new Color(0.0, 0.0, 0.0);
    static Color background = Color.black;
    static Color defaultColor = Color.black;

    public RGBColor toDrawingColor() {
        var result = new RGBColor();
        result.r = legalize(this.r);
        result.g = legalize(this.g);
        result.b = legalize(this.b);
        result.a = -1;
        return result;
    }

    private static byte legalize(double c) {
        int x = (int) (c * 255);
        if (x < 0) {
            x = 0;
        } else if (x > 255) {
            x = 255;
        }
        return (byte) x;
    }
}

class Camera {
    public Vector forward;
    public Vector right;
    public Vector up;
    public Vector pos;

    public Camera(Vector pos, Vector lookAt) {
        Vector down = new Vector(0.0, -1.0, 0.0);
        this.pos = pos;
        this.forward = lookAt.minus(this.pos).norm();
        this.right = this.forward.cross(down).norm().times(1.5);
        this.up = this.forward.cross(right).norm().times(1.5);
    }

    public Vector getPoint(int x, int y, int screenWidth, int screenHeight) {
        double recenterX = (x - (screenWidth / 2.0)) / 2.0 / screenWidth;
        double recenterY = -(y - (screenHeight / 2.0)) / 2.0 / screenHeight;
        return forward.plus(right.times(recenterX)).plus(up.times(recenterY)).norm();
    }
}

class Ray {
    public Vector start;
    public Vector dir;

    public Ray() {
    }

    public Ray(Vector start, Vector dir) {
        this.start = start;
        this.dir = dir;
    }
}

class Intersection {
    public Thing thing;
    public Ray ray;
    public double dist;

    public Intersection(Thing thing, Ray ray, double dist) {
        this.thing = thing;
        this.ray = ray;
        this.dist = dist;
    }
}

interface Surface {
    public Color diffuse(Vector pos);

    public Color specular(Vector pos);

    public double reflect(Vector pos);

    public double roughness();
}

interface Thing {
    public Intersection intersect(Ray ray);

    public Vector normal(Vector pos);

    public Surface surface();
}

class Light {
    Vector pos;
    Color color;

    public Light(Vector pos, Color color) {
        this.pos = pos;
        this.color = color;
    }
}

class Sphere implements Thing {
    public double radius2;
    public Vector center;
    public Surface surface;

    public Sphere(Vector center, double radius, Surface surface) {
        this.radius2 = radius * radius;
        this.center = center;
        this.surface = surface;
    }

    public Vector normal(Vector pos) {
        return pos.minus(this.center).norm();
    }

    public Intersection intersect(Ray ray) {
        Vector eo = this.center.minus(ray.start);
        double v = eo.dot(ray.dir);
        double dist = 0;
        if (v >= 0) {
            double disc = this.radius2 - (eo.dot(eo) - v * v);
            if (disc >= 0) {
                dist = v - Math.sqrt(disc);
                return new Intersection(this, ray, dist);
            }
        }
        return null;
    }

    @Override
    public Surface surface() {
        return this.surface;
    }
}

class Plane implements Thing {
    private Vector norm;
    public Surface surface;
    private double offset;

    public Vector normal(Vector pos) {
        return this.norm;
    }

    public Intersection intersect(Ray ray) {
        double denom = norm.dot(ray.dir);
        if (denom > 0) {
            return null;
        }
        double dist = (norm.dot(ray.start) + offset) / (-denom);
        return new Intersection(this, ray, dist);
    }

    public Plane(Vector norm, double offset, Surface surface) {
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
            }
            return Color.black;
        }

        @Override
        public Color specular(Vector pos) {
            return Color.white;
        }

        @Override
        public double reflect(Vector pos) {
            if ((Math.floor(pos.z) + Math.floor(pos.x)) % 2 != 0) {
                return 0.1;
            }
            return 0.7;
        }

        @Override
        public double roughness() {
            return 150;
        }
    };
}

class Scene {
    public List<Thing> things = new ArrayList<Thing>();
    public List<Light> lights = new ArrayList<Light>();
    public Camera camera;

    public Scene() {
        things.add(new Plane(new Vector(0.0, 1.0, 0.0), 0.0, Surfaces.checkerboard));
        things.add(new Sphere(new Vector(0.0, 1.0, -0.25), 1.0, Surfaces.shiny));
        things.add(new Sphere(new Vector(-1.0, 0.5, 1.5), 0.5, Surfaces.shiny));

        lights.add(new Light(new Vector(-2.0, 2.5, 0.0), new Color(0.49, 0.07, 0.07)));
        lights.add(new Light(new Vector(1.5, 2.5, 1.5), new Color(0.07, 0.07, 0.49)));
        lights.add(new Light(new Vector(1.5, 2.5, -1.5), new Color(0.07, 0.49, 0.071)));
        lights.add(new Light(new Vector(0.0, 3.5, 0.0), new Color(0.21, 0.21, 0.35)));

        camera = new Camera(new Vector(3.0, 2.0, 4.0), new Vector(-1.0, 0.5, 0.0));
    }
}

class RayTracerEngine {
    private int maxDepth = 5;

    private Intersection intersections(Ray ray, Scene scene) {
        double closest = Double.POSITIVE_INFINITY;
        Intersection closestInter = null;
        for (Thing thing : scene.things) {
            Intersection inter = thing.intersect(ray);
            if (inter != null && inter.dist < closest) {
                closestInter = inter;
                closest = inter.dist;
            }
        }
        return closestInter;
    }

    private Color traceRay(Ray ray, Scene scene, int depth) {
        Intersection isect = intersections(ray, scene);
        if (isect == null) {
            return Color.background;
        }
        return shade(isect, scene, depth);
    }

    private Color shade(Intersection isect, Scene scene, int depth) {
        Vector d = isect.ray.dir;
        Vector pos = d.times(isect.dist).plus(isect.ray.start);
        Vector normal = isect.thing.normal(pos);

        Vector reflectDir = d.minus(normal.times(normal.dot(d)).times(2));
        Color naturalColor = Color.background.plus(getNaturalColor(isect.thing, pos, normal, reflectDir, scene));

        Color reflectedColor = Color.grey;
        if (depth < this.maxDepth) {
            reflectedColor = getReflectionColor(isect.thing, pos, normal, reflectDir, scene, depth);
        }
        return naturalColor.plus(reflectedColor);
    }

    private Color getReflectionColor(Thing thing, Vector pos, Vector normal, Vector rd, Scene scene, int depth) {
        Color color = traceRay(new Ray(pos, rd), scene, depth + 1);
        double reflect = thing.surface().reflect(pos);
        return color.scale(reflect);
    }

    private Color getNaturalColor(Thing thing, Vector pos, Vector norm, Vector rd, Scene scene) {
        Color color = Color.black;
        for (Light light : scene.lights) {
            Vector ldis = light.pos.minus(pos);
            Vector livec = ldis.norm();
            Ray ray = new Ray(pos, livec);

            Intersection neatIsect = intersections(ray, scene);
            boolean isInShadow = (neatIsect != null) && (neatIsect.dist <= ldis.mag());

            if (!isInShadow) {
                double illum = livec.dot(norm);
                double specular = livec.dot(rd.norm());

                Color lcolor = Color.defaultColor;
                Color scolor = Color.defaultColor;

                if (illum > 0) {
                    lcolor = light.color.scale(illum);
                }

                if (specular > 0) {
                    scolor = light.color.scale(Math.pow(specular, thing.surface().roughness()));
                }
                Color surfDiffuse = thing.surface().diffuse(pos);
                Color surfSpecular = thing.surface().specular(pos);
                color = color.plus(lcolor.times(surfDiffuse)).plus(scolor.times(surfSpecular));
            }

        }
        return color;
    }

    public void render(Scene scene, Image img) {
        int h = img.getHeight();
        int w = img.getWidth();
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                Vector point = scene.camera.getPoint(x, y, w, h);
                Ray ray = new Ray(scene.camera.pos, point);
                Color color = this.traceRay(ray, scene, 0);
                img.setColor(x, y, color.toDrawingColor());
            }
        }
    }
}

class BITMAPINFOHEADER {
    public int biSize;
    public int biWidth;
    public int biHeight;
    public short biPlanes;
    public short biBitCount;
    public int biCompression;
    public int biSizeImage;
    public int biXPelsPerMeter;
    public int biYPelsPerMeter;
    public int biClrUsed;
    public int biClrImportant;

    public byte[] getBytes() {
        return Encoding.Join(Encoding.DWORD(this.biSize), Encoding.LONG(this.biWidth), Encoding.LONG(this.biHeight),
                Encoding.WORD(this.biPlanes), Encoding.WORD(this.biBitCount), Encoding.DWORD(this.biCompression),
                Encoding.DWORD(this.biSizeImage), Encoding.LONG(this.biXPelsPerMeter),
                Encoding.LONG(this.biYPelsPerMeter), Encoding.DWORD(this.biClrUsed),
                Encoding.DWORD(this.biClrImportant));
    }
}

class BITMAPFILEHEADER {
    public short bfType;
    public int bfSize;
    public int bfReserved;
    public int bfOffBits;

    public byte[] getBytes() {
        return Encoding.Join(Encoding.WORD(this.bfType), Encoding.DWORD(this.bfSize), Encoding.DWORD(this.bfReserved),
                Encoding.DWORD(this.bfOffBits));
    }
}

class Encoding {
    static byte[] DWORD(int n) {
        // Unsigned 32 bit integer
        byte b0 = (byte) ((n >> 0) & 0x000000FF);
        byte b1 = (byte) ((n >> 8) & 0x000000FF);
        byte b2 = (byte) ((n >> 16) & 0x000000FF);
        byte b3 = (byte) ((n >> 24) & 0x000000FF);
        return new byte[] { b0, b1, b2, b3 };
    }

    static byte[] LONG(int n) {
        // Signed 32 bit integer (since we use zeros this will work i hope)
        return Encoding.DWORD(n);
    }

    static byte[] WORD(int n) {
        // Unsigned 16 bit integer
        byte b0 = (byte) (n & 0x000000FF);
        byte b1 = (byte) ((n >> 8) & 0x000000FF);
        return new byte[] { b0, b1 };
    }

    static byte[] Join(byte[]... elements) {
        int size = 0;
        for (var e : elements) {
            size += e.length;
        }
        var result = new byte[size];
        int pos = 0;
        for (var e : elements) {
            for (byte b : e) {
                result[pos] = b;
                pos++;
            }
        }
        return result;
    }
}

class Image {
    private final int width;
    private final int height;
    private RGBColor[] data;

    public Image(int width, int height) {
        this.width = width;
        this.height = height;
        this.data = new RGBColor[width * height];
    }

    public int getWidth() {
        return width;
    }

    public int getHeight() {
        return height;
    }

    public void setColor(int x, int y, RGBColor color) {
        this.data[y * width + x] = color;
    }

    public void save(String fileName) {
        var infoHeaderSize = 40;
        var fileHeaderSize = 14;
        var offBits = infoHeaderSize + fileHeaderSize;

        var infoHeader = new BITMAPINFOHEADER();
        infoHeader.biSize = infoHeaderSize;
        infoHeader.biBitCount = 32;
        infoHeader.biClrImportant = 0;
        infoHeader.biClrUsed = 0;
        infoHeader.biCompression = 0;
        infoHeader.biHeight = -height;
        infoHeader.biWidth = width;
        infoHeader.biPlanes = 1;
        infoHeader.biSizeImage = (width * height * 4);

        var fileHeader = new BITMAPFILEHEADER();
        fileHeader.bfType = 'B' + ('M' << 8);
        fileHeader.bfOffBits = offBits;
        fileHeader.bfSize = (offBits + infoHeader.biSizeImage);

        try {
            var os = new FileOutputStream(fileName);
            var headerBytes = fileHeader.getBytes();
            var infoBytes = infoHeader.getBytes();

            os.write(headerBytes);
            os.write(infoBytes);

            for (RGBColor color : this.data) {
                os.write(color.b);
                os.write(color.g);
                os.write(color.r);
                os.write(color.a);
            }
            os.close();
        } catch (IOException ex) {
        }
    }
}