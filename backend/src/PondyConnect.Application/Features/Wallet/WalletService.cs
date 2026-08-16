namespace PondyConnect.Application.Features.Wallet;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

/// <summary>
/// Manages the per-driver cash-collection ledger wallet. Tracks platform
/// commission owed by the driver for Cash-on-Delivery rides/orders. When the
/// balance breaches the hard limit the wallet is suspended, blocking the
/// driver from going online until dues are settled via Razorpay top-up.
/// </summary>
public sealed class WalletService
{
    public const int RecentTransactionCount = 20;

    private readonly IApplicationDbContext _context;
    private readonly IPaymentGateway _paymentGateway;
    private readonly ILogger<WalletService> _logger;

    public WalletService(
        IApplicationDbContext context,
        IPaymentGateway paymentGateway,
        ILogger<WalletService> logger)
    {
        _context = context;
        _paymentGateway = paymentGateway;
        _logger = logger;
    }

    /// <summary>
    /// Returns the driver's wallet, creating it if it does not yet exist.
    /// </summary>
    public async Task<DriverWallet> GetOrCreateWalletAsync(Guid driverId, CancellationToken ct = default)
    {
        if (driverId == Guid.Empty)
            throw new ArgumentException("Driver ID is required.", nameof(driverId));

        var wallet = await _context.DriverWallets
            .FirstOrDefaultAsync(w => w.DriverId == driverId, ct);

        if (wallet is null)
        {
            wallet = DriverWallet.Create(driverId);
            _context.DriverWallets.Add(wallet);
            await _context.SaveChangesAsync(ct);
            _logger.WalletCreated(driverId);
        }

        return wallet;
    }

    /// <summary>
    /// Debits the platform commission for a COD ride/order from the driver's
    /// wallet and records a Commission transaction. The commission is the
    /// platform's cut from the cash collected by the driver.
    /// </summary>
    public async Task RecordCommissionAsync(
        Guid driverId,
        decimal commissionAmount,
        string referenceId,
        string description,
        CancellationToken ct = default)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(commissionAmount);

        await using var transaction = await _context.BeginTransactionAsync(ct);

        var wallet = await GetOrCreateWalletAsync(driverId, ct);

        // Acquire a row lock on PostgreSQL to prevent concurrent commission
        // deductions from racing on the same wallet.
        if (_context.IsPostgreSQL && transaction is not null)
            await _context.AcquireRowLockAsync("driver_wallets", wallet.Id, ct);

        wallet.Debit(commissionAmount);

        var txn = DriverWalletTransaction.Create(
            wallet.Id,
            DriverWalletTransactionType.Commission,
            -commissionAmount,
            description,
            referenceId);

        _context.DriverWalletTransactions.Add(txn);
        await _context.SaveChangesAsync(ct);

        if (transaction is not null)
            await transaction.CommitAsync(ct);

        _logger.CommissionRecorded(driverId, commissionAmount, referenceId);
    }

    /// <summary>
    /// Suspends the wallet if the balance has reached or breached the hard
    /// limit. Returns true if the suspension state changed.
    /// </summary>
    public async Task<bool> CheckAndSuspendIfNeededAsync(Guid driverId, CancellationToken ct = default)
    {
        var wallet = await GetOrCreateWalletAsync(driverId, ct);

        if (wallet.Balance <= wallet.HardLimit && !wallet.Suspended)
        {
            wallet.SuspendIfAtHardLimit();
            await _context.SaveChangesAsync(ct);
            _logger.WalletSuspended(driverId, wallet.Balance, wallet.HardLimit);
            return true;
        }

        return false;
    }

    /// <summary>
    /// Initiates a Razorpay top-up order for the specified amount (in rupees).
    /// Returns the provider order ID that the client uses to open checkout.
    /// </summary>
    public async Task<TopUpOrderResult> InitiateTopUpAsync(
        Guid driverId,
        decimal amount,
        CancellationToken ct = default)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(amount);

        // Ensure the wallet exists so we can link the top-up.
        _ = await GetOrCreateWalletAsync(driverId, ct);

        var receipt = $"wallet-topup-{driverId.ToString().Substring(0, 8)}-{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}";
        var order = await _paymentGateway.CreateOrderAsync(amount, "INR", receipt, ct);

        if (!order.Success || order.OrderId is null)
            throw new InvalidOperationException(order.ErrorMessage ?? "Failed to create Razorpay order for wallet top-up.");

        return new TopUpOrderResult(order.OrderId, amount, "INR");
    }

    /// <summary>
    /// Verifies a Razorpay payment and credits the wallet with the top-up
    /// amount. Clears the Suspended flag when the balance returns to >= 0.
    /// </summary>
    public async Task<bool> TopUpAsync(
        Guid driverId,
        decimal amount,
        string razorpayPaymentId,
        string razorpayOrderId,
        string? razorpaySignature,
        CancellationToken ct = default)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(amount);
        ArgumentException.ThrowIfNullOrWhiteSpace(razorpayPaymentId);
        ArgumentException.ThrowIfNullOrWhiteSpace(razorpayOrderId);

        // Verify the Razorpay payment signature before crediting.
        var valid = await _paymentGateway.VerifyPaymentSignatureAsync(
            razorpayOrderId, razorpayPaymentId, razorpaySignature ?? string.Empty, ct);

        if (!valid)
        {
            _logger.TopUpSignatureFailed(driverId, razorpayOrderId);
            return false;
        }

        await using var transaction = await _context.BeginTransactionAsync(ct);

        var wallet = await GetOrCreateWalletAsync(driverId, ct);

        if (_context.IsPostgreSQL && transaction is not null)
            await _context.AcquireRowLockAsync("driver_wallets", wallet.Id, ct);

        wallet.Credit(amount);

        var txn = DriverWalletTransaction.Create(
            wallet.Id,
            DriverWalletTransactionType.TopUp,
            amount,
            $"Wallet top-up via Razorpay ({razorpayPaymentId})",
            razorpayPaymentId);

        _context.DriverWalletTransactions.Add(txn);
        await _context.SaveChangesAsync(ct);

        if (transaction is not null)
            await transaction.CommitAsync(ct);

        _logger.TopUpProcessed(driverId, amount, razorpayPaymentId);
        return true;
    }

    /// <summary>
    /// Returns the driver's wallet with recent transactions.
    /// </summary>
    public async Task<DriverWalletDetail?> GetWalletAsync(Guid driverId, CancellationToken ct = default)
    {
        var wallet = await _context.DriverWallets
            .AsNoTracking()
            .FirstOrDefaultAsync(w => w.DriverId == driverId, ct);

        if (wallet is null)
        {
            // Lazily create so the first GET returns a zero-balance wallet.
            wallet = await GetOrCreateWalletAsync(driverId, ct);
            // Re-query as no-tracking for a clean detached read.
            wallet = await _context.DriverWallets
                .AsNoTracking()
                .FirstAsync(w => w.DriverId == driverId, ct);
        }

        var transactions = await _context.DriverWalletTransactions
            .AsNoTracking()
            .Where(t => t.WalletId == wallet.Id)
            .OrderByDescending(t => t.CreatedAt)
            .Take(RecentTransactionCount)
            .Select(t => new WalletTransactionSummary(
                t.Id,
                t.Type.ToString(),
                t.Amount,
                t.Description,
                t.ReferenceId,
                t.CreatedAt))
            .ToListAsync(ct);

        return new DriverWalletDetail(
            wallet.Id,
            wallet.Balance,
            wallet.HardLimit,
            wallet.Currency,
            wallet.Suspended,
            wallet.LastSettledAt,
            transactions);
    }
}

/// <summary>Result of initiating a Razorpay top-up order.</summary>
public sealed record TopUpOrderResult(string OrderId, decimal Amount, string Currency);

/// <summary>Wallet state with recent transactions, returned by GET /api/driver/wallet.</summary>
public sealed record DriverWalletDetail(
    Guid Id,
    decimal Balance,
    decimal HardLimit,
    string Currency,
    bool Suspended,
    DateTimeOffset? LastSettledAt,
    IReadOnlyList<WalletTransactionSummary> RecentTransactions);

/// <summary>A single wallet ledger entry.</summary>
public sealed record WalletTransactionSummary(
    Guid Id,
    string Type,
    decimal Amount,
    string Description,
    string? ReferenceId,
    DateTimeOffset CreatedAt);

internal static partial class WalletServiceLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Driver wallet created for {DriverId}")]
    public static partial void WalletCreated(this ILogger logger, Guid driverId);

    [LoggerMessage(Level = LogLevel.Information, Message = "Commission ₹{Amount} recorded for driver {DriverId} (ref: {ReferenceId})")]
    public static partial void CommissionRecorded(this ILogger logger, Guid driverId, decimal amount, string referenceId);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Wallet suspended for driver {DriverId}: balance {Balance} reached hard limit {HardLimit}")]
    public static partial void WalletSuspended(this ILogger logger, Guid driverId, decimal balance, decimal hardLimit);

    [LoggerMessage(Level = LogLevel.Information, Message = "Wallet top-up ₹{Amount} processed for driver {DriverId} (payment: {PaymentId})")]
    public static partial void TopUpProcessed(this ILogger logger, Guid driverId, decimal amount, string paymentId);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Top-up signature verification failed for driver {DriverId} (order: {OrderId})")]
    public static partial void TopUpSignatureFailed(this ILogger logger, Guid driverId, string orderId);
}
