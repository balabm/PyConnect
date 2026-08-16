namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;

[ApiController]
[Route("api/reviews")]
[Authorize]
public sealed class ReviewsController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ReviewsController(IMediator mediator, IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _mediator = mediator;
        _context = context;
        _currentUser = currentUser;
    }

    /// <summary>
    /// POST /api/reviews — submit a review (rating + optional feedback + tip).
    /// </summary>
    [HttpPost]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult> SubmitReview([FromBody] SubmitReviewRequest request, CancellationToken ct)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException();
        var review = Review.Create(userId, request.Rating, request.Feedback, request.TipAmount,
            request.DriverId, request.VendorId, request.RideId, request.OrderId);
        _context.Reviews.Add(review);
        await _context.SaveChangesAsync(ct);
        return Ok(new { Message = "Review submitted.", review.Id });
    }

    /// <summary>
    /// GET /api/reviews/driver/{driverId} — get a driver's average rating and review count.
    /// </summary>
    [HttpGet("driver/{driverId}")]
    [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
    public async Task<ActionResult<object>> GetDriverRating(Guid driverId, CancellationToken ct)
    {
        var reviews = await _context.Reviews.Where(r => r.DriverId == driverId).ToListAsync(ct);
        var count = reviews.Count;
        var avg = count > 0 ? reviews.Average(r => r.Rating) : 0;
        return Ok(new { averageRating = Math.Round(avg, 1), totalReviews = count });
    }

    /// <summary>
    /// GET /api/reviews/vendor/{vendorId} — get a vendor's average rating and review count.
    /// </summary>
    [HttpGet("vendor/{vendorId}")]
    [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
    public async Task<ActionResult<object>> GetVendorRating(Guid vendorId, CancellationToken ct)
    {
        var reviews = await _context.Reviews.Where(r => r.VendorId == vendorId).ToListAsync(ct);
        var count = reviews.Count;
        var avg = count > 0 ? reviews.Average(r => r.Rating) : 0;
        return Ok(new { averageRating = Math.Round(avg, 1), totalReviews = count });
    }
}

public record SubmitReviewRequest(
    int Rating, string? Feedback, decimal? TipAmount,
    Guid? DriverId, Guid? VendorId, Guid? RideId, Guid? OrderId);
