namespace PondyConnect.Infrastructure.Services;

using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Development-only SMS sink. Logs the message instead of dialling a real
/// gateway. Swap with Twilio/MSG91/TVO identity provider for production.
/// </summary>
public sealed class ConsoleSmsSender : ISmsSender
{
    private static readonly Action<ILogger, string, string, Exception?> s_send =
        LoggerMessage.Define<string, string>(
            LogLevel.Information,
            new EventId(1, "SmsSent"),
            "[SMS -> {Phone}] {Message}");

    private readonly ILogger<ConsoleSmsSender> _logger;

    public ConsoleSmsSender(ILogger<ConsoleSmsSender> logger)
    {
        _logger = logger;
    }

    public Task SendAsync(string phone, string message, CancellationToken cancellationToken = default)
    {
        s_send(_logger, phone, message, null);
        return Task.CompletedTask;
    }
}