namespace PondyConnect.Infrastructure;

using System.Data.Common;
using Microsoft.EntityFrameworkCore.Diagnostics;

/// <summary>
/// Normalizes all <see cref="DateTimeOffset"/> parameter values to UTC
/// before they are sent to PostgreSQL. Npgsql 6+ rejects non-UTC offsets
/// for <c>timestamp with time zone</c> columns, so this interceptor acts
/// as a safety net to convert any stray IST-offset values to UTC.
/// </summary>
internal sealed class UtcDateTimeOffsetInterceptor : DbCommandInterceptor
{
    public override ValueTask<InterceptionResult<DbDataReader>> ReaderExecutingAsync(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<DbDataReader> result,
        CancellationToken cancellationToken = default)
    {
        NormalizeParameters(command);
        return base.ReaderExecutingAsync(command, eventData, result, cancellationToken);
    }

    public override ValueTask<InterceptionResult<int>> NonQueryExecutingAsync(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<int> result,
        CancellationToken cancellationToken = default)
    {
        NormalizeParameters(command);
        return base.NonQueryExecutingAsync(command, eventData, result, cancellationToken);
    }

    public override ValueTask<InterceptionResult<object>> ScalarExecutingAsync(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<object> result,
        CancellationToken cancellationToken = default)
    {
        NormalizeParameters(command);
        return base.ScalarExecutingAsync(command, eventData, result, cancellationToken);
    }

    private static void NormalizeParameters(DbCommand command)
    {
        foreach (DbParameter? param in command.Parameters)
        {
            if (param is null) continue;
            if (param.Value is DateTimeOffset dto && dto.Offset != TimeSpan.Zero)
            {
                param.Value = dto.ToUniversalTime();
            }
        }
    }
}
