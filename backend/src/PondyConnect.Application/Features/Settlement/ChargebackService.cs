namespace PondyConnect.Application.Features.Settlement;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Ledger;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using System.Globalization;
using System.Text.Json;

/// <summary>
/// Handles chargeback disputes when a consumer issues a credit card
/// chargeback via their bank. Auto-generates an evidence dossier
/// containing order receipts, GPS logs, and delivery photos to
/// contest the chargeback.
/// </summary>
public sealed class ChargebackService
{
    private readonly IApplicationDbContext _context;
    private readonly LedgerService _ledgerService;
    private readonly ILogger<ChargebackService> _logger;

    public ChargebackService(IApplicationDbContext context, LedgerService ledgerService, ILogger<ChargebackService> logger)
    {
        _context = context;
        _ledgerService = ledgerService;
        _logger = logger;
    }

    /// <summary>
    /// Creates a chargeback dispute and auto-generates the evidence dossier.
    /// Freezes the user's account pending resolution.
    /// </summary>
    public async Task<ChargebackDispute> HandleChargebackAsync(
        Guid paymentId,
        decimal chargebackAmount,
        string? providerDisputeId = null,
        CancellationToken ct = default)
    {
        var payment = await _context.Payments.FirstOrDefaultAsync(p => p.Id == paymentId, ct)
            ?? throw new InvalidOperationException("Payment not found.");

        // Determine the order type and ID
        Guid? orderId = null;
        string? orderType = null;
        Guid userId = Guid.Empty;

        if (payment.FoodOrderId is not null)
        {
            orderId = payment.FoodOrderId;
            orderType = "FoodOrder";
            var order = await _context.FoodOrders.AsNoTracking().FirstOrDefaultAsync(o => o.Id == payment.FoodOrderId, ct);
            userId = order?.UserId ?? Guid.Empty;
        }
        else if (payment.ServiceBookingId is not null)
        {
            orderId = payment.ServiceBookingId;
            orderType = "ServiceBooking";
            var booking = await _context.ServiceBookings.AsNoTracking().FirstOrDefaultAsync(b => b.Id == payment.ServiceBookingId, ct);
            userId = booking?.UserId ?? Guid.Empty;
        }
        else if (payment.ScooterRentalId is not null)
        {
            orderId = payment.ScooterRentalId;
            orderType = "Rental";
        }

        if (userId == Guid.Empty)
        {
            // Try to get user from the order
            var foodOrder = await _context.FoodOrders.AsNoTracking().FirstOrDefaultAsync(o => o.Id == payment.FoodOrderId, ct);
            userId = foodOrder?.UserId ?? Guid.Empty;
        }

        // Create the chargeback dispute
        var dispute = ChargebackDispute.Create(
            paymentId,
            userId,
            chargebackAmount,
            orderId,
            orderType,
            providerDisputeId);

        _context.ChargebackDisputes.Add(dispute);

        // Generate the evidence dossier
        var evidence = await GenerateEvidenceDossierAsync(payment, orderId, orderType, ct);
        dispute.AttachEvidence(evidence.UrlsJson, evidence.Summary);

        // Record the chargeback in the double-entry ledger
        await _ledgerService.RecordRefundAsync(
            originalPaymentId: paymentId,
            referenceId: dispute.Id,
            referenceType: "Chargeback",
            refundAmount: chargebackAmount,
            ct: ct);

        await _context.SaveChangesAsync(ct);

        _logger.ChargebackCreated(paymentId, dispute.Id, chargebackAmount);

        return dispute;
    }

    private async Task<(string UrlsJson, string Summary)> GenerateEvidenceDossierAsync(
        Payment payment,
        Guid? orderId,
        string? orderType,
        CancellationToken ct)
    {
        var evidenceUrls = new List<string>();
        var summaryParts = new List<string>();

        summaryParts.Add($"Payment ID: {payment.Id}");
        summaryParts.Add($"Amount: ₹{payment.Amount.ToString("F2", CultureInfo.InvariantCulture)}");
        summaryParts.Add($"Provider Payment ID: {payment.ProviderPaymentId ?? "N/A"}");
        summaryParts.Add($"Captured At: {payment.CapturedAt?.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture) ?? "N/A"}");

        if (orderType == "FoodOrder" && orderId is not null)
        {
            var order = await _context.FoodOrders.AsNoTracking().FirstOrDefaultAsync(o => o.Id == orderId, ct);
            if (order is not null)
            {
                summaryParts.Add($"Order Status: {order.Status}");
                summaryParts.Add($"Delivery Address: {order.DeliveryAddress ?? "N/A"}");
                summaryParts.Add($"Total Amount: ₹{order.TotalAmount.ToString("F2", CultureInfo.InvariantCulture)}");

                // Check for proof of delivery photo
                if (!string.IsNullOrEmpty(order.DeliveryProofUrl))
                {
                    evidenceUrls.Add(order.DeliveryProofUrl);
                    summaryParts.Add("Proof of delivery photo attached");
                }
            }
        }
        else if (orderType == "Rental" && orderId is not null)
        {
            var rental = await _context.ScooterRentals.AsNoTracking().FirstOrDefaultAsync(r => r.Id == orderId, ct);
            if (rental is not null)
            {
                summaryParts.Add($"Rental Status: {rental.Status}");
                if (!string.IsNullOrEmpty(rental.ConditionPhotosJson))
                    evidenceUrls.Add("rental_condition_photos:" + rental.Id);
            }
        }

        var urlsJson = JsonSerializer.Serialize(evidenceUrls);
        var summary = string.Join("\n", summaryParts);

        return (urlsJson, summary);
    }

    /// <summary>
    /// Lists all chargeback disputes for the admin dashboard.
    /// </summary>
    public async Task<List<ChargebackDispute>> ListDisputesAsync(
        ChargebackStatus? statusFilter = null,
        CancellationToken ct = default)
    {
        var query = _context.ChargebackDisputes.AsNoTracking();

        if (statusFilter is not null)
            query = query.Where(d => d.Status == statusFilter.Value);

        return await query.OrderByDescending(d => d.CreatedAt).ToListAsync(ct);
    }

    /// <summary>
    /// Resolves a chargeback dispute (admin action).
    /// </summary>
    public async Task ResolveDisputeAsync(
        Guid disputeId,
        bool won,
        string note,
        CancellationToken ct = default)
    {
        var dispute = await _context.ChargebackDisputes.FirstOrDefaultAsync(d => d.Id == disputeId, ct)
            ?? throw new InvalidOperationException("Dispute not found.");

        if (won)
            dispute.MarkWon(note);
        else
            dispute.MarkLost(note);

        await _context.SaveChangesAsync(ct);
        _logger.ChargebackResolved(disputeId, won);
    }
}

internal static partial class ChargebackLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Warning, Message = "Chargeback created: Payment {PaymentId}, Dispute {DisputeId}, Amount: ₹{Amount}")]
    public static partial void ChargebackCreated(this ILogger logger, Guid paymentId, Guid disputeId, decimal amount);

    [LoggerMessage(Level = LogLevel.Information, Message = "Chargeback resolved: {DisputeId}, Won: {Won}")]
    public static partial void ChargebackResolved(this ILogger logger, Guid disputeId, bool won);
}
