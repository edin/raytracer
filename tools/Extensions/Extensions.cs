using System;
using SixLabors.ImageSharp.PixelFormats;

namespace Tools.Extensions
{
    static class Extensions
    {
        public static Rgba32 Sub(in this Rgba32 color, in Rgba32 other)
        {
            var result = new Rgba32
            {
                B = (byte)Math.Abs(color.B - other.B),
                G = (byte)Math.Abs(color.G - other.G),
                R = (byte)Math.Abs(color.R - other.R),
                A = 255
            };
            return result;
        }

        public static byte Scale(in this byte color, byte maxColor)
        {
            if (maxColor > 0)
            {
                return (byte)(255 * (color / (float)maxColor));
            }
            return color;
        }
    }
}
