namespace PondyConnect.Application.Common.Behaviours;

using MediatR;
using Microsoft.Extensions.Logging;

public sealed class LoggingBehaviour<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    private static readonly Action<ILogger, string, DateTimeOffset, Exception?> s_handling =
        LoggerMessage.Define<string, DateTimeOffset>(
            LogLevel.Information,
            new EventId(1, "RequestStart"),
            "Handling {RequestName} at {Timestamp:O}");

    private static readonly Action<ILogger, string, DateTimeOffset, Exception?> s_handled =
        LoggerMessage.Define<string, DateTimeOffset>(
            LogLevel.Information,
            new EventId(2, "RequestEnd"),
            "Handled {RequestName} at {Timestamp:O}");

    private static readonly Action<ILogger, string, Exception?> s_failed =
        LoggerMessage.Define<string>(
            LogLevel.Error,
            new EventId(3, "RequestFailed"),
            "Request {RequestName} failed");

    private readonly ILogger<LoggingBehaviour<TRequest, TResponse>> _logger;

    public LoggingBehaviour(ILogger<LoggingBehaviour<TRequest, TResponse>> logger)
    {
        _logger = logger;
    }

    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        var requestName = typeof(TRequest).Name;
        s_handling(_logger, requestName, DateTimeOffset.UtcNow, null);

        try
        {
            var response = await next();
            s_handled(_logger, requestName, DateTimeOffset.UtcNow, null);
            return response;
        }
        catch (Exception ex)
        {
            s_failed(_logger, requestName, ex);
            throw;
        }
    }
}