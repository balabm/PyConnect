namespace PondyConnect.Application.Common.Behaviours;

using System.Security;
using FluentValidation;
using MediatR;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Features.Bookings;
using PondyConnect.Application.Features.GeoFence;

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

    private static readonly Action<ILogger, string, Exception?> s_failedWarning =
        LoggerMessage.Define<string>(
            LogLevel.Warning,
            new EventId(3, "RequestFailed"),
            "Request {RequestName} failed (expected business exception)");

    private static readonly Action<ILogger, string, Exception?> s_failedError =
        LoggerMessage.Define<string>(
            LogLevel.Error,
            new EventId(4, "RequestFailed"),
            "Request {RequestName} failed (unexpected)");

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
            // Expected business exceptions are handled by ExceptionHandlingMiddleware
            // and returned as proper 4xx responses — log at Warning, not Error.
            if (IsExpectedBusinessException(ex))
            {
                s_failedWarning(_logger, requestName, ex);
            }
            else
            {
                s_failedError(_logger, requestName, ex);
            }
            throw;
        }
    }

    /// <summary>
    /// Returns true for exceptions that represent expected business rule violations
    /// or client errors (4xx), not infrastructure/system failures (5xx).
    /// </summary>
    private static bool IsExpectedBusinessException(Exception ex) =>
        ex is ValidationException
            or UnauthorizedAccessException
            or SecurityException
            or InvalidOperationException
            or ArgumentException
            or ServiceAreaException
            or BookingConflictException;
}