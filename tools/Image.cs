namespace Tools
{
    internal class Image
    {
        private RGBColor[] data;
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

            using (var writer = new BinaryWriter(File.Open(fileName, FileMode.Create)))
            {
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
        }

        public byte[] GetBytes<T>(T data)
        {
            var length = Marshal.SizeOf(data);
            var ptr = Marshal.AllocHGlobal(length);
            var result = new byte[length];
            Marshal.StructureToPtr(data, ptr, true);
            Marshal.Copy(ptr, result, 0, length);
            Marshal.FreeHGlobal(ptr);
            return result;
        }
    }
}