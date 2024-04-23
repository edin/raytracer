--
-- Raytracer implementation in Ada
-- by John Perry (github: johnperry-math)
-- 2021
--
-- implementation for Objects that may appear in the scene
--

pragma Ada_2022;

-- Ada packages

with Ada.Numerics.Generic_Elementary_Functions;

-- local packages

with RayTracing_Constants; use RayTracing_Constants;
with RayTracer;

package body Objects is

   -------------------------------------------------------------------------
   -- the next package, and the following two subprograms,
   -- make the square root and floating-point exponentiation functions available

   package Float_Numerics is new Ada.Numerics.Generic_Elementary_Functions
         (
          Float_Type => Float15
         );

   function Sqrt(X: Float15) return Float15 renames Float_Numerics.Sqrt;

   function "**" (Left, Right : Float15) return Float15
                  renames Float_Numerics."**";

   -------------------------------------------------------------------------

   function Surface_Of(Thing: Thing_Type) return Surface_Type
   is ( Thing.Surface );

   procedure Get_Surface_Properties(
                                    Surface: Surface_Type;
                                    Position: Vector;
                                    Properties: out Surface_Properties
                                   )
   is
   begin

      case Surface is

         when Shiny =>

            Properties.Diffuse := White;
            Properties.Specular := Grey;
            Properties.Reflect := 0.7;
            Properties.Roughness := 250.0;

         when Checkerboard =>

            declare Val: constant Integer
                     := Integer( Float15'Floor(Position.Z)
                                 + Float15'Floor(Position.X) );
            begin

               if Val mod 2 /= 0 then
                  Properties.Reflect := 0.1;
                  Properties.Diffuse := White;
               else
                  Properties.Reflect := 0.7;
                  Properties.Diffuse := Black;
               end if;

               Properties.Specular := White;
               Properties.Roughness := 150.0;

            end;

      end case;

   end Get_Surface_Properties;

   function Object_Distance( Obj: Thing_Type; Ray: Ray_Type ) return Float15 is
   begin

      case Obj.Kind is

      when Sphere =>

         declare
            Eo: constant Vector := Obj.Center - Ray.Start;
            V: constant Float15 := Eo * Ray.Dir;
         begin

            if V > 0.0 then
               declare
                  Disc: constant Float15 := Obj.Radius2 - ( Eo * Eo - V * V );
               begin
                  if Disc > 0.0 then
                     return V - Sqrt(Disc);
                  end if;
               end;
            end if;

         end;

      when Plane =>

         declare
            Denom: constant Float15 := Obj.Normal * Ray.Dir;
         begin

            if Denom <= 0.0 then
               return ( Obj.Normal * Ray.Start + Obj.Offset ) / ( -Denom );
            end if;

         end;

      end case;

      return Far_Away;

   end Object_Distance;
   pragma Inline_Always(Object_Distance);

   function Intersections(Ray: Ray_Type; Things: Thing_Array)
                          return Intersection_Type
   is

      Closest: Float15 := Far_Away;         -- distance of closest object
      Which: Natural := 0;                  -- closest object in Things
      Dist: array(Things'Range) of Float15; -- distance to each object

   begin

      -- determine distance for each object
      for I in Things'Range loop
         Dist(I) := Object_Distance(Things(I), Ray);
         if Dist(I) < Closest then
            Which := I;
         end if;
      end loop;

      return (
              if Which = 0 then No_Intersection
              else (
                    Thing => Things(Which),
                    Ray   => Ray,
                    Dist  => Dist(Which)
                   )
             );

   end Intersections;

   function Object_Normal(Obj: Thing_Type; Position: Vector) return Vector is
         (
                     (
                           case Obj.Kind is
                              when Sphere => ( Normal(Position - Obj.Center ) ),
                              when Plane => ( Obj.Normal )
                          )
              );

   function Create_Intersection(
                                Thing: Thing_Type;
                                Ray: Ray_Type;
                                Dist: Float15
                               )
                                return Intersection_Type
   is ( ( Thing => Thing, Ray => Ray, Dist => Dist ) );
   pragma Inline_Always(Create_Intersection);

   procedure Create_Sphere(
                           Thing: out Thing_Type;
                           Center: Vector;
                           Radius: Float15;
                           Surface: Surface_Type
                          )
   is
   begin
      Thing := (
                Kind    => Sphere,
                Surface => Surface,
                Radius2 => Radius * Radius,
                Center  => Center
               );
   end Create_Sphere;

   procedure Create_Plane(
                          Thing: out Thing_Type;
                          Position: Vector;
                          Offset: Float15;
                          Surface: Surface_Type
                         )
   is
   begin
      Thing := (
                Kind    => Plane,
                Surface => Surface,
                Offset  => Offset,
                Normal  => Position
               );
   end Create_Plane;

end Objects;
