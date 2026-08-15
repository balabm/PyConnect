namespace PondyConnect.Infrastructure.Persistence;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Npgsql.EntityFrameworkCore.PostgreSQL;

/// <summary>
/// Design-time factory that always uses PostgreSQL so `dotnet ef migrations add`
/// generates Npgsql-compatible migrations regardless of the appsettings.json
/// Database:Provider setting (which defaults to SQLite for local dev).
///
/// The connection string is read from the POSTGRES_CONNECTION_STRING env var,
/// falling back to a hardcoded development RDS string.
/// </summary>
public sealed class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<ApplicationDbContext>
{
    public ApplicationDbContext CreateDbContext(string[] args)
    {
        var connectionString = Environment.GetEnvironmentVariable("POSTGRES_CONNECTION_STRING")
            ?? "Host=pyconnect.ch2i68eyk0ii.eu-north-1.rds.amazonaws.com;Port=5432;Database=pondyconnect;Username=postgres;Password=pyconnect9943";

        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseNpgsql(connectionString, npgsql =>
            {
                npgsql.MigrationsAssembly(typeof(ApplicationDbContext).Assembly.FullName);
                npgsql.UseNetTopologySuite();
            })
            .Options;

        return new ApplicationDbContext(options);
    }
}
