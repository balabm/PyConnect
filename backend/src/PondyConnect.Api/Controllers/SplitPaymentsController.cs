namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;

/// <summary>
/// Split Payment (P2P) endpoints. Allows a user to create a cost-sharing pool
/// for high-ticket items (villa rentals, yacht charters) and share a deep-link
/// URL via WhatsApp so friends can claim and pay their shares.
/// </summary>
[ApiController]
[Route("api/split-payments")]
[Authorize]
public sealed class SplitPaymentsController : ControllerBase
{
    private const string SlugAlphabet = "abcdefghijklmnopqrstuvwxyz0123456789";
    private const int SlugLength = 8;

    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public SplitPaymentsController(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    // ── Create Pool ──

    [HttpPost]
    [ProducesResponseType(typeof(SplitPaymentPoolDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<SplitPaymentPoolDto>> CreatePool(
        [FromBody] CreateSplitPaymentRequest request, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null)
            return Unauthorized(new { Message = "User not authenticated." });

        if (request.TotalAmount <= 0)
            return BadRequest(new { Message = "Total amount must be greater than zero." });
        if (request.MaxShares <= 0)
            return BadRequest(new { Message = "Max shares must be greater than zero." });
        if (string.IsNullOrWhiteSpace(request.Description))
            return BadRequest(new { Message = "Description is required." });

        var expiresAt = DateTimeOffset.UtcNow.AddHours(
            request.ExpiresAtHours is > 0 ? request.ExpiresAtHours.Value : 72);

        // Generate a unique URL-safe slug.
        string slug;
        var attempts = 0;
        do
        {
            slug = GenerateSlug();
            attempts++;
            if (attempts > 10)
                return BadRequest(new { Message = "Could not generate a unique slug. Please retry." });
        }
        while (await _context.SplitPaymentPools.AsNoTracking()
            .AnyAsync(p => p.DeepLinkSlug == slug, ct));

        SplitPaymentPool pool;
        try
        {
            pool = SplitPaymentPool.Create(
                userId.Value,
                request.TotalAmount,
                request.Description,
                slug,
                request.MaxShares,
                expiresAt,
                request.ReferenceType,
                request.ReferenceId);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }

        _context.SplitPaymentPools.Add(pool);
        await _context.SaveChangesAsync(ct);

        var dto = MapPoolDto(pool);
        return CreatedAtAction(nameof(GetBySlug), new { slug = pool.DeepLinkSlug }, dto);
    }

    // ── Get Pool by Slug ──

    [HttpGet("{slug}")]
    [ProducesResponseType(typeof(SplitPaymentPoolDetailDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<SplitPaymentPoolDetailDto>> GetBySlug(string slug, CancellationToken ct)
    {
        if (_currentUser.UserId is null)
            return Unauthorized(new { Message = "User not authenticated." });

        var pool = await _context.SplitPaymentPools
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.DeepLinkSlug == slug, ct);

        if (pool is null)
            return NotFound(new { Message = "Split payment pool not found." });

        var contributors = await _context.SplitPaymentContributors
            .AsNoTracking()
            .Where(c => c.PoolId == pool.Id)
            .Join(_context.Users,
                c => c.UserId,
                u => u.Id,
                (c, u) => new { c, u })
            .Select(x => new SplitPaymentContributorDto(
                x.c.Id,
                x.u.Name,
                x.c.ShareAmount,
                x.c.PaidAmount,
                x.c.Status.ToString(),
                x.c.PaidAt))
            .ToListAsync(ct);

        var dto = new SplitPaymentPoolDetailDto(
            pool.Id,
            pool.CreatorUserId,
            pool.TotalAmount,
            pool.CollectedAmount,
            pool.Description,
            pool.ReferenceType,
            pool.ReferenceId,
            pool.DeepLinkSlug,
            pool.Status.ToString(),
            pool.PerShareAmount,
            pool.MaxShares,
            pool.ClaimedShares,
            pool.CreatedAt,
            pool.ExpiresAt,
            contributors);

        return Ok(dto);
    }

    // ── Claim a Share ──

    [HttpPost("{id:guid}/claim")]
    [ProducesResponseType(typeof(SplitPaymentContributorDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ClaimShare(Guid id, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null)
            return Unauthorized(new { Message = "User not authenticated." });

        var pool = await _context.SplitPaymentPools
            .FirstOrDefaultAsync(p => p.Id == id, ct);

        if (pool is null)
            return NotFound(new { Message = "Split payment pool not found." });

        // Prevent duplicate claims by the same user.
        var existing = await _context.SplitPaymentContributors
            .AsNoTracking()
            .AnyAsync(c => c.PoolId == id && c.UserId == userId.Value, ct);
        if (existing)
            return BadRequest(new { Message = "You have already claimed a share in this pool." });

        try
        {
            pool.ClaimShare(userId.Value);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }

        var contributor = SplitPaymentContributor.Create(id, userId.Value, pool.PerShareAmount);
        _context.SplitPaymentContributors.Add(contributor);
        await _context.SaveChangesAsync(ct);

        var user = await _context.Users.AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == userId.Value, ct);

        return CreatedAtAction(
            nameof(GetBySlug),
            new { slug = pool.DeepLinkSlug },
            new SplitPaymentContributorDto(
                contributor.Id,
                user?.Name ?? "You",
                contributor.ShareAmount,
                contributor.PaidAmount,
                contributor.Status.ToString(),
                contributor.PaidAt));
    }

    // ── Pay for a Claimed Share ──

    [HttpPost("{id:guid}/pay")]
    [ProducesResponseType(typeof(SplitPaymentContributorDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> PayShare(
        Guid id,
        [FromBody] PayShareRequest request, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null)
            return Unauthorized(new { Message = "User not authenticated." });

        var pool = await _context.SplitPaymentPools
            .FirstOrDefaultAsync(p => p.Id == id, ct);

        if (pool is null)
            return NotFound(new { Message = "Split payment pool not found." });

        var contributor = await _context.SplitPaymentContributors
            .FirstOrDefaultAsync(c => c.PoolId == id && c.UserId == userId.Value, ct);

        if (contributor is null)
            return NotFound(new { Message = "You have not claimed a share in this pool." });

        if (contributor.Status == Domain.Enums.ContributorStatus.Paid)
            return BadRequest(new { Message = "Your share is already paid." });

        try
        {
            contributor.MarkPaid();
            pool.MarkPaid(userId.Value, contributor.ShareAmount);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }

        await _context.SaveChangesAsync(ct);

        var user = await _context.Users.AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == userId.Value, ct);

        return Ok(new SplitPaymentContributorDto(
            contributor.Id,
            user?.Name ?? "You",
            contributor.ShareAmount,
            contributor.PaidAmount,
            contributor.Status.ToString(),
            contributor.PaidAt));
    }

    // ── My Pools ──

    [HttpGet("my-pools")]
    [ProducesResponseType(typeof(IReadOnlyList<SplitPaymentPoolDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<IReadOnlyList<SplitPaymentPoolDto>>> MyPools(CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null)
            return Unauthorized(new { Message = "User not authenticated." });

        var pools = await _context.SplitPaymentPools
            .AsNoTracking()
            .Where(p => p.CreatorUserId == userId.Value)
            .OrderByDescending(p => p.CreatedAt)
            .Select(p => new SplitPaymentPoolDto(
                p.Id,
                p.CreatorUserId,
                p.TotalAmount,
                p.CollectedAmount,
                p.Description,
                p.ReferenceType,
                p.ReferenceId,
                p.DeepLinkSlug,
                p.Status.ToString(),
                p.PerShareAmount,
                p.MaxShares,
                p.ClaimedShares,
                p.CreatedAt,
                p.ExpiresAt))
            .ToListAsync(ct);

        return Ok(pools);
    }

    // ── Cancel Pool ──

    [HttpPost("{id:guid}/cancel")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> CancelPool(Guid id, CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null)
            return Unauthorized(new { Message = "User not authenticated." });

        var pool = await _context.SplitPaymentPools
            .FirstOrDefaultAsync(p => p.Id == id, ct);

        if (pool is null)
            return NotFound(new { Message = "Split payment pool not found." });

        if (pool.CreatorUserId != userId.Value)
            return StatusCode(StatusCodes.Status403Forbidden,
                new { Message = "Only the creator can cancel this pool." });

        try
        {
            pool.Cancel();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }

        await _context.SaveChangesAsync(ct);
        return Ok(new { Message = "Split payment pool cancelled." });
    }

    // ── Helpers ──

    private static string GenerateSlug()
    {
        var chars = new char[SlugLength];
        for (var i = 0; i < SlugLength; i++)
            chars[i] = SlugAlphabet[Random.Shared.Next(SlugAlphabet.Length)];
        return new string(chars);
    }

    private static SplitPaymentPoolDto MapPoolDto(SplitPaymentPool pool)
        => new(
            pool.Id,
            pool.CreatorUserId,
            pool.TotalAmount,
            pool.CollectedAmount,
            pool.Description,
            pool.ReferenceType,
            pool.ReferenceId,
            pool.DeepLinkSlug,
            pool.Status.ToString(),
            pool.PerShareAmount,
            pool.MaxShares,
            pool.ClaimedShares,
            pool.CreatedAt,
            pool.ExpiresAt);
}

// ── Request DTOs ──

public sealed record CreateSplitPaymentRequest(
    decimal TotalAmount,
    string Description,
    int MaxShares,
    string? ReferenceType = null,
    Guid? ReferenceId = null,
    int? ExpiresAtHours = null);

public sealed record PayShareRequest(
    string RazorpayOrderId,
    string RazorpayPaymentId,
    string RazorpaySignature);

// ── Response DTOs ──

public sealed record SplitPaymentPoolDto(
    Guid Id,
    Guid CreatorUserId,
    decimal TotalAmount,
    decimal CollectedAmount,
    string Description,
    string? ReferenceType,
    Guid? ReferenceId,
    string DeepLinkSlug,
    string Status,
    decimal PerShareAmount,
    int MaxShares,
    int ClaimedShares,
    DateTimeOffset CreatedAt,
    DateTimeOffset ExpiresAt)
{
    /// <summary>
    /// The full deep-link URL that can be shared via WhatsApp.
    /// </summary>
    public string DeepLinkUrl => $"https://pyconnect.run.place/split/{DeepLinkSlug}";
}

public sealed record SplitPaymentContributorDto(
    Guid Id,
    string Name,
    decimal ShareAmount,
    decimal PaidAmount,
    string Status,
    DateTimeOffset? PaidAt);

public sealed record SplitPaymentPoolDetailDto(
    Guid Id,
    Guid CreatorUserId,
    decimal TotalAmount,
    decimal CollectedAmount,
    string Description,
    string? ReferenceType,
    Guid? ReferenceId,
    string DeepLinkSlug,
    string Status,
    decimal PerShareAmount,
    int MaxShares,
    int ClaimedShares,
    DateTimeOffset CreatedAt,
    DateTimeOffset ExpiresAt,
    IReadOnlyList<SplitPaymentContributorDto> Contributors)
{
    public string DeepLinkUrl => $"https://pyconnect.run.place/split/{DeepLinkSlug}";
}
