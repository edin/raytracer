--
-- Raytracer implementation in Ada
-- by John Perry (github: johnperry-math)
-- 2021
--
-- implementation for Cameras, that view the scene
--

-- local packages

with RayTracing_Constants; use RayTracing_Constants;

package body Cameras is

   function Create_Camera(Position, Target: Vector) return Camera_Type is

      Result: Camera_Type;

      Down: Vector := Create_Vector(0.0, -1.0, 0.0);
      Forward: Vector := Target - Position;

      -- computed later
      Right_Norm, Up_Norm: Vector;

   begin

      Result.Position := Position;
      Result.Forward := Normal(Forward);
      Result.Right := Cross_Product(Result.Forward, Down);
      Result.Up := Cross_Product(Result.Forward, Result.Right);

      Right_Norm := Normal(Result.Right);
      Up_Norm := Normal(Result.Up);

      Result.Right := Right_Norm * 1.5;
      Result.Up := Up_Norm * 1.5;
      return Result;

   end Create_Camera;

end Cameras;
