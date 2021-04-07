--
-- Raytracer implementation in Ada
-- by John Perry (github: johnperry-math)
-- 2021
--
-- main program
--

-- Ada packages

with Ada.Text_IO; use Ada.Text_IO; -- I/O
with Ada.Real_Time;                -- timing

-- local packages

with Bitmap;
with Cameras;
with Colors;
with Lights;
with Objects;
with RayTracer;
with Vectors;

with RayTracing_Constants; use RayTracing_Constants;

-- @summary
-- creates, draws, and saves a 500px x 500px image of two shiny balls
-- on a checkerboard
procedure Main is

   Start, Stop: Ada.Real_Time.Time;     -- clock times at start, stop of render
   Difference: Ada.Real_Time.Time_Span; -- difference between Start and Stop

   Width:  Int32 := 500; -- image width
   Height: Int32 := 500; -- image height

   Bmp: Bitmap.Bitmap_Data( 1 .. Integer( Width * Height ) ); -- bitmap to save

   function "-"(First, Second: Ada.Real_Time.Time)
                return Ada.Real_Time.Time_Span
                renames Ada.Real_Time."-";
   -- make the predefined subtraction operator available for time

   package L renames Lights;

   Lights: L.Light_Array( 1 .. 4 ); -- lights shining on the image
   Things: Objects.Thing_Array( 1 .. 3 ); -- things present in the image
   Camera: Cameras.Camera_Type;

   Scene: RayTracer.Scene_Type(
                               Light_Count => Lights'Length,
                               Thing_Count => Things'Length
                              );
   -- the scene to display

begin

   -- set up the objects in the scene, the lights, and the Camera_Type

   Objects.Create_Plane(
                        Things(1),
                        Vectors.Create_Vector(0.0, 1.0, 0.0),
                        0.0,
                        Objects.Checkerboard
                       );
   Objects.Create_Sphere(
                         Things(2),
                         Vectors.Create_Vector(0.0, 1.0, -0.25),
                         1.0,
                         Objects.Shiny
                        );
   Objects.Create_Sphere(
                         Things(3),
                         Vectors.Create_Vector(-1.0, 0.5, 1.5),
                         0.5,
                         Objects.Shiny
                        );

   Lights(1) := L.Create_Light(
                               Vectors.Create_Vector(-2.0, 2.5, 0.0),
                               Colors.Create_Color(0.49, 0.07, 0.07)
                              );
   Lights(2) := L.Create_Light(
                               Vectors.Create_Vector(1.5, 2.5, 1.5),
                               Colors.Create_Color(0.07, 0.07, 0.49)
                              );
   Lights(3) := L.Create_Light(
                               Vectors.Create_Vector(1.5, 2.5, -1.5),
                               Colors.Create_Color(0.07, 0.49, 0.071)
                              );
   Lights(4) := L.Create_Light(
                               Vectors.Create_Vector(0.0, 3.5, 0.0),
                               Colors.Create_Color(0.21, 0.21, 0.35)
                              );

   Camera := Cameras.Create_Camera(
                                   Vectors.Create_Vector(3.0, 2.0, 4.0),
                                   Vectors.Create_Vector(-1.0, 0.5, 0.0)
                                  );

   RayTracer.Create_Scene(Scene, Things, Lights, Camera, 5);

   -- render and time the rendering

   Put_Line("started");

   Start := Ada.Real_Time.Clock;

   RayTracer.Render_Scene(Scene, Bmp, Width, Height);

   Stop := Ada.Real_Time.Clock;
   Difference := Stop - Start;

   -- report time, then save output

   Put_Line(
            "Completed in"
            & Duration'Image( Ada.Real_Time.To_Duration(Difference))
            & " seconds"
           );
   Bitmap.Save_RGB_Bitmap(Bmp, Width, Height, 32, "ada-raytracer.bmp");

end Main;
