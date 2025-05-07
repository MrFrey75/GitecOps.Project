using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace GitecOps.Util;

public class Program
{
    public static async Task<int> Main(string[] args)
    {
        using var host = CreateHostBuilder(args).Build();

        // Run the actual logic here
        var app = host.Services.GetRequiredService<App>();
        return await app.RunAsync(args);
    }

    static IHostBuilder CreateHostBuilder(string[] args) =>
        Host.CreateDefaultBuilder(args)
            .ConfigureLogging(logging =>
            {
                logging.ClearProviders();
                logging.AddConsole();
            })
            .ConfigureServices((_, services) =>
            {
                services.AddSingleton<App>();
                // Add other services here
            });
}

public class App
{
    private readonly ILogger<App> _logger;

    public App(ILogger<App> logger)
    {
        _logger = logger;
    }

    public Task<int> RunAsync(string[] args)
    {
        _logger.LogInformation("CLI started with args: {Args}", string.Join(' ', args));

        if (args.Length == 0)
        {
            _logger.LogError("No arguments provided.");
            return Task.FromResult(1);
        }

        // Example logic
        Console.WriteLine($"Hello, {args[0]}!");
        return Task.FromResult(0);
    }
}