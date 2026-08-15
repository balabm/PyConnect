namespace PondyConnect.Application.Features.Support;

using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;

public sealed class UserContextService
{
    private static readonly JsonSerializerOptions s_jsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    private readonly IApplicationDbContext _context;

    public UserContextService(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<string> GetActiveBookingsJsonAsync(Guid userId, CancellationToken cancellationToken)
    {
        var cutoff = DateTimeOffset.UtcNow.AddHours(-24);

        var bookings = await _context.ServiceBookings
            .Where(b => b.UserId == userId
                && (b.Status == BookingStatus.Pending
                    || b.Status == BookingStatus.Confirmed
                    || b.Status == BookingStatus.CheckedIn))
            .ToListAsync(cancellationToken);

        var filtered = bookings
            .Where(b => b.ScheduledFor >= cutoff)
            .Select(b => new
            {
                type = b.ServiceType.ToString(),
                status = b.Status.ToString(),
                scheduledFor = b.ScheduledFor,
                totalAmount = b.TotalAmount,
                checkInDate = b.CheckInDate,
                checkOutDate = b.CheckOutDate
            })
            .ToList();

        return JsonSerializer.Serialize(filtered, s_jsonOptions);
    }
}
