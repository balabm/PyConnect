namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Features.Admin;

/// <summary>
/// Admin-controlled system configuration (kill switches). Allows the
/// Admin to toggle 3rd-party API integrations on/off during outages:
///
/// - IsRazorpayActive: when false, mobile apps hide UPI/Card and
///   force Cash on Delivery.
/// - IsGoogleMapsActive: when false, mobile apps fall back to a
///   static status list instead of a live map.
/// - IsFoodDeliveryActive: when false, food ordering is disabled.
///
/// The public GET endpoint is accessible without authentication so
/// the mobile apps can fetch the config on startup.
/// </summary>
[ApiController]
[Route("api/system-config")]
public sealed class SystemConfigController : ControllerBase
{
    private readonly SystemConfigService _configService;

    public SystemConfigController(SystemConfigService configService)
    {
        _configService = configService;
    }

    /// <summary>
    /// Returns all feature toggles. This endpoint is public (no auth
    /// required) so the mobile apps can fetch it on startup and
    /// gracefully degrade during 3rd-party outages.
    /// </summary>
    [HttpGet]
    [AllowAnonymous]
    [ProducesResponseType(typeof(SystemConfigResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<SystemConfigResponse>> GetAll(CancellationToken ct)
    {
        var config = await _configService.GetAllAsync(ct);
        return Ok(new SystemConfigResponse(config));
    }

    /// <summary>
    /// Updates a single feature toggle. Admin-only.
    /// </summary>
    [HttpPut("{key}")]
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(typeof(SystemConfigResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<SystemConfigResponse>> SetToggle(
        string key,
        [FromBody] SetToggleRequest request,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(key))
            return BadRequest(new { Message = "Config key is required." });

        await _configService.SetAsync(key, request.Value, ct);

        var config = await _configService.GetAllAsync(ct);
        return Ok(new SystemConfigResponse(config));
    }

    /// <summary>
    /// Resets all toggles to their default (active) state. Admin-only.
    /// </summary>
    [HttpPost("reset")]
    [Authorize(Roles = "Admin")]
    [ProducesResponseType(typeof(SystemConfigResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<SystemConfigResponse>> ResetAll(CancellationToken ct)
    {
        await _configService.ResetAllAsync(ct);
        var config = await _configService.GetAllAsync(ct);
        return Ok(new SystemConfigResponse(config));
    }
}

public sealed record SystemConfigResponse(Dictionary<string, bool> Toggles);
public sealed record SetToggleRequest(bool Value);
