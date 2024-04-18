--
-- Raytracer implementation in Ada
-- by John Perry (github: johnperry-math)
-- 2021
--
-- implementation of Scene type and the ray tracer
--

pragma Ada_2022;

-- Ada packages

with Ada.Numerics.Generic_Elementary_Functions; -- needed for sqrt function

-- local packages

with Colors;  use Colors;
with Objects; use Objects;
with Rays;    use Rays;
with Vectors; use Vectors;

package body RayTracer is

   -------------------------------------------------------------------------
   -- the next package, and the subsequent subprogram,
   -- make the square root function available

   package Float_Numerics is new Ada.Numerics.Generic_Elementary_Functions
     (
      Float_Type => Float15
     );

   function "**" (Left, Right : Float15) return Float15
                  renames Float_Numerics."**";

   -------------------------------------------------------------------------

   function Things(Scene: Scene_Type) return Thing_Array is
     ( Scene.Things );

   function Get_Natural_Color(
                              Sp: Surface_Properties;
                              Position, Normal_Vector, Reflected_Direction: Vector;
                              Scene: Scene_Type
                             ) return Color_Type
   -- returns the "natural" color of an object with given surface properties
   is
      Result_Color: Color_Type := Black;
   begin

      for I in 1 .. Scene.Light_Count loop

         declare

            Light renames Scene.Lights(I);
            L_Dis: constant Vector := Position_Of(Light) - Position;
            L_Ivec: constant Vector := Normal(L_Dis);
            Ray: constant Ray_Type := ( Position, L_Ivec );

            Neat_Isect: constant Intersection_Type
              := Intersections(Ray, Scene.Things);
            Is_In_Shadow: constant Boolean := Neat_Isect.Dist <= Length(L_Dis);

         begin

            if not Is_In_Shadow then

               declare

                  Illum: constant Float15 := L_Ivec * Normal_Vector;
                  Specular: constant Float15 := L_Ivec * Reflected_Direction;
                  L_Color: Color_Type
                    := (
                        if Illum > 0.0 then Scale(Color_Of(Light), Illum)
                        else Default_Color
                       );
                  S_Color: Color_Type
                    := (
                        if Specular > 0.0
                        then Scale(Color_Of(Light), Specular**Sp.Roughness)
                        else Default_Color
                       );

               begin

                  Color_Multiply_Self(L_Color, Sp.Diffuse);
                  Color_Multiply_Self(S_Color, Sp.Specular);
                  Result_Color := Result_Color + L_Color + S_Color;

               end;

            end if;

         end;

      end loop;

      return Result_Color;

   end Get_Natural_Color;

   function Shade(Isect: Intersection_Type; Scene: Scene_Type; Depth: Integer)
                  return Color_Type;

   function Trace_Ray(Ray: Ray_Type; Scene: Scene_Type; Depth: Integer)
                      return Color_Type
   -- traces Ray through Scene up to Depth reflections
   is
      Intersect: constant Intersection_Type := Intersections(Ray, Scene.Things);
   begin
      return (
              if Intersect.Dist < Far_Away
              then Shade(Intersect, Scene, Depth)
              else Background
             );
   end Trace_Ray;
   pragma Inline_Always(Trace_Ray);

   function Get_Reflection_Color(
                                 Properties: Surface_Properties;
                                 Position, Normal_Vector, Reflected_Direction: Vector;
                                 Scene: Scene_Type;
                                 Depth: Integer
                                )
                                 return Color_Type
   -- determines the color reflected off an object with the given Properties,
   -- with up to Depth reflections
   is
      Ray: constant Ray_Type := Create_Ray(Position, Reflected_Direction);
      Col: Color_Type := Trace_Ray(Ray, Scene, Depth + 1);
   begin
      return Scale(Col, Properties.Reflect);
   end Get_Reflection_Color;
   pragma Inline_Always(Get_Reflection_Color);

   function Shade(Isect: Intersection_Type; Scene: Scene_Type; Depth: Integer)
                  return Color_Type
   -- determine the shade of the object at Isect
   is

      D renames Isect.Ray.Dir;
      Scaled: constant Vector := D * Isect.Dist;
      Position: constant Vector := Scaled + Isect.Ray.Start;
      Normal_Vector: constant Vector
        := Object_Normal(Isect.Thing, Position);
      Normal_Dot_D: constant Float15 := Normal_Vector * D;
      Normal_Scaled: constant Vector := Normal_Vector * ( Normal_Dot_D * 2.0 );
      Reflect_Dir: constant Vector := Normal(D - Normal_Scaled);

      Natural_Color, Reflected_Color: Color_Type;
      Properties: Surface_Properties;

   begin

      -- get the properties of the surface at the intersection;
      -- determine the natural and reflected colors,
      -- then return their sum

      Get_Surface_Properties(
                             Surface_Of(Isect.Thing),
                             Position,
                             Properties
                            );
      Natural_Color
        := Get_Natural_Color(
                             Properties,
                             Position,
                             Normal_Vector,
                             Reflect_Dir,
                             Scene
                            );
      Reflected_Color
        := (
            if Depth >= Scene.Max_Depth then Grey
            else Get_Reflection_Color(
              Properties, Position, Normal_Vector, Reflect_Dir, Scene, Depth
             )
           );
      return Background + Natural_Color + Reflected_Color;
   end Shade;

   procedure Create_Scene(
                          Scene: out Scene_Type;
                          Things: Thing_Array;
                          Lights: Light_Array;
                          Camera: Camera_Type;
                          Depth: Natural
                         )
   is
   begin
      Scene.Things := Things;
      Scene.Lights := Lights;
      Scene.Camera := Camera;
      Scene.Max_Depth := Depth;
   end Create_Scene;

   function Get_Point(X, Y: Int32; Cam: Camera_Type; Width, Height: Int32)
                      return Vector
   -- gets the 3d point seen by a Camera at position (x,y) in an image
   -- of given width and height
   is

      Fwidth: constant Float15 := Float15(Width);
      Fheight: constant Float15 := Float15(Height);
      Recenter_X: constant Float15
        := ( Float15(X) - Fwidth / 2.0 ) / 2.0 / Fwidth;
      Recenter_Y: constant Float15
        := - ( Float15(Y) - Fheight / 2.0 ) / 2.0 / Fheight;
      Vx: constant Vector := Cam.Right * Recenter_X;
      Vy: constant Vector := Cam.Up * Recenter_Y;
      V: constant Vector := Vx + Vy;
      Z: Vector := Cam.Forward + V;

   begin
      return Normal(Z);
   end Get_Point;

   procedure Render_Scene(
                          Scene: Scene_Type;
                          Bitmap: out Bitmap_Data;
                          Width, Height: Int32
                         )
   is
      Ray: Ray_Type;
      Position: Int32;
   begin

      Ray.Start := Scene.Camera.Position;

      for Y in 0 .. Height - 1 loop

         Position := Y * Height;

         for X in 0 .. Width - 1 loop

            Ray.Dir := Get_Point(X, Y, Scene.Camera, Width, Height);
            Bitmap(Integer( Position + X + 1 ))
              := To_Drawing_Color(Trace_Ray(Ray, Scene, 0));
         end loop;

      end loop;

   end Render_Scene;

end RayTracer;
