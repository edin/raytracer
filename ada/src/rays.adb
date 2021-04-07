--
-- Raytracer implementation in Ada
-- by John Perry (github: johnperry-math)
-- 2021
--
-- implementation for Rays
--

package body Rays is

   function Create_Ray(start, dir: Vector) return Ray_Type is
      ( ( start => start, dir => dir ) );

end Rays;
