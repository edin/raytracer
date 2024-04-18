--
-- Raytracer implementation in Ada
-- by John Perry (github: johnperry-math)
-- 2021
--
-- specification for Colors, both RGB ("Color_Type")
-- and RGBA ("Transparent_Color_Type")
--

-- local packages

with RayTracing_Constants; use RayTracing_Constants;

-- @summary
-- specification for Colors, both RGB ("Color_Type")
-- and RGBA ("Transparent_Color_Type")
package Colors is

   type Color_Type is record
      Blue, Green, Red: Float15;
   end record;
   -- RGB channels only; for transparency channel see Color_With_Transparency

   White:         constant Color_Type := ( 1.0, 1.0, 1.0 );
   Grey:          constant Color_Type := ( 0.5, 0.5, 0.5 );
   Black:         constant Color_Type := ( 0.0, 0.0, 0.0 );
   Background:    constant Color_Type := Black;
   Default_Color: constant Color_Type := Black;

   type Color_With_Transparency_Type is record
      Blue, Green, Red, Alpha: UInt8;
   end record;
   -- R, G, B, and Alpha (transparency) channels

   function Create_Color( Red, Green, Blue: Float15 ) return Color_Type;

   function Scale( Color: Color_Type; K: Float15 ) return Color_Type;
   -- scales Color by a factor of K, returns result
   pragma Inline_Always(Scale);

   procedure Scale_Self( Color: in out Color_Type; K: Float15 );
   -- scales Color by a factor of K, modifies self
   pragma Inline_Always(Scale_Self);

   function "*"(First, Second: Color_Type) return Color_Type;
   -- componentwise product of First and Second, returns result
   pragma Inline_Always("*");

   procedure Color_Multiply_Self(First: in out Color_Type; Second: Color_Type);
   pragma Inline_Always(Color_Multiply_Self);

   function "+"(First, Second: Color_Type) return Color_Type;
   -- returns sum of First and Second
   pragma Inline_Always("+");

   function Legalize(C: Float15) return UInt8;
   -- modifies C, expected in the range 0.0 .. 1.0, to the range 0 .. 255,
   -- with values less than 0.0 converted to 0, and values greater than 1.0
   -- converted to 255
   pragma Inline_Always(Legalize);

   function To_Drawing_Color(C: Color_Type) return Color_With_Transparency_Type;
   -- converts RGB to RGBA with A = 255
   pragma Inline_Always(To_Drawing_Color);

end Colors;
