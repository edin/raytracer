--
-- Raytracer implementation in Ada
-- by John Perry (github: johnperry-math)
-- 2021
--
-- specification for Cameras, that view the scene
--

-- local packages

with Vectors; use Vectors;

-- @summary Cameras that view the scene
package Cameras is

   type Camera_Type is record
      Forward, Right, Up, Position: Vector;
   end record;

   function Create_Camera(Position, Target: Vector) return Camera_Type;
   -- creates a camera at Position that is looking at Target

end Cameras;
