using Tools.Application;
using Tools.Commands;

namespace Tools
{
    public class Program
    {
        private static void Main(string[] args)
        {
            var application = new ConsoleApplication(args);
            application.AddCommand(new DiffCommand());
            application.AddCommand(new TimeCommand());
            application.Run();
        }
    }
}