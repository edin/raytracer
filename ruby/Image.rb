class BinaryStream
    def initialize()
    end

    def write_word(value)
    end

    def write_dword(value)
    end

    def write_long(value)
    end
end

class BitmapInfoHeader
    def initialize(w, h)
        @biSize = 0          # DWORD
        @biWidth = 0         # LONG
        @biHeight = 0        # LONG
        @biPlanes = 0        # WORD
        @biBitCount = 0      # WORD
        @biCompression = 0   # DWORD
        @biSizeImage = 0     # DWORD
        @biXPelsPerMeter = 0 # LONG
        @biYPelsPerMeter = 0 # LONG
        @biClrUsed = 0       # DWORD
        @biClrImportant = 0  # DWORD

        @biSize = 40;
        @biWidth = w;
        @biHeight = -h;
        @biPlanes = 1;
        @biBitCount = 32;
        @biSizeImage = w * h * 4;
    end

    def write_to (stream)
        stream.write_dword(@biSize),
        stream.write_long(@biWidth),
        stream.write_long(@biHeight),
        stream.write_word(@biPlanes),
        stream.write_word(@biBitCount),
        stream.write_dword(@biCompression),
        stream.write_dword(@biSizeImage),
        stream.write_long(@biXPelsPerMeter),
        stream.write_long(@biYPelsPerMeter),
        stream.write_dword(@biClrUsed),
        stream.write_dword(@biClrImportant),
    end
end

class BitmapFileHeader
    # private bfType: number = 0;    // WORD
    # public bfSize: number = 0;     // DWORD
    # public bfReserved: number = 0; // DWORD
    # public bfOffBits: number = 0;  // DWORD

    def initialize(imageSize: number)
        @bfType = 0x4D42;
        @bfOffBits = 54;
        @bfSize = @bfOffBits + imageSize;
    end

    def write_to(stream)
        stream.write_word(@bfType),
        stream.write_dword(@bfSize),
        stream.write_dword(@bfReserved),
        stream.write_dword(@bfOffBits),
    end
end


class Image
    def initialize(width, height)
        @width = width
        @height = height
        @colors = Array.new(width) { Array.new(height) }
    end

    def set_pixel(x, y, color)
        @colors[x][y] = color
    end

    def save_to(filname)
        data = Int8Array.new(54 + @data.width * @data.height * 4);
        stream = BinaryStream.new(data)

        bih = BitmapInfoHeader.new(this.width, this.height);
        bfh = BitmapFileHeader.new(this.data.length);

        bfh.write_to(stream)
        bih.write_to(stream)

        # write bitmap bites

        # save image
    end
end