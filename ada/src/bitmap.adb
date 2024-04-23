--
-- Raytracer implementation in Ada
-- by John Perry (github: johnperry-math)
-- 2021
--
-- implementation for Bitmap, a Bitmap of Color_With_Transparency_Type,
-- along with a procedure to save the Bitmap to a BMP file
--

pragma Ada_2022; -- use Ada_2022 features

-- Ada packages

with Interfaces.C; use Interfaces.C; -- interface to C
with Ada.Streams.Stream_IO;          -- writing data to disk
with Ada.Text_IO; use Ada.Text_IO;   -- I/O

-- local packages

with RayTracing_Constants; use RayTracing_Constants;

package body Bitmap is

   bi_rgb: constant := 0; -- whether the data is compressed

   procedure Save_RGB_Bitmap
     (
      bits: Bitmap_Data;
      width, height: Int32;
      bits_per_pixel: UInt16;
      filename: String
     )
   is

      type Bitmap_File_Header is record
         Header_Type: UInt16;
         Size: UInt32;
         Reserved1, Reserved2: UInt16 := 0;
         Off_Bits: UInt32;
      end record with Pack;
      -- header for file storing the bitmap

      type Bitmap_Info_Header is record
         size: UInt32;
         width, height: Int32;
         planes, bit_count: UInt16;
         compression, size_image: UInt32;
         xpels_per_meter, ypels_per_meter: Int32;
         clr_used, clr_important: UInt32;
      end record with Pack;
      -- header for bitmap within file

      info_size: UInt32
        := UInt32( size_t( Bitmap_Info_Header'Size / CHAR_BIT ) );
        -- size of bitmap header

      info_header: Bitmap_Info_Header
        := (
            size => info_size,
            bit_count => bits_per_pixel,
            clr_important => 0,
            clr_used => 0,
            compression => bi_rgb,
            height => -height,
            width => width,
            planes => 1,
            size_image => UInt32( width * height * Int32( bits_per_pixel ) / 8 ),
            --  pixels => bits,
            others => 0
           );

      file_header: Bitmap_File_Header
        := (
            Header_Type => Character'Pos('B')
            + ( Character'Pos('M') * UInt16( 2 ** 8 ) ),
            Off_Bits    => Info_Size
            + UInt32( Size_T(Bitmap_File_Header'Size / CHAR_BIT) ),
            Size        => Info_Size
            + UInt32( Size_T(Bitmap_File_Header'Size / CHAR_BIT) )
            + Info_Header.Size_Image,
            others => 0
           );

      F: Ada.Streams.Stream_IO.File_Type;

   begin

      Ada.Streams.Stream_IO.Create(F, Name => filename);
      Bitmap_File_Header'Write( Ada.Streams.Stream_IO.Stream(F), File_Header );
      Bitmap_Info_Header'Write( Ada.Streams.Stream_IO.Stream(F), Info_Header );
      Bitmap_Data'Write( Ada.Streams.Stream_IO.Stream(F), Bits );
      Ada.Streams.Stream_IO.Close(F);

   end Save_RGB_Bitmap;

end Bitmap;
