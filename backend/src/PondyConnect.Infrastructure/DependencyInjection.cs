namespace PondyConnect.Infrastructure;

using Amazon;
using Amazon.Extensions.NETCore.Setup;
using Google.Apis.Auth.OAuth2;
using Google.Cloud.Vision.V1;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Services;
using PondyConnect.Infrastructure.Cache;
using PondyConnect.Infrastructure.Locking;
using PondyConnect.Infrastructure.Persistence;
using PondyConnect.Infrastructure.Persistence.Repositories;
using PondyConnect.Infrastructure.Services;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        var provider = configuration.GetValue<string>("Database:Provider") ?? "PostgreSQL";

        if (string.Equals(provider, "SQLite", StringComparison.OrdinalIgnoreCase))
        {
            var sqliteConn = configuration.GetConnectionString("SQLite")
                ?? "Data Source=pondyconnect.db";
            services.AddDbContext<ApplicationDbContext>(options =>
                options.UseSqlite(sqliteConn));
        }
        else
        {
            var connectionString = configuration.GetConnectionString("PostgreSQL")
                ?? throw new InvalidOperationException("Connection string 'PostgreSQL' is not configured.");
            services.AddDbContext<ApplicationDbContext>(options =>
                options.UseNpgsql(connectionString, npgsql =>
                {
                    npgsql.MigrationsAssembly(typeof(ApplicationDbContext).Assembly.FullName);
                    npgsql.UseNetTopologySuite();
                })
                // Npgsql 6+ rejects DateTimeOffset with non-UTC offsets when
                // writing to timestamptz columns. This interceptor normalizes
                // all DateTimeOffset values to UTC before they reach the driver.
                .AddInterceptors(new UtcDateTimeOffsetInterceptor()));
        }

        services.AddScoped<IApplicationDbContext>(sp => sp.GetRequiredService<ApplicationDbContext>());
        services.AddScoped(typeof(Domain.Interfaces.IRepository<>), typeof(EfRepository<>));

        var redisConnectionString = configuration.GetConnectionString("Redis");
        if (string.IsNullOrWhiteSpace(redisConnectionString))
        {
            services.AddDistributedMemoryCache();
            services.AddSingleton<IDistributedLock, InMemoryDistributedLock>();
        }
        else
        {
            services.AddStackExchangeRedisCache(options => options.Configuration = redisConnectionString);
            services.AddSingleton<StackExchange.Redis.IConnectionMultiplexer>(_ =>
                StackExchange.Redis.ConnectionMultiplexer.Connect(redisConnectionString));
            services.AddSingleton<IDistributedLock, RedisDistributedLock>();
        }

        services.AddSingleton<RedisCacheService>();
        services.AddSingleton<IAvailabilityCache, AvailabilityCache>();

        // OTP rate limiter: 3 requests per 15 minutes per IP and per phone.
        // Backed by IDistributedCache (Redis in production, in-memory in dev).
        services.AddScoped<IOtpRateLimiter, OtpRateLimiter>();

        // Distributed-transaction safety net: automatic refunds and idempotency.
        services.AddScoped<IPaymentRefundService, PaymentRefundService>();
        services.AddScoped<IIdempotencyService, IdempotencyService>();

        // SMS sender: toggle via Sms:UseMock (true = Console, false = Fast2SMS)
        var smsUseMock = configuration.GetValue("Sms:UseMock", true);

        // OTP service: when SMS is in mock/test mode, also enable plaintext
        // peek so the Flutter app can autofill codes during testing.
        services.AddScoped<IOtpService>(sp => new OtpService(
            sp.GetRequiredService<IDistributedCache>(),
            testMode: smsUseMock));

        if (smsUseMock)
        {
            services.AddScoped<ISmsSender, ConsoleSmsSender>();
        }
        else
        {
            services.AddHttpClient<Fast2SmsSender>();
            services.AddScoped<ISmsSender, Fast2SmsSender>();
        }

        services.AddScoped<IUserResolver, UserResolver>();

        // Audit logger for admin super-app actions
        services.AddScoped<IAdminActionLogger, AdminActionLogger>();

        // Social login token verifiers
        services.AddScoped<IGoogleTokenVerifier, GoogleTokenVerifier>();

        // WhatsApp outbound: register the message sender alongside the
        // pre-configured HttpClient (base address set in Program.cs).
        services.AddScoped<IWhatsAppSender, WhatsAppMessageSender>();

        // OCR document verification: pluggable Google Vision / AWS Textract.
        services.AddScoped<IDocumentVerificationService, DocumentVerificationService>();

        var ocrProvider = configuration.GetValue<string>("Ocr:Provider") ?? "None";
        if (string.Equals(ocrProvider, "GoogleVision", StringComparison.OrdinalIgnoreCase))
        {
            var googleCredentials = configuration.GetValue<string>("Ocr:GoogleCredentials");
            var googleCredentialsPath = configuration.GetValue<string>("Ocr:GoogleCredentialsPath");

            if (!string.IsNullOrWhiteSpace(googleCredentials) ||
                (!string.IsNullOrWhiteSpace(googleCredentialsPath) && File.Exists(googleCredentialsPath)))
            {
                services.AddSingleton<ImageAnnotatorClient>(_ =>
                {
                    GoogleCredential credential;
                    if (!string.IsNullOrWhiteSpace(googleCredentials))
                    {
                        credential = GoogleCredential.FromJson(googleCredentials!);
                    }
                    else
                    {
                        credential = GoogleCredential.FromFile(googleCredentialsPath!);
                    }

                    return new ImageAnnotatorClientBuilder { Credential = credential }.Build();
                });
            }
        }

        services.Configure<Services.JwtTokenOptions>(configuration.GetSection(Services.JwtTokenOptions.SectionName));
        services.AddScoped<IJwtTokenFactory, JwtTokenFactory>();

        // Payment gateway: toggle via Payments:UseMock (true = Noop, false = Razorpay)
        services.Configure<RazorpayOptions>(configuration.GetSection(RazorpayOptions.SectionName));
        services.AddHttpClient<RazorpayGateway>();
        services.AddScoped<NoopPaymentGateway>();
        var paymentsUseMock = configuration.GetValue("Payments:UseMock", true);
        services.AddScoped<IPaymentGateway>(sp =>
        {
            if (paymentsUseMock)
                return sp.GetRequiredService<NoopPaymentGateway>();
            return sp.GetRequiredService<RazorpayGateway>();
        });

        // Storage service: toggle via Storage:UseMock (true = Local, false = AWS S3)
        services.Configure<StorageOptions>(configuration.GetSection(StorageOptions.SectionName));
        var storageUseMock = configuration.GetValue("Storage:UseMock", true);
        if (storageUseMock)
        {
            services.AddScoped<IStorageService, LocalFileStorageService>();
        }
        else
        {
            services.AddDefaultAWSOptions(new AWSOptions
            {
                Region = Amazon.RegionEndpoint.GetBySystemName(
                    configuration.GetValue<string>("Storage:Region") ?? "ap-south-1"),
            });
            services.AddAWSService<Amazon.S3.IAmazonS3>();
            services.AddScoped<IStorageService, AwsS3StorageService>();
        }

        services.AddScoped<DataInitializer>();

        // OSRM routing service for server-side distance validation and route geometry
        services.AddHttpClient<IRoutingService, OsrmRoutingService>((sp, client) =>
        {
            var config = sp.GetRequiredService<IConfiguration>();
            var baseUrl = config.GetValue<string>("Osrm:BaseUrl") ?? "https://router.project-osrm.org";
            client.BaseAddress = new Uri(baseUrl);
            client.Timeout = TimeSpan.FromSeconds(10);
            client.DefaultRequestHeaders.Add("User-Agent", "PondyConnect/1.0");
        });

        return services;
    }
}