using System.Collections.Generic;
using System.Linq;
using System.Reflection;

namespace Tools
{
    internal class CommandAction
    {
        public object Instance { get; set; }
        public MethodInfo Method { get; set; }
        public List<object> Arguments { get; set; }

        public void Run()
        {
            Method.Invoke(Instance, Arguments.ToArray());
        }
    }


    internal class ArgumentParser
    {
        private string[] args;
        private string action = "";
        private Dictionary<string, object> arguments = new Dictionary<string, object>();

        private string GetArgument(int pos)
        {
            if (pos >= 0 && pos < args.Length)
            {
                return args[pos];
            }
            return "";
        }

        internal List<MethodInfo> GetCommands(object program)
        {
            return program.GetType()
                    .GetMethods()
                    .Where(m => m.GetCustomAttributes(typeof(CommandAttribute), false).Length > 0)
                    .ToList();
        }

        public ArgumentParser(string[] args)
        {
            this.args = args;
            this.action = this.GetArgument(0);

            for (var i = 1; i < args.Length; i++)
            {
                string name = this.GetArgument(i);
                string value = this.GetArgument(i + 1);
                if (name.StartsWith("--"))
                {
                    var key = name.Substring(2);
                    if (!value.StartsWith("--"))
                    {
                        arguments.Add(key.ToLower(), value);
                        i += 1;
                    }
                    else
                    {
                        arguments.Add(key.ToLower(), true);
                    }
                }
            }
        }

        internal CommandAction FindCommand(object instance)
        {
            var methods = this.GetCommands(instance);
            var method = methods.FirstOrDefault(m => string.Compare(m.Name, this.action, true) == 0);
            var missingParams = new List<string>();

            if (method != null)
            {
                var methodArguments = new List<object>();

                foreach(var p in method.GetParameters())
                {
                    var key = p.Name.ToLower();
                    if (!arguments.ContainsKey(key) && !p.IsOptional)
                    {
                        throw new System.Exception($"Missing parameter '{p.Name}'");
                    }
                    object value = null;
                    
                    if (p.IsOptional && p.HasDefaultValue)
                    {
                        value = p.DefaultValue;
                    }
                    if (arguments.ContainsKey(key))
                    {
                        value = System.Convert.ChangeType(arguments[key], p.ParameterType);
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

        public Dictionary<string, object> Arguments => arguments;
    }
}