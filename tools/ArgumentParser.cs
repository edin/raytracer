using System.Collections.Generic;

namespace Tools
{
    internal class ArgumentParser
    {
        private string[] args;
        private string action = null;
        private Dictionary<string, object> arguments = new Dictionary<string, object>();

        private string GetArgument(int pos)
        {
            if (pos >= 0 && pos < args.Length)
            {
                return args[pos];
            }
            return "";
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
                        arguments.Add(key, value);
                        i += 1;
                    }
                    else
                    {
                        arguments.Add(key, true);
                    }
                }
            }
        }

        public Dictionary<string, object> Argiments => arguments;
    }
}