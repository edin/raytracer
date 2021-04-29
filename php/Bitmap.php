<?php

namespace RayTracer;

use SplFixedArray;

class BitmapInfoHeader
{
    public int $biSize = 0;
    public int $biWidth = 0;
    public int $biHeight = 0;
    public int $biPlanes = 0;
    public int $biBitCount = 0;
    public int $biCompression = 0;
    public int $biSizeImage = 0;
    public int $biXPelsPerMeter = 0;
    public int $biYPelsPerMeter = 0;
    public int $biClrUsed = 0;
    public int $biClrImportant = 0;

    public function getBytes(): array
    {
        return Encoding::Join(
            Encoding::DWORD($this->biSize),
            Encoding::LONG($this->biWidth),
            Encoding::LONG($this->biHeight),
            Encoding::WORD($this->biPlanes),
            Encoding::WORD($this->biBitCount),
            Encoding::DWORD($this->biCompression),
            Encoding::DWORD($this->biSizeImage),
            Encoding::LONG($this->biXPelsPerMeter),
            Encoding::LONG($this->biYPelsPerMeter),
            Encoding::DWORD($this->biClrUsed),
            Encoding::DWORD($this->biClrImportant)
        );
    }
}

class BitmapFileHeader
{
    public int $bfType = 0;
    public int $bfSize = 0;
    public int $bfReserved = 0;
    public int $bfOffBits = 0;

    public function getBytes(): array
    {
        return Encoding::Join(
            Encoding::WORD($this->bfType),
            Encoding::DWORD($this->bfSize),
            Encoding::DWORD($this->bfReserved),
            Encoding::DWORD($this->bfOffBits)
        );
    }
}

class Encoding
{
    public static function DWORD(int $n): array
    {
        $b0 = (($n >> 0) & 0x000000FF);
        $b1 = (($n >> 8) & 0x000000FF);
        $b2 = (($n >> 16) & 0x000000FF);
        $b3 = (($n >> 24) & 0x000000FF);
        return [$b0, $b1, $b2, $b3 ];
    }

    public static function LONG(int $n): array
    {
        return Encoding::DWORD($n);
    }

    public static function WORD(int $n): array
    {
        $b0 = ($n & 0x000000FF);
        $b1 = (($n >> 8) & 0x000000FF);
        return [$b0, $b1];
    }

    public static function Join(array ...$elements): array
    {
        $result = [];
        foreach ($elements as $values) {
            foreach ($values as $value) {
                $result[] = $value;
            }
        }
        return $result;
    }
}

class Image
{
    private int $width;
    private int $height;
    private SplFixedArray $data;

    public function __construct(int $width, int $height)
    {
        $this->width = $width;
        $this->height = $height;
        $this->data = new SplFixedArray($width * $height);
    }

    public function getWidth(): int
    {
        return $this->width;
    }

    public function getHeight(): int
    {
        return $this->height;
    }

    public function setColor(int $x, int $y, RGBColor $color): void
    {
        $this->data[$y * $this->width + $x] = $color;
    }

    public function save(string $fileName): void
    {
        $infoHeaderSize = 40;
        $fileHeaderSize = 14;
        $offBits = $infoHeaderSize + $fileHeaderSize;

        $infoHeader = new BitmapInfoHeader();
        $infoHeader->biSize = $infoHeaderSize;
        $infoHeader->biBitCount = 32;
        $infoHeader->biClrImportant = 0;
        $infoHeader->biClrUsed = 0;
        $infoHeader->biCompression = 0;
        $infoHeader->biHeight = -$this->height;
        $infoHeader->biWidth = $this->width;
        $infoHeader->biPlanes = 1;
        $infoHeader->biSizeImage = ($this->width * $this->height * 4);

        $fileHeader = new BitmapFileHeader();
        $fileHeader->bfType = ord('B') + (ord('M') << 8);
        $fileHeader->bfOffBits = $offBits;
        $fileHeader->bfSize = ($offBits + $infoHeader->biSizeImage);

        try {
            $data = [... $fileHeader->getBytes(), ... $infoHeader->getBytes() ];

            foreach ($this->data as $color) {
                $data[] = $color->b;
                $data[] = $color->g;
                $data[] = $color->r;
                $data[] = 255;
            }

            file_put_contents($fileName, pack("C*", ...$data));
        } catch (\Exception $ex) {
        }
    }
}
