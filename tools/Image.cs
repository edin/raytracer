using System;
using System.IO;
using System.Runtime.InteropServices;

namespace Tools
{
    internal struct RGBColor
    {
        public byte B;
        public byte G;
        public byte R;
        public byte A;

        public RGBColor Diff(RGBColor color)
        {
            RGBColor result;
            result.A = 255;
            result.R = (byte)Math.Abs((int)R - (int)color.R);
            result.G = (byte)Math.Abs((int)G - (int)color.G);
            result.B = (byte)Math.Abs((int)B - (int)color.B);
            return result;
        }
    }

    internal class ImageDiffResult
    {
        public string Message { get; set; }
        public Image Image { get; set; }
    }


    internal class Image
    {
        private RGBColor[] data;

        public ImageDiffResult Diff(Image image)
        {
            ImageDiffResult diffResult = new ImageDiffResult();

            if (this.Width != image.Width || this.Height != image.Height)
            {
                diffResult.Message = "Image size does not match";
                return diffResult;
            }

            diffResult.Image = new Image(Width, Height);

            for (int pos = 0; pos < data.Length; pos ++)
            {
                RGBColor a = this[pos];
                RGBColor b = image[pos];
                diffResult.Image[pos] = a.Diff(b);
            }

            // TODO: Scale luminance

            return diffResult;
        }

        public int Width { get; private set; }
        public int Height { get; private set; }

        [StructLayout(LayoutKind.Sequential)]
        private struct BITMAPINFOHEADER
        {
            public uint biSize;
            public int biWidth;
            public int biHeight;
            public ushort biPlanes;
            public ushort biBitCount;
            public uint biCompression;
            public uint biSizeImage;
            public int biXPelsPerMeter;
            public int biYPelsPerMeter;
            public uint biClrUsed;
            public uint biClrImportant;
        }

        [StructLayout(LayoutKind.Sequential, Pack = 2)]
        private struct BITMAPFILEHEADER
        {
            public ushort bfType;
            public uint bfSize;
            public ushort bfReserved1;
            public ushort bfReserved2;
            public uint bfOffBits;
        }

        public Image(int width, int height)
        {
            this.Width = width;
            this.Height = height;
            this.data = new RGBColor[(width * height)];
        }

        public Image(string fileName)
        {
            using var reader = new BinaryReader(File.Open(fileName, FileMode.Open));

            var fh = reader.ReadBytes(Marshal.SizeOf(typeof(BITMAPFILEHEADER)));
            var bh = reader.ReadBytes(Marshal.SizeOf(typeof(BITMAPINFOHEADER)));

            var bfh = GetStruct<BITMAPFILEHEADER>(fh);
            var bih = GetStruct<BITMAPINFOHEADER>(bh);

            byte[] byteData = reader.ReadBytes((int)bih.biSizeImage);

            this.Width = Math.Abs(bih.biWidth);
            this.Height = Math.Abs(bih.biHeight);
            this.data = new RGBColor[(Width * Height)];

            for (int y = 0; y < Height; y++)
            {
                for (int x = 0; x < Width; x++)
                {
                    var pos = (x + Width * y);
                    this.data[pos] = new RGBColor
                    {
                        B = byteData[4 * pos + 0],
                        G = byteData[4 * pos + 1],
                        R = byteData[4 * pos + 2],
                        A = byteData[4 * pos + 3]
                    };
                }
            }
        }

        public RGBColor this[int index]
        {
            get { return data[index]; }
            set { data[index] = value; }
        }

        public void Save(string fileName)
        {
            var infoHeaderSize = Marshal.SizeOf(typeof(BITMAPINFOHEADER));
            var fileHeaderSize = Marshal.SizeOf(typeof(BITMAPFILEHEADER));
            var offBits = infoHeaderSize + fileHeaderSize;

            BITMAPINFOHEADER infoHeader = new BITMAPINFOHEADER
            {
                biSize = (uint)infoHeaderSize,
                biBitCount = 32,
                biClrImportant = 0,
                biClrUsed = 0,
                biCompression = 0,
                biHeight = -Height,
                biWidth = Width,
                biPlanes = 1,
                biSizeImage = (uint)(Width * Height * 4)
            };

            BITMAPFILEHEADER fileHeader = new BITMAPFILEHEADER
            {
                bfType = 'B' + ('M' << 8),
                bfOffBits = (uint)offBits,
                bfSize = (uint)(offBits + infoHeader.biSizeImage)
            };

            using var writer = new BinaryWriter(File.Open(fileName, FileMode.Create));
            writer.Write(GetBytes(fileHeader));
            writer.Write(GetBytes(infoHeader));
            foreach (var color in data)
            {
                writer.Write(color.B);
                writer.Write(color.G);
                writer.Write(color.R);
                writer.Write(color.A);
            }
        }

        private static byte[] GetBytes<T>(T data)
        {
            var length = Marshal.SizeOf(data);
            var ptr = Marshal.AllocHGlobal(length);
            var result = new byte[length];
            Marshal.StructureToPtr(data, ptr, true);
            Marshal.Copy(ptr, result, 0, length);
            Marshal.FreeHGlobal(ptr);
            return result;
        }

        private T GetStruct<T>(byte[] bytes) where T : struct
        {
            T stuff;
            GCHandle handle = GCHandle.Alloc(bytes, GCHandleType.Pinned);
            try
            {
                stuff = (T)Marshal.PtrToStructure(handle.AddrOfPinnedObject(), typeof(T));
            }
            finally
            {
                handle.Free();
            }
            return stuff;
        }
    }
}