using System;
using System.Linq;

namespace Tools
{
    public class Program
    {
        private static void Main(string[] args)
        {
            var argumentParser = new ArgumentParser(args);

            var program = new ConsoleApplication();
            var methods = program.GetType()
                                 .GetMethods()
                                 .Where(m => m.GetCustomAttributes(typeof(CommandAttribute), false).Length > 0)
                                 .ToList();

            //TODO: Find and invoke command using provided arguments
            
            Console.WriteLine("[Commands]");
            foreach (var m in methods)
            {
                Console.WriteLine(" - {0}", m.Name);
            }
        }
    }
}