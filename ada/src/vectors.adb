--
-- Raytracer implementation in Ada
-- by John Perry (github: johnperry-math)
-- 2021
--
-- implementation for 3d Vectors, which describe positions, directions, etc.
--

pragma Ada_2020;

-- Ada packages

with Ada.Numerics.Generic_Elementary_Functions;

-- local packages

with RayTracing_Constants; use RayTracing_Constants;

package body Vectors is

   -------------------------------------------------------------------------
   -- the next package, and the subsequent subprogram,
   -- make the square root function available

   package Float_Numerics is new Ada.Numerics.Generic_Elementary_Functions
         (
          Float_Type => Float15
         );

   function Sqrt(X: Float15) return Float15 renames Float_Numerics.Sqrt;

   -------------------------------------------------------------------------

   function Create_Vector(X, Y, Z: Float15) return Vector is
         ( ( X => X, Y => Y, Z => Z ) );

   function Cross_Product(First, Second: Vector) return Vector is
         (
               Create_Vector(
                                  First.Y * Second.Z - First.Z * Second.Y,
                                  First.Z * Second.X - First.X * Second.Z,
                                  First.X * Second.Y - First.Y * Second.X
                                 )
              );

   function Length(V: Vector) return Float15 is
         ( Sqrt( V.X * V.X + V.Y * V.Y + V.Z * V.Z ) );

   function Scale(V: Vector; K: Float15) return Vector is
         ( ( K * V.X, K * V.Y, K * V.Z ) );

   procedure Self_Scale(V: in out Vector; K: Float15) is
   begin
      V.X := @ * K;
      V.Y := @ * K;
      V.Z := @ * K;
   end Self_Scale;

   function Normal(V: Vector) return Vector is
      Mag: Float15 := Length(V);
   begin
      return Scale(
                   V,
                   (
                    if Mag = 0.0 then Far_Away
                    else 1.0 / Mag
                   )
                  );
   end Normal;

   procedure Self_Norm(V: in out Vector) is
      Mag: Float15 := Length(V);
   begin
      Self_Scale( V, ( if Mag = 0.0 then Far_Away else 1.0 / Mag ) );
   end Self_Norm;


   function Dot_Product(First, Second: Vector) return Float15 is
         ( First.X * Second.X + First.Y * Second.Y + First.Z * Second.Z );

   function "+"(First, Second: Vector) return Vector is
         ( Create_Vector( First.X + Second.X, First.Y + Second.Y, First.Z + Second.Z ) );

   function "-"(First, Second: Vector) return Vector is
         ( Create_Vector( First.X - Second.X, First.Y - Second.Y, First.Z - Second.Z ) );

end Vectors;
