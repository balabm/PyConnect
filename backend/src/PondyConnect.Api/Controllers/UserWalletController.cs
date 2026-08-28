namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

/// <summary>
/// Consumer PY Wallet endpoints. Exposes the user's promo balance, real
/// balance, PY Coins loyalty balance, and supports Razorpay top-ups.
/// </summary>
[ApiController]
[Route("api/user/wallet")]
[Authorize]
public sealed class UserWalletController : ControllerBase
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;
    private readonly IPaymentGateway _paymentGateway;

    public UserWalletController(
        IApplicationDbContext dbContext,
        ICurrentUserService currentUser,
        IPaymentGateway paymentGateway)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
        _paymentGateway = paymentGateway;
    }

    /// <summary>
    /// Returns the current user's wallet balance breakdown.
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(UserWalletDetail), StatusCodes.Status200OK)]
    public async Task<ActionResult<UserWalletDetail>> GetWallet(CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "User not authenticated." });

        var wallet = await _dbContext.UserWallets
            .AsNoTracking()
            .FirstOrDefaultAsync(w => w.UserId == userId, ct);

        if (wallet is null)
        {
            // Lazily report zero balance if the wallet hasn't been created yet.
            return Ok(new UserWalletDetail(
                PromoBalance: 0m,
                RealBalance: 0m,
                PyCoins: 0,
                TotalBalance: 0m));
        }

        return Ok(new UserWalletDetail(
            PromoBalance: wallet.PromoBalance,
            RealBalance: wallet.RealBalance,
            PyCoins: wallet.PyCoins,
            TotalBalance: wallet.PromoBalance + wallet.RealBalance));
    }

    /// <summary>
    /// Initiates a wallet top-up by creating a Razorpay order. The client
    /// completes checkout and calls <see cref="ConfirmTopUp"/> to credit
    /// the wallet after successful payment.
    /// </summary>
    [HttpPost("topup")]
    [ProducesResponseType(typeof(UserTopUpInitResult), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<UserTopUpInitResult>> InitiateTopUp(
        [FromBody] UserInitiateTopUpRequest request, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "User not authenticated." });

        if (request.Amount <= 0)
            return BadRequest(new { Message = "Amount must be greater than zero." });

        var receipt = $"wallet-{userId.Value.ToString().Substring(0, 8)}-{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}";
        var order = await _paymentGateway.CreateOrderAsync(
            request.Amount, "INR", receipt, capture: true, cancellationToken: ct);

        if (!order.Success || order.OrderId is null)
            return BadRequest(new { Message = order.ErrorMessage ?? "Failed to create payment order." });

        return Ok(new UserTopUpInitResult(order.OrderId, request.Amount));
    }

    /// <summary>
    /// Confirms a wallet top-up after successful Razorpay checkout. Verifies
    /// the payment signature and credits the real balance.
    /// </summary>
    [HttpPost("topup/confirm")]
    [ProducesResponseType(typeof(UserWalletDetail), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<UserWalletDetail>> ConfirmTopUp(
        [FromBody] UserConfirmTopUpRequest request, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "User not authenticated." });

        var valid = await _paymentGateway.VerifyPaymentSignatureAsync(
            request.RazorpayOrderId, request.RazorpayPaymentId, request.Signature, ct);

        if (!valid)
            return BadRequest(new { Message = "Invalid payment signature." });

        var wallet = await _dbContext.UserWallets
            .FirstOrDefaultAsync(w => w.UserId == userId, ct);

        if (wallet is null)
        {
            wallet = UserWallet.Create(userId.Value);
            _dbContext.UserWallets.Add(wallet);
        }

        wallet.CreditReal(request.Amount);

        // Record the transaction in the ledger.
        var transaction = UserWalletTransaction.Create(
            walletId: wallet.Id,
            type: UserWalletTransactionType.TopUp,
            amount: request.Amount,
            description: $"Wallet top-up via Razorpay ({request.RazorpayPaymentId})",
            referenceId: request.RazorpayPaymentId);
        _dbContext.UserWalletTransactions.Add(transaction);

        await _dbContext.SaveChangesAsync(ct);

        return Ok(new UserWalletDetail(
            PromoBalance: wallet.PromoBalance,
            RealBalance: wallet.RealBalance,
            PyCoins: wallet.PyCoins,
            TotalBalance: wallet.PromoBalance + wallet.RealBalance));
    }

    /// <summary>
    /// Transfers funds from the authenticated user's real balance to another
    /// user's wallet by phone number. Creates a debit transaction on the
    /// sender's wallet and a credit transaction on the recipient's wallet
    /// atomically.
    /// </summary>
    [HttpPost("transfer")]
    [ProducesResponseType(typeof(UserWalletDetail), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<UserWalletDetail>> Transfer(
        [FromBody] UserTransferRequest request, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "User not authenticated." });

        if (string.IsNullOrWhiteSpace(request.RecipientPhone))
            return BadRequest(new { Message = "Recipient phone is required." });

        if (request.Amount <= 0)
            return BadRequest(new { Message = "Amount must be greater than zero." });

        var senderWallet = await _dbContext.UserWallets
            .FirstOrDefaultAsync(w => w.UserId == userId, ct);

        if (senderWallet is null || senderWallet.RealBalance < request.Amount)
            return BadRequest(new { Message = "Insufficient real balance for transfer." });

        var recipientUser = await _dbContext.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Phone == request.RecipientPhone, ct);

        if (recipientUser is null)
            return NotFound(new { Message = "No user found with that phone number." });

        if (recipientUser.Id == userId.Value)
            return BadRequest(new { Message = "Cannot transfer to your own wallet." });

        var recipientWallet = await _dbContext.UserWallets
            .FirstOrDefaultAsync(w => w.UserId == recipientUser.Id, ct);

        if (recipientWallet is null)
        {
            recipientWallet = UserWallet.Create(recipientUser.Id);
            _dbContext.UserWallets.Add(recipientWallet);
        }

        senderWallet.DebitReal(request.Amount);
        recipientWallet.CreditReal(request.Amount);

        var senderTx = UserWalletTransaction.Create(
            walletId: senderWallet.Id,
            type: UserWalletTransactionType.TransferSent,
            amount: -request.Amount,
            description: $"P2P transfer to {request.RecipientPhone}",
            referenceId: recipientUser.Id.ToString());
        _dbContext.UserWalletTransactions.Add(senderTx);

        var recipientTx = UserWalletTransaction.Create(
            walletId: recipientWallet.Id,
            type: UserWalletTransactionType.TransferReceived,
            amount: request.Amount,
            description: $"P2P transfer from {_currentUser.Phone ?? "user"}",
            referenceId: userId.Value.ToString());
        _dbContext.UserWalletTransactions.Add(recipientTx);

        await _dbContext.SaveChangesAsync(ct);

        return Ok(new UserWalletDetail(
            PromoBalance: senderWallet.PromoBalance,
            RealBalance: senderWallet.RealBalance,
            PyCoins: senderWallet.PyCoins,
            TotalBalance: senderWallet.PromoBalance + senderWallet.RealBalance));
    }

    /// <summary>
    /// Returns the user's recent wallet transactions (ledger entries).
    /// </summary>
    [HttpGet("transactions")]
    [ProducesResponseType(typeof(IReadOnlyList<UserWalletTransactionResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<IReadOnlyList<UserWalletTransactionResponse>>> GetTransactions(
        [FromQuery] int limit = 50, CancellationToken ct = default)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "User not authenticated." });

        var wallet = await _dbContext.UserWallets
            .AsNoTracking()
            .FirstOrDefaultAsync(w => w.UserId == userId, ct);

        if (wallet is null)
            return Ok(new List<UserWalletTransactionResponse>());

        var transactions = await _dbContext.UserWalletTransactions
            .AsNoTracking()
            .Where(t => t.WalletId == wallet.Id)
            .OrderByDescending(t => t.CreatedAt)
            .Take(limit)
            .Select(t => new UserWalletTransactionResponse(
                t.Id,
                t.Type.ToString(),
                t.Amount,
                t.Description,
                t.ReferenceId,
                t.CreatedAt))
            .ToListAsync(ct);

        return Ok(transactions);
    }
}

/// <summary>
/// Consumer wallet balance breakdown.
/// </summary>
public sealed record UserWalletDetail(
    decimal PromoBalance,
    decimal RealBalance,
    int PyCoins,
    decimal TotalBalance);

public sealed record UserInitiateTopUpRequest(decimal Amount);

public sealed record UserTopUpInitResult(string RazorpayOrderId, decimal Amount);

public sealed record UserConfirmTopUpRequest(
    decimal Amount,
    string RazorpayOrderId,
    string RazorpayPaymentId,
    string Signature);

public sealed record UserTransferRequest(string RecipientPhone, decimal Amount);

public sealed record UserWalletTransactionResponse(
    Guid Id,
    string Type,
    decimal Amount,
    string Description,
    string? ReferenceId,
    DateTimeOffset CreatedAt);
