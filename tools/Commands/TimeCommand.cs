using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using Tools.Application;
using Tools.Models;

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

            //foreach (var project in document.Projects)
            //{
            //    Console.WriteLine(" {0}", project.Path);
            //}

            Project selectedProject = document.Projects.FirstOrDefault(p => string.Compare(p.Path, name, true) == 0);

            if (selectedProject != null)
            {
                var command = selectedProject.Commands.FirstOrDefault(x => string.Compare(x.Name, "default", true) == 0);

                if (command != null)
                {
                    BuildAndRun(selectedProject, command);
                }
            }
        }

        private void BuildAndRun(Project project, Command command)
        {
            Directory.SetCurrentDirectory(Path.Join(baseDirectory, project.Path));

            Build(command.Build);
            Run(command.Run);
        }

        private void Build(Build command)
        {
            if (command != null && !string.IsNullOrWhiteSpace(command.Process))
            {
                var process = Process.Start(command.Process, command.Arguments);
                process.WaitForExit();
            }
        }

        private void Run(Run command)
        {
            var watch = Stopwatch.StartNew();
            long totalMemory = 0;
            int n = 5;

            for (int i = 0; i < n; i++)
            {
                long peakPagedMem = 0;
                watch.Start();
                var process = Process.Start(command.Process, command.Arguments);
                do
                {
                    watch.Stop();
                    if (!process.HasExited)
                    {
                        process.Refresh();
                        peakPagedMem = Math.Max(peakPagedMem, process.PeakPagedMemorySize64);
                    }
                    watch.Start();
                }
                while (!process.WaitForExit(1000));
                watch.Stop();

                totalMemory += peakPagedMem;
            }

            var elapsedMs = (int)(watch.ElapsedMilliseconds / n);
            var peekMemory = Math.Round(totalMemory / n / 1000.0 / 1000.0, 2);

            
            Console.ForegroundColor = ConsoleColor.Gray;
            Console.WriteLine("---");
            Console.ResetColor();

            Console.ForegroundColor = ConsoleColor.DarkGreen;
            Console.WriteLine($"Completed in: {elapsedMs} ms, Max memory used: {peekMemory} MB");
            Console.ResetColor();
        }
    }
}