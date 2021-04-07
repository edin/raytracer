--
-- Raytracer implementation in Ada
-- by John Perry (github: johnperry-math)
-- 2021
--
-- specification for types, constants, and operators used throughout
--

-- Ada packages

with Interfaces;

-- @summary types, constants, and operators used throughout the project
-- @description
-- Makes precise the meaning of floating-point and integer types that we need.
--
package RayTracing_Constants is

   type Float15 is digits 15;
   -- floating point with 15 digit precision; i.e.,
   -- 64-bit floating point will suffice

   Far_Away: constant Float15 := 1_000_000.0;
   -- an point too far away to be considered useful

   subtype UInt8  is Interfaces.Unsigned_8;
   function "="(First, Second: UInt8) return Boolean renames Interfaces."=";

   subtype UInt16 is Interfaces.Unsigned_16;
   function "+"(First, Second: UInt16) return UInt16 renames Interfaces."+";
   function "*"(First, Second: UInt16) return UInt16 renames Interfaces."*";

   subtype UInt32 is Interfaces.Unsigned_32;
   function "+"(First, Second: UInt32) return UInt32 renames Interfaces."+";

   subtype Int32  is Interfaces.Integer_32;
   function "-"(It: Int32) return Int32 renames Interfaces."-";
   function "+"(First, Second: Int32) return Int32 renames Interfaces."+";
   function "-"(First, Second: Int32) return Int32 renames Interfaces."-";
   function "*"(First, Second: Int32) return Int32 renames Interfaces."*";
   function "/"(First, Second: Int32) return Int32 renames Interfaces."/";

end RayTracing_Constants;
