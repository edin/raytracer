using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

namespace Tools.Application
{
    class ConsoleApplication
    {
        private ArgumentParser argumentParser;
        private Dictionary<string, object> arguments;
        private string action;
        private List<object> commands = new List<object>();

        public ConsoleApplication(string[] args)
        {
            argumentParser = new ArgumentParser(args);
            arguments = argumentParser.Arguments;
            action = argumentParser.Action;
        }

        public void AddCommand(object instance)
        {
            commands.Add(instance);
        }

        public void Run()
        {
            try
            {
                foreach (var commandSet in commands)
                {
                    var command = FindCommand(commandSet);
                    if (command != null)
                    {
                        command.Run();
                        return;
                    }
                }

                var allCommands = new List<MethodInfo>();
                foreach (var commandSet in commands)
                {
                    var commands = GetCommands(commandSet);
                    allCommands.AddRange(commands);
                }

                DisplayCommands(allCommands);
            }
            catch (Exception ex)
            {
                Console.WriteLine("Error:");
                if (ex.InnerException != null)
                {
                    Console.WriteLine(ex.InnerException.Message);
                }
                else
                {
                    Console.WriteLine(ex.Message);
                }
            }
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

        internal List<MethodInfo> GetCommands(object program)
        {
            return program.GetType()
                    .GetMethods()
                    .Where(m => m.GetCustomAttributes(typeof(CommandAttribute), false).Length > 0)
                    .ToList();
        }

        private CommandAction FindCommand(object instance)
        {
            var methods = this.GetCommands(instance);
            var method = methods.FirstOrDefault(m => string.Compare(m.Name, this.action, true) == 0);
            var missingParams = new List<string>();

            if (method != null)
            {
                var methodArguments = new List<object>();

                foreach (var p in method.GetParameters())
                {
                    var key = p.Name.ToLower();
                    if (!arguments.ContainsKey(key) && !p.IsOptional)
                    {
                        throw new Exception($"Missing parameter '{p.Name}'");
                    }
                    object value = null;

                    if (p.IsOptional && p.HasDefaultValue)
                    {
                        value = p.DefaultValue;
                    }
                    if (arguments.ContainsKey(key))
                    {
                        value = Convert.ChangeType(arguments[key], p.ParameterType);
                    }

                    methodArguments.Add(value);
                }

                return new CommandAction()
                {
                    Instance = instance,
                    Method = method,
                    Arguments = methodArguments
                };
            }
            return null;
        }
    }
}