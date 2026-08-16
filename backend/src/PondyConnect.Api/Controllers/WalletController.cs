namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Wallet;

/// <summary>
/// Driver cash-collection wallet endpoints. Lets the captain view their
/// COD commission balance, settle outstanding dues via Razorpay, and review
/// recent wallet transactions.
/// </summary>
[ApiController]
[Route("api/driver/wallet")]
[Authorize(Roles = "Driver")]
public sealed class WalletController : ControllerBase
{
    private readonly WalletService _walletService;
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;

    public WalletController(
        WalletService walletService,
        IApplicationDbContext dbContext,
        ICurrentUserService currentUser)
    {
        _walletService = walletService;
        _dbContext = dbContext;
        _currentUser = currentUser;
    }

    /// <summary>
    /// Returns the current driver's wallet balance, suspended status, and
    /// recent transactions.
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(DriverWalletDetail), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<DriverWalletDetail>> GetWallet(CancellationToken ct)
    {
        var driverId = await ResolveDriverIdAsync(ct);
        if (driverId is null)
            return NotFound(new { Message = "Driver profile not found." });

        var wallet = await _walletService.GetWalletAsync(driverId.Value, ct);
        if (wallet is null)
            return NotFound(new { Message = "Wallet not available." });

        return Ok(wallet);
    }

    /// <summary>
    /// Initiates a Razorpay top-up order for settling wallet dues. Returns
    /// the provider order ID that the client uses to open the Razorpay
    /// checkout sheet.
    /// </summary>
    [HttpPost("topup")]
    [ProducesResponseType(typeof(TopUpOrderResult), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<TopUpOrderResult>> InitiateTopUp(
        [FromBody] InitiateTopUpRequest request,
        CancellationToken ct)
    {
        if (request.Amount <= 0m)
            return BadRequest(new { Message = "Amount must be greater than zero." });

        var driverId = await ResolveDriverIdAsync(ct);
        if (driverId is null)
            return NotFound(new { Message = "Driver profile not found." });

        try
        {
            var result = await _walletService.InitiateTopUpAsync(driverId.Value, request.Amount, ct);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

    /// <summary>
    /// Verifies a Razorpay payment and credits the wallet with the top-up
    /// amount. Clears the suspended flag when the balance returns to >= 0.
    /// </summary>
    [HttpPost("topup/verify")]
    [ProducesResponseType(typeof(VerifyTopUpResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<VerifyTopUpResponse>> VerifyTopUp(
        [FromBody] VerifyTopUpRequest request,
        CancellationToken ct)
    {
        var driverId = await ResolveDriverIdAsync(ct);
        if (driverId is null)
            return NotFound(new { Message = "Driver profile not found." });

        var credited = await _walletService.TopUpAsync(
            driverId.Value,
            request.Amount,
            request.RazorpayPaymentId,
            request.RazorpayOrderId,
            request.RazorpaySignature,
            ct);

        if (!credited)
            return BadRequest(new { Message = "Payment signature verification failed." });

        return Ok(new VerifyTopUpResponse(true, "Wallet topped up successfully."));
    }

    private async Task<Guid?> ResolveDriverIdAsync(CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null)
            return null;

        var driver = await _dbContext.Drivers
            .AsNoTracking()
            .FirstOrDefaultAsync(d => d.UserId == userId.Value, ct);

        return driver?.Id;
    }
}

public sealed record InitiateTopUpRequest(decimal Amount);

public sealed record VerifyTopUpRequest(
    decimal Amount,
    string RazorpayPaymentId,
    string RazorpayOrderId,
    string? RazorpaySignature);

public sealed record VerifyTopUpResponse(bool Success, string Message);
