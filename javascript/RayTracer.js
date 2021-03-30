const fs = require('fs');
const { performance } = require('perf_hooks');

/// Vector math

function dotProduct(a, b) {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

function crossProduct(a, b) {
    return new Vector(
        a.y * b.z - a.z * b.y, 
        a.z * b.x - a.x * b.z, 
        a.x * b.y - a.y * b.x
    );
}

class Vector {
    constructor(x, y, z) {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    mag() {
        return Math.sqrt(this.x * this.x + this.y * this.y + this.z * this.z);
    }

    scale(k) {
        return new Vector(k * this.x, k * this.y, k * this.z);
    }

    scaleInPlace(k) {
        this.x *= k;
        this.y *= k;
        this.z *= k;
        return this;
    }

    norm() {
        const div = 1 / this.mag();
        return new Vector(this.x * div, this.y * div, this.z * div);
    }

    normInPlace() {
        const div = 1 / this.mag();
        this.x *= div;
        this.y *= div;
        this.z *= div;
        return this;
    }
}

class Color {
    constructor(r, g, b) {
        this.r = r;
        this.g = g;
        this.b = b;
    }
    
    clone() {
        return new Color(this.r, this.g, this.b);
    }

    static white = new Color(1.0, 1.0, 1.0);
    static grey = new Color(0.5, 0.5, 0.5);
    static black = new Color(0.0, 0.0, 0.0);
    static background = Color.black;
    static defaultColor = Color.black;
}

class Camera {
    constructor(pos, lookAt) {
        const down = new Vector(0.0, -1.0, 0.0);
        this.pos = pos;
        this.forward = new Vector(
            lookAt.x - pos.x,
            lookAt.y - pos.y,
            lookAt.z - pos.z
        ).normInPlace();
        this.right = crossProduct(this.forward, down).normInPlace();
        this.up = crossProduct(this.forward, this.right).normInPlace();
    }
}

class Ray {
    constructor(start, dir){
        this.start = start;
        this.dir = dir;
    }
}

class Intersection {
    constructor(thing, ray, dist) {
        this.thing = thing;
        this.ray = ray;
        this.dist = dist;
    }
}

class Light {
    constructor(pos, color) {
        this.pos = pos;
        this.color = color;
    }
}

class Scene {
    constructor(things, lights, camera) {
        this.things = things;
        this.lights = lights;
        this.camera = camera;
    }
}

class Sphere {
    constructor(center, radius, surface) {
        this.center = center;
        this.radius = radius;
        this.radius2 = radius * radius;
        this.surface = surface;
    }

    normal(pos) {
        return new Vector(
            pos.x - this.center.x,
            pos.y - this.center.y,
            pos.z - this.center.z
        ).norm();
    }

    intersect(ray) {
        const eo = new Vector(
            this.center.x - ray.start.x,
            this.center.y - ray.start.y,
            this.center.z - ray.start.z
        );
        const v = dotProduct(eo, ray.dir);
        if (v >= 0) {
            const disc = this.radius2 - (dotProduct(eo, eo) - v * v);
            if (disc >= 0) {
                const dist = v - Math.sqrt(disc);
                return new Intersection(this, ray, dist);
            }
        }
        return null;
    }
}

class Plane {
    constructor(norm, offset, surface) {
        this.norm = norm;
        this.offset = offset;
        this.surface = surface;
    }

    normal(pos) {
        return this.norm;
    }

    intersect(ray) {
        const denom = dotProduct(this.norm, ray.dir);
        if (denom <= 0) {
            const dist = (dotProduct(this.norm, ray.start) + this.offset) / (-denom);
            return new Intersection(this, ray, dist);
        }
        return null;
    }
}

class ShinySurface {
    constructor() {
        this.roughness = 250;
    }
    diffuse(pos) {
        return Color.white;
    }
    specular(pos) {
        return Color.grey;
    }
    reflect(pos) {
        return 0.7;
    }
}

class CheckerboardSurface {
    constructor() {
        this.roughness = 150;
    }

    condition(pos) {
        return (Math.floor(pos.z) + Math.floor(pos.x)) % 2 !== 0;
    } 

    diffuse(pos) {
        return this.condition(pos) ? Color.white : Color.black;
    }

    specular(pos) {
        return Color.white;
    }
    
    reflect(pos) {
        return this.condition(pos) ? 0.1 : 0.7;
    }
}

/// RayTracer

function renderScene(scene, image, maxDepth) {
    const camera = scene.camera;
    const h = image.height;
    const w = image.width;
    const ryIncrement = 0.75 / h;
    const rxIncrement = 0.75 / w;
    for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
            const ry = -0.375 + y * ryIncrement;
            const rx = -0.375 + x * rxIncrement;
            const pt = new Vector(
                camera.forward.x + camera.right.x * rx + camera.up.x * ry,
                camera.forward.y + camera.right.y * rx + camera.up.y * ry,
                camera.forward.z + camera.right.z * rx + camera.up.z * ry
            ).normInPlace();

            const ray = new Ray(camera.pos, pt);
            const color = shadeRay(ray, scene, 0, maxDepth);
            image.setColor(x, y, color);
        }
    }
}

function shadeRay(ray, scene, depth, maxDepth) {
    const intersect = intersectRay(ray, scene);
    if (intersect) {
        return shadeIntersection(intersect, scene, depth, maxDepth);
    } else {
        return Color.background;
    }
}

function intersectRay(ray, scene) {
    const things = scene.things;
    let closest = null;
    for (let i = 0; i < things.length; ++i) {
        const inter = things[i].intersect(ray);
        if (inter !== null) {
            if (closest == null || closest.dist > inter.dist) {
                closest = inter;
            }
        }
    }
    return closest;
}

function shadeIntersection(intersect, scene, depth, maxDepth) {
    const rayStart = intersect.ray.start;
    const rayDir = intersect.ray.dir;
    const pos = new Vector(
        rayStart.x + rayDir.x * intersect.dist,
        rayStart.y + rayDir.y * intersect.dist,
        rayStart.z + rayDir.z * intersect.dist
    );
    
    const thing = intersect.thing;
    const surfNormal = thing.normal(pos);
    const surfRoughness = thing.surface.roughness;
    const surfDiffuse = thing.surface.diffuse(pos);
    const surfSpecular = thing.surface.specular(pos);

    const reflection = dotProduct(surfNormal, rayDir) * 2;
    const reflectDir = new Vector(
        rayDir.x - surfNormal.x * reflection,
        rayDir.y - surfNormal.y * reflection,
        rayDir.z - surfNormal.z * reflection
    );
    const reflectDirNorm = reflectDir.norm();

    const lights = scene.lights;
    const color = Color.background.clone();
    for (let i = 0; i < lights.length; ++i) {
        const lightDistance = new Vector(
            lights[i].pos.x - pos.x,
            lights[i].pos.y - pos.y,
            lights[i].pos.z - pos.z
        );
        const lightDirection = lightDistance.norm();
        const lightIntersect = intersectRay(new Ray(pos, lightDirection), scene);
        if (!lightIntersect || lightIntersect.dist > lightDistance.mag()) {
            const illum = dotProduct(lightDirection, surfNormal);
            if (illum > 0) {
                color.r += illum * lights[i].color.r * surfDiffuse.r;
                color.g += illum * lights[i].color.g * surfDiffuse.g;
                color.b += illum * lights[i].color.b * surfDiffuse.b;
            }
            const specular = dotProduct(lightDirection, reflectDirNorm);
            if (specular > 0) {
                const pow = Math.pow(specular, surfRoughness); // TODO: optimize pow
                color.r += pow * lights[i].color.r * surfSpecular.r;
                color.g += pow * lights[i].color.g * surfSpecular.g;
                color.b += pow * lights[i].color.b * surfSpecular.b;
            }
        }
    }

    if (depth < maxDepth) {
        const reflectedColor = shadeRay(new Ray(pos, reflectDir), scene, depth + 1, maxDepth)
        const reflect = thing.surface.reflect(pos);
        color.r += reflectedColor.r * reflect;
        color.g += reflectedColor.g * reflect
        color.b += reflectedColor.b * reflect;
    } else {
        const reflectedColor = Color.grey;
        color.r += reflectedColor.r;
        color.g += reflectedColor.g;
        color.b += reflectedColor.b;
    }
    return color;
}

class BitmapImage {
    constructor(width, height) {
        this.width = width;
        this.height = height;

        // allocate buffer
        const headerSize = 54;
        const imageSize = width * height * 4;
        const buffer = Buffer.alloc(headerSize + imageSize);
        
        // BITMAPFILEHEADER
        buffer.writeUInt16LE(0x4D42, 0);  // bitmap file type
        buffer.writeUInt32LE(headerSize + imageSize, 2);
        buffer.writeUInt32LE(0, 6); // reserved
        buffer.writeUInt32LE(headerSize, 10);

        // BITMAPINFOHEADER
        buffer.writeUInt32LE(40, 14); // header size
        buffer.writeUInt32LE(width, 18);
        buffer.writeUInt32LE(height, 22);
        buffer.writeUInt16LE(1, 26); // planes
        buffer.writeUInt16LE(32, 28); // bit count
        buffer.writeUInt32LE(0, 30); // compression
        buffer.writeUInt32LE(imageSize, 34);
        buffer.writeUInt32LE(0, 38); // x pixels per meter
        buffer.writeUInt32LE(0, 42); // y pixels per meter
        buffer.writeUInt32LE(0, 46); // clr used
        buffer.writeUInt32LE(0, 50); // clr important

        // save buffer
        this.headerSize = headerSize;
        this.buffer = buffer;
    }

    setColor(x, y, color) {
        const convert = (value) => {
            // NOTE: channels cannot go negative, so don't need to check for that
            value = Math.floor(value * 255);
            return value <= 255 ? value : 255;
        };
        const offset = (y * this.width + x) * 4 + this.headerSize;
        this.buffer.writeUInt8(convert(color.b), offset);
        this.buffer.writeUInt8(convert(color.g), offset + 1);
        this.buffer.writeUInt8(convert(color.r), offset + 2);
        this.buffer.writeUInt8(255, offset + 3);
    }

    saveSync(fileName) {
        fs.writeFileSync(fileName, this.buffer);
    }
}

(function() {
    const start = performance.now();

    // create the scene
    const shiny = new ShinySurface();
    const checkerboard = new CheckerboardSurface();
    const scene = new Scene(
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

    // render the scene
    const image = new BitmapImage(500, 500);
    renderScene(scene, image, 5);

    // log the runtime and save the render
    const time = performance.now() - start;      
    console.log(`Completed in ${time.toFixed(0)} ms`);
    image.saveSync('javascript-raytracer.bmp');
})();
