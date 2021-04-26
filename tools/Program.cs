using System;
using System.Collections.Generic;
using System.Reflection;

namespace Tools
{
    public class Program
    {
        private static void Main(string[] args)
        {
            var argumentParser = new ArgumentParser(args);
            var program = new ConsoleApplication();

            try
            {
                var methods = argumentParser.GetCommands(program);
                var command = argumentParser.FindCommand(program);

                if (command != null)
                {
                    RunCommand(command);
                }
                else
                {
                    DisplayCommands(methods);
                }
            } 
            catch (Exception ex)
            {
                Console.WriteLine("Error:");
                if (ex.InnerException != null)
                {
                    Console.WriteLine(ex.InnerException.Message);
                } else
                {
                    Console.WriteLine(ex.Message);
                }
            }
        }

        private static void RunCommand(CommandAction command)
        {
            command.Run();
        }

        private static void DisplayCommands(List<MethodInfo> methods)
        {
            Console.WriteLine("Commands:");
            foreach (var m in methods)
            {
                var defaultColor = Console.ForegroundColor;
                Console.ForegroundColor = ConsoleColor.Green;
                Console.Write(" {0}", m.Name);
                Console.ForegroundColor = defaultColor;

                foreach (var p in m.GetParameters())
                {
                    Console.Write(" --{0}: {1} ", p.Name, p.ParameterType.Name);
                }
                Console.WriteLine("");
            }
        }
    }
}