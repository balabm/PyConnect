namespace PondyConnect.Infrastructure.Services;

using System.Text.Json;
using Microsoft.AspNetCore.Http;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;

/// <summary>
/// Writes <see cref="AdminActionLog"/> records from the current HTTP context.
/// </summary>
public sealed class AdminActionLogger : IAdminActionLogger
{
    private static readonly JsonSerializerOptions s_jsonOptions = new(JsonSerializerDefaults.Web);

    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;
    private readonly IHttpContextAccessor _httpContextAccessor;

    public AdminActionLogger(
        IApplicationDbContext dbContext,
        ICurrentUserService currentUser,
        IHttpContextAccessor httpContextAccessor)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
        _httpContextAccessor = httpContextAccessor;
    }

    public async Task LogAsync(
        string actionType,
        string? entityType = null,
        Guid? entityId = null,
        object? payload = null,
        CancellationToken cancellationToken = default)
    {
        var adminUserId = _currentUser.UserId
            ?? throw new InvalidOperationException("Admin user ID is not available.");

        var payloadJson = payload is null
            ? null
            : JsonSerializer.Serialize(payload, s_jsonOptions);

        var ipAddress = _httpContextAccessor.HttpContext?.Connection?.RemoteIpAddress?.ToString()
            ?? _httpContextAccessor.HttpContext?.Request?.Headers["X-Forwarded-For"].FirstOrDefault();

        var log = AdminActionLog.Create(
            adminUserId,
            actionType,
            entityType,
            entityId,
            payloadJson,
            ipAddress);

        _dbContext.AdminActionLogs.Add(log);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }
}
