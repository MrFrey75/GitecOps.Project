using System;
using Newtonsoft.Json;

class Program
{
    static void Main(string[] args)
    {
        if (args.Length == 0 || string.IsNullOrWhiteSpace(args[0]))
        {
            Console.Error.WriteLine("ERROR: No name provided.");
            Environment.Exit(1);
        }

        var result = new
        {
            greeting = $"Hello, {args[0]}!",
            timestamp = DateTime.UtcNow
        };

        var json = JsonConvert.SerializeObject(result, Formatting.Indented);
        Console.WriteLine(json);
        Environment.Exit(0);
    }
}