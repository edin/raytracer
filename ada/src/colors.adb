--
-- Raytracer implementation in Ada
-- by John Perry (github: johnperry-math)
-- 2021
--
-- implementation for Colors, both RGB ("Color_Type")
-- and RGBA ("Transparent_Color_Type")
--

package body Colors is

   function Create_Color(Red, Green, Blue: Float15) return Color_Type is
         ( Red => Red, Green => Green, Blue => Blue );

   function Scale( Color: Color_Type; K: Float15 ) return Color_Type is
         (
               Red => K * Color.Red,
               Green => K * Color.Green,
               Blue => K * Color.Blue
              );

   procedure Scale_Self( Color: in out Color_Type; K: Float15 ) is
   begin
      Color.Red := K * Color.Red;
      Color.Green := K * Color.Green;
      Color.Blue := K * Color.Blue;
   end Scale_Self;

   function "*"(First, Second: Color_Type) return Color_Type is
         (
               Red   => First.Red * Second.Red,
               Green => First.Green * Second.Green,
               Blue  => First.Blue * Second.Blue
              );

   procedure Color_Multiply_Self(First: in out Color_Type; Second: Color_Type)
   is
   begin
      First.Red := First.Red * Second.Red;
      First.Green := First.Green * Second.Green;
      First.Blue := First.Blue * Second.Blue;
   end Color_Multiply_Self;

   function "+"(First, Second: Color_Type) return Color_Type is
         (
               Red   => First.Red + Second.Red,
               Green => First.Green + Second.Green,
               Blue  => First.Blue + Second.Blue
              );

   function Legalize(C: Float15) return UInt8 is
         ( (
                 if C < 0.0 then 0
                 elsif C  > 1.0 then 255
                 else UInt8(C * 255.0)
                ) );

   function To_Drawing_Color(C: Color_Type) return Color_With_Transparency_Type
   is
         (
               Red   => Legalize(C.Red),
               Green => Legalize(C.Green),
               Blue  => Legalize(C.Blue),
               Alpha => 255
              );

end Colors;
