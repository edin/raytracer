//using System;
//using System.IO;
//using System.Runtime.InteropServices;

//namespace Tools2
//{
//    internal struct RGBColor
//    {
//        public byte B;
//        public byte G;
//        public byte R;
//        public byte A;

//        public RGBColor Diff(RGBColor color)
//        {
//            RGBColor result = new RGBColor();
//            result.A = 255;
//            result.R = (byte)Math.Abs((int)R - (int)color.R);
//            result.G = (byte)Math.Abs((int)G - (int)color.G);
//            result.B = (byte)Math.Abs((int)B - (int)color.B);
//            return result;
//        }

//        public RGBColor Scale(RGBColor color)
//        {
//            RGBColor result = new RGBColor();
//            result.R = Scale(this.R, color.R);
//            result.G = Scale(this.R, color.R);
//            result.B = Scale(this.R, color.R);
//            result.A = this.A;
//            return result;
//        }

//        private static byte Scale(byte value, byte max)
//        {
//            if (max > 0)
//            {
//                float v = (float)value;
//                float m = (float)max;
//                return (byte)(v / m * 255);
//            }
//            return value;
//        }
//    }

//    internal class ImageDiffResult
//    {
//        public string Message { get; set; }
//        public bool IsSame { get; set; }
//        public Image Image { get; set; }
//    }

//    internal class Image
//    {
//        private RGBColor[] data;

//        public ImageDiffResult Diff(Image image)
//        {
//            ImageDiffResult diffResult = new ImageDiffResult();

//            if (this.Width != image.Width || this.Height != image.Height)
//            {
//                diffResult.Message = "Image size does not match";
//                return diffResult;
//            }

//            diffResult.Image = new Image(Width, Height);
//            diffResult.IsSame = true;

//            RGBColor maxColor = new();

//            for (int pos = 0; pos < data.Length; pos++)
//            {
//                RGBColor a = this[pos];
//                RGBColor b = image[pos];
//                var diff = a.Diff(b);
//                diffResult.Image[pos] = diff;

//                if ((diff.R + diff.G + diff.B) > 0)
//                {
//                    diffResult.IsSame = false;
//                }

//                maxColor.R = Math.Max(diff.R, maxColor.R);
//                maxColor.G = Math.Max(diff.G, maxColor.G);
//                maxColor.B = Math.Max(diff.B, maxColor.B);
//            }

//            for (int pos = 0; pos < data.Length; pos++)
//            {
//                data[pos] = data[pos].Scale(maxColor);
//            }

//            return diffResult;
//        }

//        public int Width { get; private set; }
//        public int Height { get; private set; }

//        [StructLayout(LayoutKind.Sequential)]
//        private struct BITMAPINFOHEADER
//        {
//            public uint biSize;
//            public int biWidth;
//            public int biHeight;
//            public ushort biPlanes;
//            public ushort biBitCount;
//            public uint biCompression;
//            public uint biSizeImage;
//            public int biXPelsPerMeter;
//            public int biYPelsPerMeter;
//            public uint biClrUsed;
//            public uint biClrImportant;
//        }

//        [StructLayout(LayoutKind.Sequential, Pack = 2)]
//        private struct BITMAPFILEHEADER
//        {
//            public ushort bfType;
//            public uint bfSize;
//            public ushort bfReserved1;
//            public ushort bfReserved2;
//            public uint bfOffBits;
//        }

//        public Image(int width, int height)
//        {
//            this.Width = width;
//            this.Height = height;
//            this.data = new RGBColor[(width * height)];
//        }

//        public Image(string fileName)
//        {
//            using var reader = new BinaryReader(File.Open(fileName, FileMode.Open));

//            var fh = reader.ReadBytes(Marshal.SizeOf(typeof(BITMAPFILEHEADER)));
//            var bh = reader.ReadBytes(Marshal.SizeOf(typeof(BITMAPINFOHEADER)));

//            var bfh = GetStruct<BITMAPFILEHEADER>(fh);
//            var bih = GetStruct<BITMAPINFOHEADER>(bh);

//            this.Width = Math.Abs(bih.biWidth);
//            this.Height = Math.Abs(bih.biHeight);

//            byte[] byteData = reader.ReadBytes(Width * Height * 4);

//            this.data = new RGBColor[(Width * Height)];

//            for (int y = 0; y < Height; y++)
//            {
//                for (int x = 0; x < Width; x++)
//                {
//                    var pos = (x + Width * y);
//                    this.data[pos] = new RGBColor
//                    {
//                        B = byteData[4 * pos + 0],
//                        G = byteData[4 * pos + 1],
//                        R = byteData[4 * pos + 2],
//                        A = byteData[4 * pos + 3]
//                    };
//                }
//            }
//        }

//        public RGBColor this[int index]
//        {
//            get { return data[index]; }
//            set { data[index] = value; }
//        }

//        public void Save(string fileName)
//        {
//            var infoHeaderSize = Marshal.SizeOf(typeof(BITMAPINFOHEADER));
//            var fileHeaderSize = Marshal.SizeOf(typeof(BITMAPFILEHEADER));
//            var offBits = infoHeaderSize + fileHeaderSize;

//            BITMAPINFOHEADER infoHeader = new BITMAPINFOHEADER
//            {
//                biSize = (uint)infoHeaderSize,
//                biBitCount = 32,
//                biClrImportant = 0,
//                biClrUsed = 0,
//                biCompression = 0,
//                biHeight = -Height,
//                biWidth = Width,
//                biPlanes = 1,
//                biSizeImage = (uint)(Width * Height * 4)
//            };

//            BITMAPFILEHEADER fileHeader = new BITMAPFILEHEADER
//            {
//                bfType = 'B' + ('M' << 8),
//                bfOffBits = (uint)offBits,
//                bfSize = (uint)(offBits + infoHeader.biSizeImage)
//            };

//            using var writer = new BinaryWriter(File.Open(fileName, FileMode.Create));
//            writer.Write(GetBytes(fileHeader));
//            writer.Write(GetBytes(infoHeader));
//            foreach (var color in data)
//            {
//                writer.Write(color.B);
//                writer.Write(color.G);
//                writer.Write(color.R);
//                writer.Write(color.A);
//            }
//        }

//        private static byte[] GetBytes<T>(T data)
//        {
//            var length = Marshal.SizeOf(data);
//            var ptr = Marshal.AllocHGlobal(length);
//            var result = new byte[length];
//            Marshal.StructureToPtr(data, ptr, true);
//            Marshal.Copy(ptr, result, 0, length);
//            Marshal.FreeHGlobal(ptr);
//            return result;
//        }

//        private T GetStruct<T>(byte[] bytes) where T : struct
//        {
//            T stuff;
//            GCHandle handle = GCHandle.Alloc(bytes, GCHandleType.Pinned);
//            try
//            {
//                stuff = (T)Marshal.PtrToStructure(handle.AddrOfPinnedObject(), typeof(T));
//            }
//            finally
//            {
//                handle.Free();
//            }
//            return stuff;
//        }
//    }
//}