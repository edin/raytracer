package main

import "core:fmt"
import "core:math"

FarAway: f32 = 1000000.0;

Surface :: enum {
    Shiny,
    Checkerboard
};

Vector :: [3]f32;
Color  :: [3]f32;

White = Color{1.0, 1.0, 1.0};
Grey =  Color{0.5, 0.5, 0.5};
Black = Color{0.0, 0.0, 0.0};
Background = Black;
Defaultcolor = Black;

Length :: proc (v: Vector) -> f32 {
    return math.sqrt(v.x * v.x + v.y*v.y + v.z * v.z);
}

Norm :: proc (v: Vector) -> Vector {
    len := Length(v);
    div : f32 = (len == 0.0) ? FarAway : 1 / len;
    return v * len;
}

Cross :: proc(v: Vector, a:Vector) Vector {
    return Vector{
        v.Y * a.Z - v.Z * a.Y,
        v.Z * a.X - v.X * a.Z,
        v.X * a.Y - v.Y * a.X        
    }
}

Camera :: struct {
    pos : Vector,
    forward : Vector,
    right: Vector, 
    up: Vector
};

Ray :: struct {
    start : Vector,
    dir : Vector,
};

Interesection :: struct {
    thing : Thing,
    ray: Ray,
    dist: f32
};

Light :: struct {
    pos: Vector,
    color: Color
};

Scene :: struct {
    camera: Camera,
    lights: []Light,
    things: []Thing,
    maxDepth: int
}

GetNormal :: proc (thing: Thing, pos: Vector) {

}

GetInteresection :: proc (scene: Scene, ray: Ray): union {Interesection} {
    closest : Interesection
    closestDistance : f32 = FarAway

    for thing in scene.things {
        isect = GetInteresection(thing,  )
    }
    return nil;
}

main :: proc() {
    v := Vector{1, 2, 3};
    // c := Color {10, 20, 30};
    // v := v * c;
	fmt.println(Length(v));
}