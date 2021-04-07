--
-- Raytracer implementation in Ada
-- by John Perry (github: johnperry-math)
-- 2021
--
-- specification for 3d Vectors, which describe positions, directions, etc.
--

-- local packages

with RayTracing_Constants; use RayTracing_Constants;

-- @summary 3d Vectors, which describe positions, directions, etc.
package Vectors is

   type Vector is record
      X, Y, Z: Float15;
   end record;
   -- 3-dimensional vectors

   function Create_Vector(X, Y, Z: Float15) return Vector;
   -- sets the Vector in the way you'd think
   pragma Inline_Always(Create_Vector);

   function Cross_Product(First, Second: Vector) return Vector;
   -- returns the cross product of First and Second
   pragma Inline_Always(Cross_Product);

   function Length(V: Vector) return Float15;
   -- Euclidean length of V
   pragma Inline_Always(Length);

   function Scale(V: Vector; K: Float15) return Vector;
   -- scales V by a factor of K
   pragma Inline_Always(Scale);
   function "*"(V: Vector; K: Float15) return Vector renames Scale;
   -- scales V by a factor of K

   procedure Self_Scale(V: in out Vector; K: Float15);
   -- scales V by a factor of K and stores result in V
   pragma Inline_Always(Self_Scale);

   function Normal(V: Vector) return Vector;
   -- returns a normalized V
   pragma Inline_Always(Normal);
   function "abs"(V: Vector) return Vector renames Normal;

   procedure Self_Norm(V: in out Vector);
   -- normalizes V
   pragma Inline_Always(Self_Norm);

   function Dot_Product(First, Second: Vector) return Float15;
   -- returns the dot product of First and Second
   pragma Inline_Always(Dot_Product);
   function "*"(First, Second: Vector) return Float15 renames Dot_Product;

   function "+"(First, Second: Vector) return Vector;
   -- returns the sum of First and Second
   pragma Inline_Always("+");

   function "-"(First, Second: Vector) return Vector;
   -- returns the difference of First and Second
   pragma Inline_Always("-");

end Vectors;
