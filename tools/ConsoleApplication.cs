using System;

namespace Tools
{
    public class ConsoleApplication
    {
        [Command]
        public void Diff(string source, string target)
        {
            Console.WriteLine("Source {source}", source);
            Console.WriteLine("Target {source}", target);
        }

        [Command]
        public void ExampleOne(string source, string target)
        {
            Console.WriteLine("Source {source}", source);
            Console.WriteLine("Target {source}", target);
        }

        [Command]
        public void ExampleTwo(string source, string target)
        {
            Console.WriteLine("Source {source}", source);
            Console.WriteLine("Target {source}", target);
        }

        [Command]
        public void ExampleThree(string source, string target)
        {
            Console.WriteLine("Source {source}", source);
            Console.WriteLine("Target {source}", target);
        }
    }
}