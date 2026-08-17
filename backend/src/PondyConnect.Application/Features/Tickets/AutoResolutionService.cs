namespace PondyConnect.Application.Features.Tickets;

using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed record AutoResolutionResult(
    bool Resolved,
    decimal? CreditAmount,
    string? Note,
    SupportTicketStatus NewStatus);

public sealed class AutoResolutionService
{
    private readonly IApplicationDbContext _context;

    public AutoResolutionService(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<AutoResolutionResult> EvaluateAsync(
        DisputeTicket ticket,
        CancellationToken ct = default)
    {
        if (ticket.Category == SupportTicketCategory.ItemMissing)
        {
            if (!Guid.TryParse(ticket.UserId, out var userGuid))
                return new AutoResolutionResult(false, null, "Unable to verify account.", SupportTicketStatus.UnderReview);

            var user = await _context.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(u => u.Id == userGuid, ct);

            if (user is null)
                return new AutoResolutionResult(false, null, "User account not found.", SupportTicketStatus.UnderReview);

            var accountAge = DateTimeOffset.UtcNow - user.CreatedAt;

            var previousRefunds = await _context.DisputeTickets
                .CountAsync(t => t.UserId == ticket.UserId
                    && t.Status == SupportTicketStatus.AutoResolved
                    && t.ResolutionAmount.HasValue
                    && t.ResolutionAmount.Value > 0
                    && t.CreatedAt >= DateTimeOffset.UtcNow.AddDays(-90), ct);

            if (accountAge > TimeSpan.FromDays(30) && previousRefunds < 2)
            {
                var creditAmount = await ComputeMissingItemAmountAsync(ticket, ct);

                return new AutoResolutionResult(
                    true,
                    creditAmount,
                    "Wallet credit granted automatically for missing item. Admin review flagged.",
                    SupportTicketStatus.AutoResolved);
            }
        }

        if (ticket.Category == SupportTicketCategory.PaymentIssue)
        {
            return new AutoResolutionResult(
                false,
                null,
                "Payment issue requires manual review.",
                SupportTicketStatus.UnderReview);
        }

        return new AutoResolutionResult(false, null, null, SupportTicketStatus.Open);
    }

    private async Task<decimal> ComputeMissingItemAmountAsync(DisputeTicket ticket, CancellationToken ct)
    {
        if (ticket.OrderId is null)
            return 0m;

        if (string.Equals(ticket.OrderType, "FoodOrder", StringComparison.OrdinalIgnoreCase))
        {
            var order = await _context.FoodOrders
                .AsNoTracking()
                .FirstOrDefaultAsync(o => o.Id == ticket.OrderId, ct);

            if (order is not null)
            {
                var firstItem = order.Items.FirstOrDefault();
                if (firstItem is not null)
                    return firstItem.UnitPrice;

                return order.TotalAmount * 0.20m;
            }
        }

        return 0m;
    }
}
