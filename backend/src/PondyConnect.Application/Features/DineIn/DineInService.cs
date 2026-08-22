namespace PondyConnect.Application.Features.DineIn;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using System.Globalization;

/// <summary>
/// Manages dine-in QR ordering: session creation, active session detection,
/// and routing orders directly to the KDS tablet without captain dispatch.
/// </summary>
public sealed class DineInService
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<DineInService> _logger;

    public DineInService(
        IApplicationDbContext context,
        ILogger<DineInService> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Finds an active dine-in session for a given table at a venue.
    /// Returns null if no active session exists (new customer).
    /// </summary>
    public async Task<DineInSession?> GetActiveSessionAsync(
        Guid venueId,
        int tableId,
        CancellationToken ct = default)
    {
        return await _context.DineInSessions
            .Where(s => s.VenueId == venueId
                && s.TableId == tableId
                && s.Status == DineInSessionStatus.Active)
            .OrderByDescending(s => s.OpenedAt)
            .FirstOrDefaultAsync(ct);
    }

    /// <summary>
    /// Opens a new dine-in session when a customer scans the QR code
    /// and no active session exists for that table.
    /// </summary>
    public async Task<DineInSession> OpenSessionAsync(
        Guid venueId,
        Guid vendorId,
        int tableId,
        Guid userId,
        CancellationToken ct = default)
    {
        // Check for existing active session
        var existing = await GetActiveSessionAsync(venueId, tableId, ct);
        if (existing is not null)
        {
            _logger.LogInformation(
                "Active session {SessionId} already exists for table {TableId} at venue {VenueId}",
                existing.Id, tableId, venueId);
            return existing;
        }

        var session = DineInSession.Create(venueId, vendorId, tableId, userId);
        _context.DineInSessions.Add(session);
        await _context.SaveChangesAsync(ct);

        _logger.LogInformation(
            "Opened dine-in session {SessionId} for table {TableId} at venue {VenueId}",
            session.Id, tableId, venueId);

        return session;
    }

    /// <summary>
    /// Attaches the first order to a session as the root KDS ticket.
    /// Subsequent "add to order" items are grouped under this ticket.
    /// </summary>
    public async Task AttachRootOrderAsync(
        Guid sessionId,
        Guid orderId,
        decimal orderTotal,
        CancellationToken ct = default)
    {
        var session = await _context.DineInSessions
            .FirstOrDefaultAsync(s => s.Id == sessionId, ct);

        if (session is null)
        {
            _logger.LogWarning("Dine-in session {SessionId} not found", sessionId);
            return;
        }

        session.AttachRootOrder(orderId);
        session.AddSettledAmount(orderTotal);
        await _context.SaveChangesAsync(ct);
    }

    /// <summary>
    /// Adds a subsequent order's total to an existing session
    /// (the "add to order" flow — dessert 30 minutes later).
    /// </summary>
    public async Task AddToSessionAsync(
        Guid sessionId,
        decimal orderTotal,
        CancellationToken ct = default)
    {
        var session = await _context.DineInSessions
            .FirstOrDefaultAsync(s => s.Id == sessionId, ct);

        if (session is null)
        {
            _logger.LogWarning("Dine-in session {SessionId} not found", sessionId);
            return;
        }

        session.AddSettledAmount(orderTotal);
        await _context.SaveChangesAsync(ct);
    }

    /// <summary>
    /// Closes a dine-in session when the bill is settled.
    /// </summary>
    public async Task CloseSessionAsync(
        Guid sessionId,
        CancellationToken ct = default)
    {
        var session = await _context.DineInSessions
            .FirstOrDefaultAsync(s => s.Id == sessionId, ct);

        if (session is null) return;

        session.Close();
        await _context.SaveChangesAsync(ct);

        _logger.LogInformation(
            "Closed dine-in session {SessionId}, total settled: {Total}",
            sessionId, session.TotalSettled.ToString("N2", CultureInfo.InvariantCulture));
    }

    /// <summary>
    /// Returns the root order ID for an active session, or null.
    /// Used by the "add to order" flow to group items under the existing KDS ticket.
    /// </summary>
    public async Task<Guid?> GetRootOrderIdAsync(
        Guid venueId,
        int tableId,
        CancellationToken ct = default)
    {
        var session = await GetActiveSessionAsync(venueId, tableId, ct);
        return session?.RootOrderId;
    }
}
