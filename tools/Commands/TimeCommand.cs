using Tools.Application;
using Tools.Models;
using System.Diagnostics;
using System.IO;
using System;
using System.Linq;

namespace Tools.Commands
{
    public class TimeCommand
    {
        private string baseDirectory;

        [Command]
        public void Time(string name)
        {
            this.baseDirectory = Directory.GetCurrentDirectory();
            var document = ProjectDocument.Load();

            foreach (var project in document.Projects)
            {
                Console.WriteLine(" {0}", project.Path);
            }

            var selectedProject = document.Projects.Where(p => string.Compare(p.Path, name, true) == 0).FirstOrDefault();

            if (selectedProject != null)
            {
                Run(selectedProject);
            }
        }

        private void Run(string path)
        {
            Directory.SetCurrentDirectory(path);

            var watch = Stopwatch.StartNew();
            var process = Process.Start("php", "RayTracer.php");

            long peakPagedMem = 0;
            long peakVirtualMem = 0;
            long peakWorkingSet = 0;

            do
            {
                if (!process.HasExited)
                {
                    process.Refresh();

                    peakPagedMem = Math.Max(peakPagedMem, process.PeakPagedMemorySize64);
                    peakVirtualMem = Math.Max(peakVirtualMem, process.PeakVirtualMemorySize64);
                    peakWorkingSet = Math.Max(peakWorkingSet, process.PeakWorkingSet64);
                }
            }
            while (!process.WaitForExit(1000));

            watch.Stop();
            var elapsedMs = watch.ElapsedMilliseconds;
            var peekMemory = Math.Round(peakWorkingSet / 1000.0 / 1000.0, 2);

            Console.WriteLine("---");
            Console.WriteLine($"Elapsed time: {elapsedMs} ms, Max memory used: {peekMemory} MB");
        }
    }
}
