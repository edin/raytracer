--
-- Raytracer implementation in Ada
-- by John Perry (github: johnperry-math)
-- 2021
--
-- specification for Rays
--

-- local packages

with Vectors; use Vectors;

-- @summary a Ray has a starting point and a direction
package Rays is


   type Ray_Type is record
      Start, Dir: Vector;
   end record;

   function Create_Ray(Start, Dir: Vector) return Ray_Type;
   pragma Inline_Always(Create_Ray);

end Rays;
