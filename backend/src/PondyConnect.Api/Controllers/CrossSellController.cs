namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.CrossSell;

/// <summary>
/// Cross-sell endpoints that suggest rides after event bookings.
/// </summary>
[ApiController]
[Route("api/cross-sell")]
[Authorize]
public sealed class CrossSellController : ControllerBase
{
    private readonly CrossSellService _crossSellService;
    private readonly ICurrentUserService _currentUser;

    public CrossSellController(
        CrossSellService crossSellService,
        ICurrentUserService currentUser)
    {
        _crossSellService = crossSellService;
        _currentUser = currentUser;
    }

    /// <summary>
    /// Gets a ride upsell suggestion for a confirmed booking.
    /// Returns venue GPS coordinates as drop-off, pickup time 30 min before event,
    /// and a 15% discount code.
    /// </summary>
    [HttpGet("ride-upsell/{bookingId:guid}")]
    [ProducesResponseType(typeof(RideUpsellSuggestion), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<RideUpsellSuggestion>> GetRideUpsell(
        Guid bookingId,
        CancellationToken ct)
    {
        var suggestion = await _crossSellService.GetRideUpsellAsync(bookingId, ct);

        if (suggestion is null)
            return NotFound(new { Message = "No ride upsell available for this booking." });

        return Ok(suggestion);
    }
}
