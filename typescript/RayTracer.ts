import * as fs from "fs";
const { performance } = require('perf_hooks');

class Vector {
    constructor(public x: number, public y: number, public z: number) {}

    times(k: number): Vector {
        return new Vector(k * this.x, k * this.y, k * this.z);
    }

    minus(v: Vector): Vector {
        return new Vector(this.x - v.x, this.y - v.y, this.z - v.z);
    }

    plus(v: Vector) {
        return new Vector(this.x + v.x, this.y + v.y, this.z + v.z);
    }

    dot(this: Vector, v: Vector) {
        return this.x * v.x + this.y * v.y + this.z * v.z;
    }

    mag(): number {
        return Math.sqrt(this.x * this.x + this.y * this.y + this.z * this.z);
    }

    norm(): Vector {
        let mag = this.mag();
        let div = mag === 0 ? Infinity : 1.0 / mag;
        return this.times(div);
    }

    cross(v: Vector) {
        return new Vector(this.y * v.z - this.z * v.y, this.z * v.x - this.x * v.z, this.x * v.y - this.y * v.x);
    }
}

class Color {
    constructor(public r: number, public g: number, public b: number) {}

    scale(k: number) {
        return new Color(k * this.r, k * this.g, k * this.b);
    }

    plus(this: Color, c: Color) {
        return new Color(this.r + c.r, this.g + c.g, this.b + c.b);
    }

    times(this: Color, c: Color) {
        return new Color(this.r * c.r, this.g * c.g, this.b * c.b);
    }

    static white = new Color(1.0, 1.0, 1.0);
    static grey = new Color(0.5, 0.5, 0.5);
    static black = new Color(0.0, 0.0, 0.0);
    static background = Color.black;
    static defaultColor = Color.black;

    toDrawingColor(): Color {
        let legalize = (d: number) => {
            if (d > 1) return 1;
            if (d < 0) return 0;
            return d;
        }
        return new Color(
            Math.floor(legalize(this.r) * 255),
            Math.floor(legalize(this.g) * 255),
            Math.floor(legalize(this.b) * 255),
        )
    }
}

class Camera {
    forward: Vector;
    right: Vector;
    up: Vector;

    constructor(public pos: Vector, lookAt: Vector) {
        let down = new Vector(0.0, -1.0, 0.0);
        this.forward = lookAt.minus(this.pos).norm();
        this.right = this.forward.cross(down).norm().times(1.5);
        this.up = this.forward.cross(this.right).norm().times(1.5);
    }

    public getPoint(x: number, y:number, screenWidth: number, screenHeight: number): Vector {
        let rx =  (x - screenWidth / 2.0) / 2.0 / screenWidth;
        let ry = -(y - screenHeight / 2.0) / 2.0 / screenHeight;
        return this.right.times(rx).plus(this.up.times(ry)).plus(this.forward).norm();
    };    
}

class Ray {
    public constructor(public start: Vector, public dir:Vector){}
}

class Intersection {
    public constructor(public thing: Thing, public ray: Ray, public dist: number) {}
}

interface Surface {
    diffuse (pos: Vector): Color;
    specular (pos: Vector): Color;
    reflect (pos: Vector): number;
    roughness: number;
}

interface Thing {
    intersect (ray: Ray): Intersection;
    normal (pos: Vector): Vector;
    surface: Surface;
}

class Light {
    constructor(public pos: Vector, public color:Color) {}
}

class Scene {
    constructor(public things: Thing[], public lights:Light[], public camera: Camera) {}
}

class Sphere implements Thing {
    radius2: number;

    constructor(public center: Vector, radius: number, public surface: Surface) {
        this.radius2 = radius * radius;
    }

    normal(pos: Vector): Vector {
        return pos.minus(this.center).norm();
    }

    intersect(ray: Ray): Intersection {
        let eo = this.center.minus(ray.start);
        let v =eo.dot(ray.dir);
        let dist = 0;
        if (v >= 0) {
            let disc = this.radius2 - (eo.dot(eo) - v * v);
            dist = (disc >= 0) ? v - Math.sqrt(disc) : dist;
        }
        return (dist === 0) ? null : new Intersection(this, ray, dist);
    }
}

class Plane implements Thing {
    constructor(private norm: Vector, private offset: number, public surface: Surface) {}

    public normal (pos: Vector):Vector {
        return this.norm;
    }
    public intersect(ray: Ray): Intersection {
        let denom = this.norm.dot(ray.dir);
        if (denom > 0) {
            return null;
        } else {
            let dist = (this.norm.dot(ray.start) + this.offset) / -denom;
            return new Intersection(this, ray, dist);
        }
    }
}

class ShinySurface implements Surface {
    public roughness = 250;
    public diffuse (pos: Vector) {
        return Color.white;
    }
    public specular (pos: Vector) {
        return Color.grey;
    }
    public reflect (pos: Vector) {
        return 0.7;
    }
}

class CheckerboardSurface implements Surface {
    public roughness = 150;

    private condition(pos:Vector): boolean {
        return (Math.floor(pos.z) + Math.floor(pos.x)) % 2 !== 0;
    } 

    public diffuse(pos:Vector): Color {
        return this.condition(pos) ? Color.white : Color.black;
    }

    public specular(pos: Vector): Color {
        return Color.white;
    }
    
    public reflect(pos: Vector): number {
        return this.condition(pos)  ? 0.1 : 0.7;
    }
}

class RayTracer {
    private maxDepth = 5;

    private intersections(ray: Ray, scene: Scene): Intersection|null {
        return scene.things
            .map(thing => thing.intersect(ray))
            .filter(inter => inter !== null)
            .reduce((a,b)=> {
                return (a != null && a.dist < b.dist) ? a : b
            }, null)
    }

    private traceRay(ray: Ray, scene: Scene, depth: number): Color {
        let isect = this.intersections(ray, scene);
        return (!isect) ? Color.background : this.shade(isect, scene, depth);
    }

    private shade(isect: Intersection, scene: Scene, depth: number) {
        let d = isect.ray.dir;
        let pos = d.times(isect.dist).plus(isect.ray.start);
        let normal = isect.thing.normal(pos);
        let reflectDir = d.minus(normal.times(normal.dot(d)).times(2))
        
        let naturalColor = Color.background.plus(this.getNaturalColor(isect.thing, pos, normal, reflectDir, scene));
        let reflectedColor = depth >= this.maxDepth ? Color.grey : this.getReflectionColor(isect.thing, pos, normal, reflectDir, scene, depth);

        return naturalColor.plus(reflectedColor);
    }

    private getReflectionColor(thing: Thing, pos: Vector, normal: Vector, rd: Vector, scene: Scene, depth: number) {
        let ray = new Ray(pos, rd)
        let color = this.traceRay(ray, scene, depth + 1)
        let reflect = thing.surface.reflect(pos);
        return color.scale(reflect);
    }

    private getNaturalColor(thing: Thing, pos: Vector, norm: Vector, rd: Vector, scene: Scene) {
        let addLight = (col:Color, light:Light) => {
            let ldis = light.pos.minus(pos);
            let livec = ldis.norm();
            let neatIsect = this.intersections(new Ray(pos, livec), scene);
            let isInShadow = neatIsect && neatIsect.dist <= ldis.mag();
            if (isInShadow) {
                return col;
            } else {
                let illum = livec.dot(norm);
                let lcolor = illum > 0 ?  light.color.scale(illum) : Color.defaultColor;
                let specular =livec.dot(rd.norm());
                let scolor = specular > 0 ? light.color.scale(Math.pow(specular, thing.surface.roughness)) : Color.defaultColor;
                let surfDiffuse = thing.surface.diffuse(pos);
                let surfSpecular = thing.surface.specular(pos);

                return col.plus(lcolor.times(surfDiffuse)).plus(scolor.times(surfSpecular))
            }
        };
        return scene.lights.reduce(addLight, Color.defaultColor);
    }

    render(scene: Scene, image: BitmapImage) {
        for (let y = 0; y < image.height; y++) {
            for (let x = 0; x < image.width; x++) {
                let pt = scene.camera.getPoint(x,y, image.width, image.height);
                let ray = new Ray(scene.camera.pos, pt);
                let color = this.traceRay(ray, scene, 0);
                image.setColor(x, y, color.toDrawingColor())
            }
        }
    }
}

function defaultScene(): Scene {
    let shiny = new ShinySurface();
    let checkerboard = new CheckerboardSurface();
    return new Scene(
        [
            new Plane(new Vector(0.0, 1.0, 0.0), 0.0, checkerboard), 
            new Sphere(new Vector(0.0, 1.0, -0.25), 1.0, shiny), 
            new Sphere(new Vector(-1.0, 0.5, 1.5), 0.5, shiny)
        ],
        [
            new Light(new Vector(-2.0, 2.5, 0.0), new Color(0.49, 0.07, 0.07)), 
            new Light(new Vector(1.5, 2.5, 1.5), new Color(0.07, 0.07, 0.49)), 
            new Light(new Vector(1.5, 2.5, -1.5), new Color(0.07, 0.49, 0.071)), 
            new Light(new Vector(0.0, 3.5, 0.0), new Color(0.21, 0.21, 0.35))
        ],
        new Camera(new Vector(3.0, 2.0, 4.0), new Vector(-1.0, 0.5, 0.0)),
    );
}


class Encoding {
    // Note: Buffer api could be used insed of 
    // https://nodejs.org/api/buffer.html
    static DWORD(n: number) {
        //Unsigned 32 bit integer
        let b0 = (n >> 0)  & 0x000000FF;
        let b1 = (n >> 8)  & 0x000000FF;
        let b2 = (n >> 16) & 0x000000FF;
        let b3 = (n >> 24) & 0x000000FF;
        return [b0,b1,b2,b3];
    }
    
    static LONG(n: number) {
        //Signed 32 bit integer (since we use zeros this will work i hope)
        return Encoding.DWORD(n);
    }

    static WORD(n: number) {
        //Unsigned 16 bit integer
        let b0 = n & 0x000000FF;
        let b1 = (n >> 8) & 0x000000FF;
        return [b0, b1];
    }
}

class BITMAPINFOHEADER {
    public biSize: number = 0;         // DWORD
    public biWidth: number = 0;        // LONG
    public biHeight: number = 0;       // LONG
    public biPlanes: number = 0;       // WORD
    public biBitCount: number = 0;     // WORD
    public biCompression: number = 0;  // DWORD
    public biSizeImage: number = 0;    // DWORD
    public biXPelsPerMeter: number = 0;// LONG
    public biYPelsPerMeter: number = 0;// LONG
    public biClrUsed: number = 0;      // DWORD
    public biClrImportant: number = 0; // DWORD

    public constructor(w:number, h:number) {
        this.biSize = 40;
        this.biWidth = w;
        this.biHeight = -h;
        this.biPlanes = 1;
        this.biBitCount = 32;
        this.biSizeImage = w * h * 4;
    }

    public getBytes(): Uint8Array {
        let buffer = new Uint8Array(40);
        let bytes = [
            ...Encoding.DWORD(this.biSize),
            ...Encoding.LONG(this.biWidth), 
            ...Encoding.LONG(this.biHeight),
            ...Encoding.WORD(this.biPlanes),
            ...Encoding.WORD(this.biBitCount),
            ...Encoding.DWORD(this.biCompression),
            ...Encoding.DWORD(this.biSizeImage),
            ...Encoding.LONG(this.biXPelsPerMeter),
            ...Encoding.LONG(this.biYPelsPerMeter),
            ...Encoding.DWORD(this.biClrUsed),
            ...Encoding.DWORD(this.biClrImportant),
        ]
        buffer.set(bytes , 0);
        return buffer;
    }
}

class BITMAPFILEHEADER {
    private bfType: number = 0;    // WORD
    public bfSize: number = 0;     // DWORD
    public bfReserved: number = 0; // DWORD
    public bfOffBits: number = 0;  // DWORD

    constructor(imageSize: number) {
        this.bfType = 0x4D42;
        this.bfOffBits = 54;
        this.bfSize = this.bfOffBits + imageSize;
    }

    public getBytes(): Uint8Array {
        let bytes = [
            ...Encoding.WORD(this.bfType), 
            ...Encoding.DWORD(this.bfSize),
            ...Encoding.DWORD(this.bfReserved), 
            ...Encoding.DWORD(this.bfOffBits),
        ]
        let buffer = new Uint8Array(14);
        buffer.set(bytes, 0);
        return buffer;
    }
}

class BitmapImage {
    public data: Uint8Array;
    constructor(public readonly width: number, public readonly height: number) {
        this.data = new Uint8Array(width*height*4);
    }

    public setColor(x: number, y: number, color: Color): void {
        let index = (y * this.width  + x)*4;
        this.data[index + 0] = color.b;
        this.data[index + 1] = color.g;
        this.data[index + 2] = color.r;
        this.data[index + 3] = 255;
    }

    public saveSync(fileName: string): void {
        let buffer = new Uint8Array(54+ this.data.length);

        let infoHeader = new BITMAPINFOHEADER(this.width, this.height);
        let fileHeader = new BITMAPFILEHEADER(this.data.length);

        let infoHeaderBytes = infoHeader.getBytes();
        let fileHeaderBytes = fileHeader.getBytes();

        buffer.set(fileHeaderBytes, 0);
        buffer.set(infoHeaderBytes, fileHeaderBytes.length);
        buffer.set(this.data, 54);
       
        fs.writeFileSync(fileName, buffer);
    }
}

(function() {
    const start = performance.now()
    const image = new BitmapImage(500,500);
    let rayTracer = new RayTracer();
    rayTracer.render(defaultScene(), image);
    image.saveSync("typescript-ray.bmp")
    const time = Math.round(performance.now() - start);      
    console.log(`Completed in ${time} ms`)
})();
