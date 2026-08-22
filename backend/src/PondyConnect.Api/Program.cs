using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using PondyConnect.Api;
using PondyConnect.Api.Hubs;
using PondyConnect.Api.Middleware;
using PondyConnect.Api.Services;
using PondyConnect.Application;
using PondyConnect.Application.Features.Auth;
using PondyConnect.Application.Features.GeoFence;
using PondyConnect.Application.Features.FoodDelivery;
using PondyConnect.Application.Features.Notifications;
using PondyConnect.Application.Features.Payments;
using PondyConnect.Application.Features.Dispatch;
using PondyConnect.Application.Features.RideHailing;
using PondyConnect.Application.Features.Telemetry;
using PondyConnect.Application.Features.Wallet;
using PondyConnect.Application.Features.Vendor;
using PondyConnect.Application.Services;
using PondyConnect.Infrastructure;
using PondyConnect.Infrastructure.Configuration;
using PondyConnect.Infrastructure.Persistence;
using PondyConnect.Infrastructure.Services;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

// In production, force Fast2SMS unless explicitly overridden via Sms:Provider
if (builder.Environment.IsProduction() &&
    string.IsNullOrWhiteSpace(builder.Configuration["Sms:Provider"]))
{
    builder.Configuration["Sms:Provider"] = "Fast2SMS";
}

builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);

builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<PondyConnect.Application.Common.Interfaces.ICurrentUserService, CurrentUserService>();

builder.Services.Configure<ServiceAreaOptions>(builder.Configuration.GetSection("ServiceArea"));
builder.Services.AddScoped<ServiceAreaValidator>();
builder.Services.AddSingleton<DriverLocationStore>();
builder.Services.AddSingleton<PondyConnect.Application.Common.Interfaces.IDriverLocationCache>(sp => sp.GetRequiredService<DriverLocationStore>());
builder.Services.AddScoped<DispatchEngine>();
builder.Services.AddScoped<RideDispatchService>();
builder.Services.AddScoped<PondyConnect.Application.Features.RideHailing.DispatchTaskService>();
builder.Services.AddScoped<BatchingService>();
builder.Services.AddScoped<FoodDeliveryDispatchService>();
builder.Services.AddScoped<PondyConnect.Application.Common.Interfaces.IFoodDeliveryDispatchService, FoodDeliveryDispatchService>();
builder.Services.AddScoped<PondyConnect.Application.Features.Support.ICriticalTicketBroadcaster, CriticalTicketBroadcaster>();
builder.Services.AddSignalR();
builder.Services.AddHostedService<FlashPromoExpiryWorker>();
builder.Services.AddHostedService<ScheduledPayoutWorker>();
builder.Services.AddHostedService<TelemetryBatchProcessor>();
builder.Services.AddHostedService<PaymentReconciliationWorker>();
builder.Services.AddHostedService<FraudDetectionWorker>();
builder.Services.AddHostedService<TripMonitoringWorker>();
builder.Services.AddHostedService<OrderEscalationWorker>();
builder.Services.AddScoped<DriverPayoutService>();
builder.Services.AddScoped<WalletService>();
builder.Services.AddScoped<AccountDeletionService>();
builder.Services.AddScoped<FoodCancellationService>();
builder.Services.AddScoped<PondyConnect.Application.Features.Homestays.InventoryService>();
builder.Services.AddHostedService<InventoryLockCleanupService>();
builder.Services.AddScoped<PondyConnect.Application.Features.Wallet.LoyaltyService>();
builder.Services.AddHostedService<WalletMonitorWorker>();
builder.Services.AddScoped<PondyConnect.Application.Features.Admin.SystemConfigService>();
builder.Services.AddScoped<PondyConnect.Application.Features.RideHailing.TripLifecycleService>();
builder.Services.AddHostedService<KdsThrottlingWorker>();
builder.Services.AddHostedService<MonthlyInvoiceWorker>();
builder.Services.AddHostedService<SettlementWorker>();
builder.Services.AddHostedService<PondyConnect.Application.Services.SubscriptionWorker>();
builder.Services.AddHostedService<PondyConnect.Application.Services.RiskScoringWorker>();
builder.Services.AddHostedService<PondyConnect.Api.Services.DriverSimulationWorker>();
builder.Services.AddScoped<PondyConnect.Application.Features.Rental.RentalDepositService>();
builder.Services.AddScoped<PondyConnect.Application.Features.Referral.ReferralService>();
builder.Services.AddScoped<PondyConnect.Application.Features.Invoicing.InvoiceService>();
builder.Services.AddScoped<PondyConnect.Application.Features.Ledger.LedgerService>();
builder.Services.AddScoped<PondyConnect.Application.Features.Settlement.SettlementService>();
builder.Services.AddScoped<PondyConnect.Application.Features.Settlement.ChargebackService>();
builder.Services.AddScoped<PondyConnect.Application.Features.DineIn.DineInService>();
builder.Services.AddScoped<PondyConnect.Application.Features.Subscriptions.SubscriptionService>();
builder.Services.AddScoped<PondyConnect.Application.Features.Fraud.RiskScoringService>();
builder.Services.AddScoped<PondyConnect.Application.Features.Fraud.RiskInterceptor>();
builder.Services.AddScoped<PondyConnect.Application.Features.CrossSell.CrossSellService>();

builder.Services.Configure<WhatsAppOptions>(builder.Configuration.GetSection(WhatsAppOptions.SectionName));
builder.Services.AddHttpClient<WhatsAppHttpClient>(client =>
{
    client.BaseAddress = new Uri("https://graph.facebook.com/v18.0/");
});

var firebaseOptions = builder.Configuration.GetSection(FirebaseOptions.SectionName)
    .Get<FirebaseOptions>() ?? new FirebaseOptions();
builder.Services.Configure<FirebaseOptions>(builder.Configuration.GetSection(FirebaseOptions.SectionName));

if (firebaseOptions.IsEnabled && !string.IsNullOrWhiteSpace(firebaseOptions.ServiceAccountPath))
{
    builder.Services.AddScoped<INotificationService, FirebaseNotificationService>();
}
else
{
    builder.Services.AddScoped<INotificationService, MockNotificationService>();
}

var rateLimitConfig = builder.Configuration
    .GetSection("RateLimiting")
    .Get<RateLimitingOptions>() ?? new RateLimitingOptions();

builder.Services.AddRateLimiter(options =>
{
    // Auth/OTP policy: 3 requests per 15-minute window, partitioned by IP or
    // phone number (from request body) to prevent brute-force OTP attacks.
    // OTP endpoints additionally enforce per-IP and per-phone limits via
    // IOtpRateLimiter (see AuthController/VendorAuthController).
    options.AddFixedWindowLimiter("AuthPolicy", opt =>
    {
        opt.PermitLimit = rateLimitConfig.Auth.PermitLimit;
        opt.Window = TimeSpan.FromSeconds(rateLimitConfig.Auth.WindowSeconds);
        opt.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        opt.QueueLimit = rateLimitConfig.Auth.QueueLimit;
    });

    // Global API throttle: 100 requests per minute per IP to prevent DDoS.
    options.AddFixedWindowLimiter("GlobalPolicy", opt =>
    {
        opt.PermitLimit = rateLimitConfig.Global.PermitLimit;
        opt.Window = TimeSpan.FromSeconds(rateLimitConfig.Global.WindowSeconds);
        opt.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        opt.QueueLimit = rateLimitConfig.Global.QueueLimit;
    });

    // Order policy: 10 orders per minute (kept for existing controllers).
    options.AddFixedWindowLimiter("OrderPolicy", opt =>
    {
        opt.PermitLimit = 10;
        opt.Window = TimeSpan.FromSeconds(60);
        opt.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        opt.QueueLimit = 0;
    });

    // Apply GlobalPolicy as the default for all endpoints. Controllers with
    // a specific [EnableRateLimiting("AuthPolicy")] or ["OrderPolicy"] attribute
    // override this default.
    options.GlobalLimiter = System.Threading.RateLimiting.PartitionedRateLimiter.Create<HttpContext, string>(
        httpContext =>
        {
            var ip = httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
            return System.Threading.RateLimiting.RateLimitPartition.GetFixedWindowLimiter(
                ip,
                _ => new System.Threading.RateLimiting.FixedWindowRateLimiterOptions
                {
                    PermitLimit = rateLimitConfig.Global.PermitLimit,
                    Window = TimeSpan.FromSeconds(rateLimitConfig.Global.WindowSeconds),
                    QueueLimit = rateLimitConfig.Global.QueueLimit,
                });
        });

    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
});

builder.Services.AddControllers()
    .ConfigureApiBehaviorOptions(options =>
    {
        options.InvalidModelStateResponseFactory = context =>
        {
            // Return generic validation errors without leaking internal class names
            var errors = context.ModelState
                .Where(kvp => kvp.Value?.Errors.Count > 0)
                .ToDictionary(
                    kvp => kvp.Key,
                    kvp => kvp.Value!.Errors.Select(e => e.ErrorMessage).ToArray());

            return new BadRequestObjectResult(new { message = "Validation failed.", errors });
        };
    });
builder.Services.AddEndpointsApiExplorer();

builder.Services.AddCors(options =>
{
    if (builder.Environment.IsDevelopment())
    {
        options.AddPolicy("MobileClient", policy =>
        {
            policy.AllowAnyOrigin()
                .AllowAnyHeader()
                .AllowAnyMethod();
        });
    }
    else
    {
        // Production: strict CORS — only explicitly allowed origins.
        var allowedOrigins = builder.Configuration
            .GetSection("Cors:AllowedOrigins")
            .Get<string[]>() ?? [];

        options.AddPolicy("MobileClient", policy =>
        {
            policy.WithOrigins(allowedOrigins)
                .AllowAnyHeader()
                .AllowAnyMethod()
                .SetPreflightMaxAge(TimeSpan.FromHours(1));
        });
    }
});

builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo { Title = "PondyConnect API", Version = "v1" });
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme. Example: \"Authorization: Bearer {token}\"",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT"
    });
    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
            },
            Array.Empty<string>()
        }
    });
});

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        var jwt = builder.Configuration.GetSection(JwtTokenOptions.SectionName).Get<JwtTokenOptions>()
            ?? throw new InvalidOperationException("Jwt configuration is missing.");

        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwt.Issuer,
            ValidateAudience = true,
            ValidAudience = jwt.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromSeconds(30)
        };
    });

builder.Services.AddAuthorization();
var healthBuilder = builder.Services.AddHealthChecks()
    .AddDbContextCheck<PondyConnect.Infrastructure.Persistence.ApplicationDbContext>("database")
    .AddCheck("signalr", () => Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Healthy("SignalR hub mapped."), tags: ["signalr"]);


var redisConn = builder.Configuration.GetConnectionString("Redis");
if (!string.IsNullOrWhiteSpace(redisConn))
{
    // Redis is optional locally (in-memory lock/cache fallback). When present,
    // surface a lightweight connectivity check via the multiplexer.
    healthBuilder.AddCheck("redis", () =>
    {
        try
        {
            using var mux = StackExchange.Redis.ConnectionMultiplexer.Connect(redisConn);
            return mux.IsConnected
                ? Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Healthy()
                : Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Degraded("Redis not connected.");
        }
        catch (Exception ex)
        {
            return Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Unhealthy(ex.Message);
        }
    });
}

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
else
{
    app.UseHsts();
}

// Forwarded headers so the app correctly sees the original scheme/host
// when behind Nginx or another reverse proxy.
app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = Microsoft.AspNetCore.HttpOverrides.ForwardedHeaders.XForwardedFor | Microsoft.AspNetCore.HttpOverrides.ForwardedHeaders.XForwardedProto
});

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseCors("MobileClient");

app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();
app.UseMiddleware<ExceptionHandlingMiddleware>();

app.MapHealthChecks("/health", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
{
    ResponseWriter = async (context, report) =>
    {
        context.Response.ContentType = "application/json";
        var json = System.Text.Json.JsonSerializer.Serialize(new
        {
            status = report.Status.ToString(),
            checks = report.Entries.Select(e => new { e.Key, status = e.Value.Status.ToString() }),
            timestamp = DateTimeOffset.UtcNow
        });
        await context.Response.WriteAsync(json);
    }
});
app.MapControllers();
app.MapHub<DriverHub>("/hubs/driver");
app.MapHub<RideHub>("/hubs/ride");
app.MapHub<AdminHub>("/hubs/admin");
app.MapHub<VendorHub>("/hubs/vendor");

// Apply migrations + seed known venues on startup. Log a warning when the
// database is unreachable so local development can still boot the API.
using (var scope = app.Services.CreateScope())
{
    var initializer = scope.ServiceProvider.GetRequiredService<DataInitializer>();
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
    try
    {
        await initializer.InitializeAsync();
    }
    catch (Exception ex)
    {
        // Startup-only diagnostics; suppressed here because LoggerMessage
        // source generation is overkill for a one-time boot path.
#pragma warning disable CA1848
        logger.LogWarning(ex, "Database initialization skipped (is Postgres running?). API started without schema.");
#pragma warning restore CA1848
    }
}

app.Run();

public partial class Program { }