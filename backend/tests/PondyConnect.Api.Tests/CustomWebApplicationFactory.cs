using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Infrastructure.Persistence;

namespace PondyConnect.Api.Tests;

public class CustomWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        builder.ConfigureAppConfiguration(config =>
        {
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["RateLimiting:PermitLimit"] = "10000",
                ["RateLimiting:WindowSeconds"] = "1",
                ["RateLimiting:QueueLimit"] = "10000",
                ["HttpsRedirection:Enabled"] = "false"
            });
        });

        builder.ConfigureServices(services =>
        {
            // Remove the production DbContext registration and replace with in-memory.
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<ApplicationDbContext>));
            if (descriptor != null)
                services.Remove(descriptor);

            services.AddDbContext<ApplicationDbContext>(options =>
            {
                options.UseInMemoryDatabase("InMemoryTestDb");
            });

            // Replace IOtpService with a test version that exposes codes in plaintext.
            var otpDescriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(IOtpService));
            if (otpDescriptor != null)
                services.Remove(otpDescriptor);
            services.AddSingleton<IOtpService, TestOtpService>();

            // Build the service provider and seed the database.
            var sp = services.BuildServiceProvider();
            using var scope = sp.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            db.Database.EnsureCreated();
        });
    }
}

public sealed class TestOtpService : IOtpService
{
    private readonly Dictionary<string, string> _codes = new();

    public Task<string> IssueCodeAsync(string phone, CancellationToken cancellationToken = default)
    {
        var code = Random.Shared.Next(100_000, 1_000_000).ToString("D6");
        _codes[phone] = code;
        return Task.FromResult(code);
    }

    public Task<bool> VerifyCodeAsync(string phone, string code, CancellationToken cancellationToken = default)
    {
        if (_codes.TryGetValue(phone, out var stored) && stored == code)
        {
            _codes.Remove(phone);
            return Task.FromResult(true);
        }
        return Task.FromResult(false);
    }

    public Task<string?> PeekCodeAsync(string phone, CancellationToken cancellationToken = default)
        => Task.FromResult<string?>(_codes.GetValueOrDefault(phone));

    public Task<string> GetCodeForTestAsync(string phone)
    {
        return Task.FromResult(_codes.GetValueOrDefault(phone) ?? string.Empty);
    }
}
