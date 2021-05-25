using System.Collections.Generic;
using System.Reflection;

namespace Tools.Application
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
}