--
-- Raytracer implementation in Ada
-- by John Perry (github: johnperry-math)
-- 2021
--
-- specification for Objects that may appear in the scene
--

-- local packages

with Bitmap;  use Bitmap;
with Cameras; use Cameras;
with Colors;  use Colors;
with Lights;  use Lights;
with Rays;    use Rays;
with Vectors; use Vectors;

with RayTracing_Constants; use RayTracing_Constants;

-- @summary
-- Objects that can appear in a Scene.
-- @description
-- Objects that can appear in the scene at this time are Spheres and Planes.
-- They may have have either a Shiny or a Checkerboard surface.
--
package Objects is

   type Object_Type is ( Sphere, Plane );

   type Surface_Type is ( Shiny, Checkerboard );

   type Surface_Properties is record
      Diffuse, Specular: Color_Type; -- what color is diffused, which one shines
      Reflect, Roughness: Float15;-- strength of reflection (0-1), how rough
   end record;

   procedure Get_Surface_Properties(
                                    Surface: Surface_Type;
                                    Position: Vector;
                                    Properties: out Surface_Properties
                                   );
   -- returns the properties of Surface from position Pos
   pragma Inline_Always(Get_Surface_Properties);

   type Thing_Type(Kind: Object_Type := Plane) is private;
   -- Thing_Type contains information on an object in the scene,
   -- which defaults to Plane
   type Thing_Array is array( Positive range <> ) of Thing_Type;

   function Surface_Of(Thing: Thing_Type) return Surface_Type;
   pragma Inline_Always(Surface_Of);

   type Intersection_Type is record
      Thing: Thing_Type;          -- the Thing intersected
      Ray:   Ray_Type;            -- the Ray intersecting
      Dist:  Float15 := Far_Away; -- distance between thing and Ray's source
   end record; -- information on an Intersection between light and object

   No_Intersection: constant Intersection_Type;
   -- used when a ray of light does not intersect an object

   procedure Create_Plane(
                          Thing: out Thing_Type;
                          Position: Vector;
                          Offset: Float15;
                          Surface: Surface_Type
                         );

   procedure Create_Sphere(
                           Thing: out Thing_Type;
                           Center: Vector;
                           Radius: Float15;
                           Surface: Surface_Type
                          );

   function Intersections(Ray: Ray_Type; Things: Thing_Array)
                          return Intersection_Type;
   -- description of Ray's intersection with Things
   pragma Inline_Always(Intersections);

   function Object_Normal(Obj: Thing_Type; Position: Vector) return Vector;
   -- returns the normal vector of Obj's position and Pos
   pragma Inline_Always(Object_Normal);

private

   type Thing_Type(Kind: Object_Type := Plane) is record
      Surface: Surface_Type := Shiny;
      case Kind is
         when Sphere =>
            Radius2: Float15 := 0.0;
            Center: Vector;
         when Plane =>
            Offset: Float15 := 0.0;
            Normal: Vector;
      end case;
   end record;

   No_Intersection: constant Intersection_Type := ( others => <> );

end Objects;
