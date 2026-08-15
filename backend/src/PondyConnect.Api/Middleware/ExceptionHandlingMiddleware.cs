namespace PondyConnect.Api.Middleware;

using System.Text.Json;
using FluentValidation;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Features.GeoFence;

public sealed partial class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    public ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            await HandleExceptionAsync(context, ex);
        }
    }

    private async Task HandleExceptionAsync(HttpContext context, Exception ex)
    {
        var (statusCode, response) = ex switch
        {
            ValidationException validationEx => (
                StatusCodes.Status422UnprocessableEntity,
                (object)new { message = "Validation failed.", errors = validationEx.Errors.Select(e => new { field = e.PropertyName, error = e.ErrorMessage }) }),
            ServiceAreaException serviceAreaEx => (
                StatusCodes.Status400BadRequest,
                (object)new { message = serviceAreaEx.Message, distanceKm = serviceAreaEx.DistanceKm, radiusKm = serviceAreaEx.RadiusKm }),
            UnauthorizedAccessException => (
                StatusCodes.Status401Unauthorized,
                (object)new { message = ex.Message }),
            InvalidOperationException => (
                StatusCodes.Status400BadRequest,
                (object)new { message = ex.Message }),
            ArgumentException => (
                StatusCodes.Status400BadRequest,
                (object)new { message = ex.Message }),
            JsonException => (
                StatusCodes.Status400BadRequest,
                (object)new { message = "Malformed JSON in request body." }),
            BadHttpRequestException badHttpEx => (
                StatusCodes.Status400BadRequest,
                (object)new { message = "Invalid request format." }),
            _ => (
                StatusCodes.Status500InternalServerError,
                (object)new { message = "An unexpected error occurred." })
        };

        if (statusCode == StatusCodes.Status500InternalServerError)
        {
            LogUnhandled(_logger, context.Request.Method, context.Request.Path, ex);
        }
        else
        {
            LogHandled(_logger, statusCode, context.Request.Method, context.Request.Path, ex);
        }

        context.Response.StatusCode = statusCode;
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsJsonAsync(response);
    }

    [LoggerMessage(Level = LogLevel.Error, Message = "Unhandled exception on {Method} {Path}")]
    static partial void LogUnhandled(ILogger logger, string method, string path, Exception ex);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Handled exception ({StatusCode}) on {Method} {Path}")]
    static partial void LogHandled(ILogger logger, int statusCode, string method, string path, Exception ex);
}
