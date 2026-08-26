namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Consumer PY Wallet endpoints. Exposes the user's promo balance, real
/// balance, and PY Coins loyalty balance. Top-up and transaction history
/// are planned for a future iteration.
/// </summary>
[ApiController]
[Route("api/user/wallet")]
[Authorize]
public sealed class UserWalletController : ControllerBase
{
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;

    public UserWalletController(IApplicationDbContext dbContext, ICurrentUserService currentUser)
    {
        _dbContext = dbContext;
        _currentUser = currentUser;
    }

    /// <summary>
    /// Returns the current user's wallet balance breakdown.
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(UserWalletDetail), StatusCodes.Status200OK)]
    public async Task<ActionResult<UserWalletDetail>> GetWallet(CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId == Guid.Empty)
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
}

/// <summary>
/// Consumer wallet balance breakdown.
/// </summary>
public sealed record UserWalletDetail(
    decimal PromoBalance,
    decimal RealBalance,
    int PyCoins,
    decimal TotalBalance);
