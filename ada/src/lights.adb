package body Lights is

   function Create_Light(Position: Vector; Color: Color_Type) return Light_Type
   is ( ( Position => Position, Color => Color ) );

   function Position_Of(Light: Light_Type) return Vector
   is ( Light.Position );

   function Color_Of(Light: Light_Type) return Color_Type
   is ( Light.Color );

end Lights;
