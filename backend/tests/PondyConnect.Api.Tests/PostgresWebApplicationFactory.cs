using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Infrastructure.Persistence;
using Testcontainers.PostgreSql;

namespace PondyConnect.Api.Tests;

/// <summary>
/// WebApplicationFactory that starts a real PostgreSQL container via
/// Testcontainers, runs EF Core migrations, and seeds the database via
/// DataInitializer. Used by E2E tests that need real database behavior
/// (foreign keys, migrations, provider-specific column types).
///
/// Requires Docker Desktop to be running on the machine.
/// </summary>
public sealed class PostgresWebApplicationFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder("postgis/postgis:16-3.4")
        .WithDatabase("pondyconnect_e2e")
        .WithUsername("test")
        .WithPassword("test")
        .Build();

    public string ConnectionString => _postgres.GetConnectionString();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        // Set environment variables for rate limiting config.
        // Environment variables are read by WebApplicationBuilder during
        // construction (before Program.cs reads builder.Configuration),
        // so these overrides take effect unlike ConfigureAppConfiguration.
        Environment.SetEnvironmentVariable("RateLimiting__Auth__PermitLimit", "10000");
        Environment.SetEnvironmentVariable("RateLimiting__Auth__WindowSeconds", "1");
        Environment.SetEnvironmentVariable("RateLimiting__Auth__QueueLimit", "10000");
        Environment.SetEnvironmentVariable("RateLimiting__Global__PermitLimit", "10000");
        Environment.SetEnvironmentVariable("RateLimiting__Global__WindowSeconds", "1");
        Environment.SetEnvironmentVariable("RateLimiting__Global__QueueLimit", "10000");

        builder.ConfigureAppConfiguration(config =>
        {
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:PostgreSQL"] = _postgres.GetConnectionString(),
                ["Database:Provider"] = "PostgreSQL",
                ["HttpsRedirection:Enabled"] = "false",
                ["Payments:UseMock"] = "true",
                ["Sms:UseMock"] = "true",
                ["Storage:UseMock"] = "true",
            });
        });

        builder.ConfigureServices(services =>
        {
            // Remove the existing DbContext registration (which may be SQLite
            // from appsettings.json) and replace with PostgreSQL pointing to
            // the test container.
            var dbContextDescriptors = services
                .Where(d => d.ServiceType == typeof(DbContextOptions<ApplicationDbContext>)
                    || d.ServiceType == typeof(DbContextOptions))
                .ToList();
            foreach (var d in dbContextDescriptors)
                services.Remove(d);

            services.AddDbContext<ApplicationDbContext>(options =>
            {
                options.UseNpgsql(_postgres.GetConnectionString(), npgsql =>
                {
                    npgsql.MigrationsAssembly(typeof(ApplicationDbContext).Assembly.FullName);
                    npgsql.UseNetTopologySuite();
                });
            });

            // Replace IOtpService with a test version that exposes codes in plaintext.
            var otpDescriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(IOtpService));
            if (otpDescriptor != null)
                services.Remove(otpDescriptor);
            services.AddSingleton<IOtpService, TestOtpService>();

            // Remove ALL background workers/hosted services that could
            // interfere with tests (PaymentReconciliationWorker polls the DB
            // and can cause DbContext concurrency issues during test setup).
            var hostedServices = services
                .Where(d => d.ServiceType == typeof(Microsoft.Extensions.Hosting.IHostedService))
                .ToList();
            foreach (var d in hostedServices)
                services.Remove(d);

            // Note: Rate limiting config overrides don't take effect because
            // builder.Configuration is read during Program.cs before the factory's
            // ConfigureAppConfiguration runs. Tests handle 429s by retrying auth.
        });
    }

    public async Task InitializeAsync()
    {
        await _postgres.StartAsync();

        // Run migrations and seed data.
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        await db.Database.MigrateAsync();
        var initializer = new DataInitializer(db);
        await initializer.InitializeAsync();
    }

    public new async Task DisposeAsync()
    {
        await _postgres.DisposeAsync();
        await base.DisposeAsync();
    }
}
