namespace PondyConnect.Application;

using System.Reflection;
using FluentValidation;
using Microsoft.Extensions.DependencyInjection;
using PondyConnect.Application.Common.Behaviours;
using PondyConnect.Application.Features.Bookings;
using PondyConnect.Application.Features.Homestays;
using PondyConnect.Application.Features.Settlement;
using PondyConnect.Application.Features.Support;
using PondyConnect.Application.Features.RideHailing;
using PondyConnect.Application.Features.Telemetry;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
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
        services.AddScoped<ILlmService, MockLlmService>();
        services.AddScoped<UserContextService>();
        services.AddScoped<MessageReceiverService>();

        services.AddSingleton<ChannelTelemetryService>();
        services.AddSingleton<ITelemetryService>(sp => sp.GetRequiredService<ChannelTelemetryService>());

        services.AddScoped<SurgeCalculator>();

        return services;
    }
}