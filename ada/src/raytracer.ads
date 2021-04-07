--
-- Raytracer implementation in Ada
-- by John Perry (github: johnperry-math)
-- 2021
--
-- specification of Scene type and the ray tracer
--

-- local packages

with RayTracing_Constants; use RayTracing_Constants;

with Bitmap;  use Bitmap;
with Cameras; use Cameras;
with Lights;  use Lights;
with Objects; use Objects;


-- @summary creates scene information, then renders it
--
package RayTracer is


   type Scene_Type (Thing_Count, Light_Count: Natural) is private;
   -- a scene of lights and objects (things)

   function Things(Scene: Scene_Type) return Thing_Array;
   -- returns the array of objects in Scene

   procedure Create_Scene(
                          Scene: out Scene_Type;
                          Things: Thing_Array;
                          Lights: Light_Array;
                          Camera: Camera_Type;
                          Depth: Natural
                         );
   -- creates a scene with things and lights, given a camera
   -- and a desired depth of reflection

   procedure Render_Scene(
                          Scene: Scene_Type;
                          Bitmap: out Bitmap_Data;
                          Width, Height: Int32
                         );
   -- renders the Scene into Bitmap, which is of given Width and Height

private

   type Scene_Type (Thing_Count, Light_Count: Natural) is record
      Max_Depth: Natural;
      Things:    Thing_Array(1 .. Thing_Count);
      Lights:    Light_Array(1 .. Light_Count);
      Camera:    Camera_Type;
   end record;

end RayTracer;
