namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Users;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.ValueObjects;

[ApiController]
[Route("api/user")]
public sealed class DeviceTokenController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public DeviceTokenController(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    [HttpPost("device-token")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateDeviceToken(
        [FromBody] UpdateDeviceTokenRequest request,
        CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);

        if (user is null)
            return NotFound(new { Message = "User not found." });

        user.UpdateFcmDeviceToken(request.Token);
        await _context.SaveChangesAsync(cancellationToken);

        return Ok(new { Message = "Device token updated." });
    }

    /// <summary>
    /// Updates the user's dietary preference for food personalization.
    /// Valid values: "veg", "non_veg", "vegan", "egg", or null.
    /// </summary>
    [HttpPut("dietary-preference")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateDietaryPreference(
        [FromBody] UpdateDietaryPreferenceRequest request,
        CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);

        if (user is null)
            return NotFound(new { Message = "User not found." });

        user.UpdateDietaryPreference(request.Preference);
        await _context.SaveChangesAsync(cancellationToken);

        return Ok(new { Message = "Dietary preference updated.", Preference = request.Preference });
    }

    /// <summary>
    /// Marks the first-launch onboarding flow as complete.
    /// Called after the user sets their home/work locations and dietary preference.
    /// </summary>
    [HttpPost("complete-onboarding")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> CompleteOnboarding(CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);

        if (user is null)
            return NotFound(new { Message = "User not found." });

        user.CompleteOnboarding();
        await _context.SaveChangesAsync(cancellationToken);

        return Ok(new { Message = "Onboarding complete." });
    }

    /// <summary>
    /// Saves a new user address (Home, Work, Other).
    /// </summary>
    [HttpPost("addresses")]
    [Authorize]
    [ProducesResponseType(typeof(UserAddressResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<UserAddressResponse>> SaveAddress(
        [FromBody] SaveUserAddressCommand command,
        CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var userExists = await _context.Users.AnyAsync(u => u.Id == userId, cancellationToken);
        if (!userExists)
            return NotFound(new { Message = "User not found." });

        try
        {
            var location = GeoLocation.Create(command.Latitude, command.Longitude);
            var address = UserAddress.Create(
                userId,
                command.DoorFlat,
                command.Landmark,
                command.Tag,
                command.FormattedAddress,
                location);

            _context.UserAddresses.Add(address);
            await _context.SaveChangesAsync(cancellationToken);

            return Ok(new UserAddressResponse(
                address.Id,
                address.DoorFlat,
                address.Landmark,
                address.Tag,
                address.Location.Latitude,
                address.Location.Longitude,
                address.FormattedAddress));
        }
        catch (ArgumentOutOfRangeException)
        {
            return BadRequest(new { Message = "Invalid latitude or longitude." });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }
}

public sealed record UpdateDeviceTokenRequest(string Token);
public sealed record UpdateDietaryPreferenceRequest(string? Preference);
