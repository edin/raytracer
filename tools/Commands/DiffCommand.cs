﻿using System;
using Tools.Application;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;
using Tools.Extensions;
using System.IO;
using System.Linq;

namespace Tools.Commands
{
    public class DiffCommand
    {
        private string FindImage(string path)
        {
            if (File.Exists(path))
            {
                return path;
            }
            if (Directory.Exists(path))
            {
                var patterns = new string[] { "*.bmp", "*.png" };
                return patterns.SelectMany(p => Directory.GetFiles(path, p, SearchOption.AllDirectories)).FirstOrDefault();
            }
            return "";
        }


        [Command]
        public void ImageDiff(string source, string target)
        {
            source = FindImage(source);
            target = FindImage(target);

            if (!File.Exists(source))
            {
                Console.WriteLine("Source image is missing");
                return;
            }

            if (!File.Exists(target))
            {
                Console.WriteLine("Target image is missing");
                return;
            }

            Console.WriteLine($"Source: {source}");
            Console.WriteLine($"Target: {target}");
            Console.WriteLine("");

            var a = Image.Load<Rgba32>(source);
            var b = Image.Load<Rgba32>(target);

            if (a.Width != b.Width || 
                a.Height != b.Height)
            {
                Console.WriteLine($"Image size does not match ({a.Width}, {a.Height}) != ({b.Width}, {b.Height})");
                return;
            }

            var imageDiff = new Image<Rgba32>(a.Width, a.Height);
            var maxColor = new Rgba32();
            long changeCount = 0;
            
            for (var y = 0; y < a.Height; y++)
            {
                for (var x = 0; x < a.Width; x++)
                {
                    var pa = a[x, y];
                    var pb = b[x, y];
                    var diff = pa.Sub(pb);

                    if (diff.R != 0 || diff.G != 0 || diff.B != 0)
                    {
                        changeCount += 1;
                    }

                    imageDiff[x, y] = diff;

                    maxColor.B = Math.Max(maxColor.B, diff.B);
                    maxColor.G = Math.Max(maxColor.G, diff.G);
                    maxColor.R = Math.Max(maxColor.R, diff.R);
                    maxColor.A = 255;
                }
            }

            for (var y = 0; y < imageDiff.Height; y++)
            {
                for (var x = 0; x < imageDiff.Width; x++)
                {
                    var color = imageDiff[x, y];
                    color.B = color.B.Scale(maxColor.B);
                    color.G = color.G.Scale(maxColor.G);
                    color.R = color.R.Scale(maxColor.R);
                    maxColor.A = 255;
                    imageDiff[x, y] = color;
                }
            }

            if (changeCount > 0)
            {
                imageDiff.SaveAsBmp("diff.bmp");
                long totalPixels = a.Width * b.Width;
                Console.WriteLine($"Changes detected: {changeCount} out of {totalPixels} does not match\n");

                Console.ForegroundColor = ConsoleColor.DarkBlue;
                Console.WriteLine("Diff stored to 'diff.bmp' file");
                Console.ResetColor();
            } 
            else
            {
                Console.WriteLine("Images are the same");
            }
        }
    }
}