--
-- Raytracer implementation in Ada
-- by John Perry (github: johnperry-math)
-- 2021
--
-- specification for Bitmap, a Bitmap of Color_With_Transparency_Type,
-- along with a procedure to save the Bitmap to a BMP file
--

-- local packages

with Colors; use Colors;

with RayTracing_Constants; use RayTracing_Constants;

-- @summary specifies a Bitmap of Color_With_Transparency_Type,
-- along with a procedure to save the Bitmap to a BMP file
package Bitmap is

   type Bitmap_Data
   is array ( Positive range <> ) of Color_With_Transparency_Type with Pack;
   -- the range can be any Positive range; we never assume start or end values

   procedure Save_RGB_Bitmap
     (
      bits: Bitmap_Data;      -- image data in format BGRA, packed
      width, height: Int32;   -- image dimensions
      bits_per_pixel: UInt16; -- self-explanatory?
      filename: String        -- name of the file to save
     );
     -- @summary saves bits, of dimension width and height, with bits_per_pixel,
     -- to filename

end Bitmap;
