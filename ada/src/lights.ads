with Colors; use Colors;
with Vectors; use Vectors;

-- @summary Lights that shine onto a Scene
package Lights is

   type Light_Type is private;
   -- Light_Type has a position and a color
   type Light_Array is array( Positive range <> ) of Light_Type;

   function Create_Light(Position: Vector; Color: Color_Type) return Light_Type;

   function Position_Of(Light: Light_Type) return Vector;
   -- the position vector of this Light
   pragma Inline_Always(Position_Of);

   function Color_Of(Light: Light_Type) return Color_Type;
   -- the RGB color of this Light
   pragma Inline_Always(Color_Of);

private

   type Light_Type is record
      Position: Vector;
      Color: Color_Type;
   end record;

end Lights;
