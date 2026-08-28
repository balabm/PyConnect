namespace PondyConnect.Application;

using System.Reflection;
using FluentValidation;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PondyConnect.Application.Common.Behaviours;
using PondyConnect.Application.Features.Bookings;
using PondyConnect.Application.Features.Fraud;
using PondyConnect.Application.Features.Homestays;
using PondyConnect.Application.Features.Settlement;
using PondyConnect.Application.Features.Support;
using PondyConnect.Application.Features.RideHailing;
using PondyConnect.Application.Features.Telemetry;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services, IConfiguration? configuration = null)
    {
        var assembly = Assembly.GetExecutingAssembly();

        services.AddMediatR(cfg =>
        {
            cfg.RegisterServicesFromAssembly(assembly);
            cfg.AddOpenBehavior(typeof(ValidationBehaviour<,>));
            cfg.AddOpenBehavior(typeof(LoggingBehaviour<,>));
        });

        services.AddValidatorsFromAssembly(assembly);

        services.AddScoped<IBookingEngineService, BookingEngineService>();
        services.AddScoped<ISettlementCalculationService, SettlementCalculationService>();

        // LLM service: MockLlmService is the only implementation available.
        // It is registered unconditionally but clearly documented as a
        // placeholder. When a real LLM provider is integrated, gate this
        // behind a configuration flag (e.g. "Llm:Provider": "OpenAI").
        services.AddScoped<ILlmService, MockLlmService>();

        services.AddScoped<UserContextService>();
        services.AddScoped<MessageReceiverService>();

        services.AddSingleton<ChannelTelemetryService>();
        services.AddSingleton<ITelemetryService>(sp => sp.GetRequiredService<ChannelTelemetryService>());

        services.AddScoped<SurgeCalculator>();

        // Fraud prevention: cancellation tracking, shadow-bans, COD restrictions.
        services.AddScoped<IFraudDetectionService, FraudDetectionService>();

        return services;
    }
}