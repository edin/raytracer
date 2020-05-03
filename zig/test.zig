const std = @import("std");

const Surface = enum {
    ShinySurface,
    CheckerboardSurface,
};

const Vector = struct { x: f64, y: f64, z: f64 };

const Thing = union(enum) {
    Plane: struct {
        norm: Vector, offset: f64, surface: Surface
    },
    Sphere: struct {
        center: Vector, radius2: f64, surface: Surface
    },
};

pub fn main() !void {
    const stdout = std.io.getStdOut().outStream();

    var pt = Thing{
        .Plane = .{
            .norm = Vector{ .x = 0, .y = 0, .z = 0 },
            .offset = 0.0,
            .surface = Surface.ShinySurface,
        },
    };
    try stdout.print("Hello, {}!\n", .{pt});
}
