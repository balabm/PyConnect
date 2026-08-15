namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.RideHailing;
using PondyConnect.Domain.Enums;
using PondyConnect.Api.Services;

[ApiController]
[Route("api/driver")]
[Authorize]
public sealed class DriverController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly DriverPayoutService _payoutService;
    private readonly DriverLocationStore _locationStore;
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;
    private readonly IStorageService _storage;

    public DriverController(
        IMediator mediator,
        DriverPayoutService payoutService,
        DriverLocationStore locationStore,
        IApplicationDbContext dbContext,
        ICurrentUserService currentUser,
        IStorageService storage)
    {
        _mediator = mediator;
        _payoutService = payoutService;
        _locationStore = locationStore;
        _dbContext = dbContext;
        _currentUser = currentUser;
        _storage = storage;
    }

    /// <summary>
    /// Returns the current driver's profile including approval, tutorial and
    /// signature status. Used by the mobile app to route to pending-verification
    /// / tutorial / signature screens and to connect SignalR dispatch.
    /// </summary>
    [HttpGet("me")]
    [ProducesResponseType(typeof(DriverProfileResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<DriverProfileResponse>> GetMyProfile(CancellationToken ct)
    {
        var driver = await GetCurrentUserDriverAsync(ct);
        if (driver is null)
            return NotFound(new { Message = "Driver profile not found." });

        return Ok(new DriverProfileResponse(
            driver.Id,
            driver.Name,
            driver.Phone,
            driver.VehicleType,
            driver.VehiclePlate,
            driver.IsApproved,
            driver.IsKycUploaded,
            driver.HasCompletedTutorial,
            driver.HasSignedAgreement,
            driver.IsOnline));
    }

    [HttpPost("register")]
    [ProducesResponseType(typeof(DriverResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<DriverResponse>> Register([FromBody] RegisterDriverRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new RegisterDriverCommand(request.Name, request.Phone, request.VehicleType, request.VehiclePlate), ct);
        return Ok(result);
    }

    [HttpPost("online")]
    [HttpPost("go-online")]
    public async Task<IActionResult> GoOnline(CancellationToken ct)
    {
        await _mediator.Send(new ToggleDriverOnlineCommand(true), ct);

        // Also update the in-memory location store so dispatch can find this driver
        var driver = await ResolveDriverAsync(ct);
        if (driver is not null)
        {
            _locationStore.SetOnline(driver.Id, true);
            _locationStore.RegisterDriver(driver.Id, driver.VehicleType, driver.Rating, 1.0);
            if (driver.CurrentLocation is not null)
                _locationStore.Update(driver.Id, driver.CurrentLocation.Latitude, driver.CurrentLocation.Longitude);
        }

        return NoContent();
    }

    [HttpPost("offline")]
    [HttpPost("go-offline")]
    public async Task<IActionResult> GoOffline(CancellationToken ct)
    {
        await _mediator.Send(new ToggleDriverOnlineCommand(false), ct);

        var driver = await ResolveDriverAsync(ct);
        if (driver is not null)
            _locationStore.SetOnline(driver.Id, false);

        return NoContent();
    }

    [HttpPost("location")]
    public async Task<IActionResult> UpdateLocation([FromBody] UpdateLocationRequest request, CancellationToken ct)
    {
        await _mediator.Send(new UpdateDriverLocationCommand(request.Latitude, request.Longitude), ct);

        // Also update the in-memory location store so dispatch can find this driver
        var driver = await ResolveDriverAsync(ct);
        if (driver is not null)
            _locationStore.Update(driver.Id, request.Latitude, request.Longitude);

        return NoContent();
    }

    private async Task<Domain.Entities.Driver?> ResolveDriverAsync(CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null) return null;
        return await _dbContext.Drivers.FirstOrDefaultAsync(d => d.UserId == userId.Value, ct);
    }

    [HttpPost("upload-kyc")]
    [ProducesResponseType(typeof(KycUploadResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<KycUploadResponse>> UploadKyc(
        [FromForm] IFormFile aadhaar,
        [FromForm] IFormFile drivingLicense,
        [FromForm] IFormFile rc,
        [FromForm] string upiId,
        CancellationToken ct)
    {
        if (aadhaar is null || aadhaar.Length == 0)
            return BadRequest(new { Message = "Aadhaar image is required." });
        if (drivingLicense is null || drivingLicense.Length == 0)
            return BadRequest(new { Message = "Driving license image is required." });
        if (rc is null || rc.Length == 0)
            return BadRequest(new { Message = "RC image is required." });
        if (string.IsNullOrWhiteSpace(upiId))
            return BadRequest(new { Message = "UPI ID is required." });

        var userId = User.FindFirst("nameid")?.Value ?? User.FindFirst("sub")?.Value;
        if (string.IsNullOrEmpty(userId))
            return Unauthorized();

        var driver = await _mediator.Send(new GetDriverByUserIdQuery(Guid.Parse(userId)), ct);
        if (driver is null)
            return BadRequest(new { Message = "Driver profile not found. Please register first." });

        // Upload all KYC documents as PRIVATE — they contain sensitive PII
        // (Aadhaar, DL, RC) and must never be publicly accessible. The storage
        // service routes them to the private bucket / private folder and
        // returns an object key (S3) or relative path (local dev) that the
        // admin panel can resolve via GetPresignedUrlAsync.
        var aadhaarKey = await _storage.UploadFileAsync(
            aadhaar.OpenReadStream(), aadhaar.FileName, aadhaar.ContentType,
            isPrivate: true, cancellationToken: ct);
        var dlKey = await _storage.UploadFileAsync(
            drivingLicense.OpenReadStream(), drivingLicense.FileName, drivingLicense.ContentType,
            isPrivate: true, cancellationToken: ct);
        var rcKey = await _storage.UploadFileAsync(
            rc.OpenReadStream(), rc.FileName, rc.ContentType,
            isPrivate: true, cancellationToken: ct);

        var result = await _mediator.Send(new UploadKycCommand(aadhaarKey, dlKey, rcKey, upiId), ct);
        return Ok(result);
    }

    /// <summary>
    /// Returns a short-lived presigned URL for viewing a private KYC document.
    /// Used by the Admin panel to inspect uploaded documents without exposing
    /// them publicly.
    /// </summary>
    [HttpGet("kyc/{driverId:guid}/presigned")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<object>> GetKycPresignedUrl(
        Guid driverId,
        [FromQuery] string objectKey,
        [FromQuery] int expiryMinutes = 15,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(objectKey))
            return BadRequest(new { Message = "objectKey query parameter is required." });

        // Only the driver themselves or an admin can access KYC documents.
        var isAdmin = User.IsInRole("Admin");
        if (!isAdmin)
        {
            var driver = await _dbContext.Drivers
                .AsNoTracking()
                .FirstOrDefaultAsync(d => d.Id == driverId, ct);
            if (driver is null || driver.UserId != _currentUser.UserId)
                return NotFound(new { Message = "Driver not found." });
        }

        var url = await _storage.GetPresignedUrlAsync(objectKey, expiryMinutes, ct);
        return Ok(new { Url = url, ExpiresInMinutes = expiryMinutes });
    }

    [HttpGet("wallet")]
    [HttpGet("earnings")]
    [ProducesResponseType(typeof(DriverWalletResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<DriverWalletResponse>> GetWallet(CancellationToken ct)
    {
        var result = await _mediator.Send(new GetDriverWalletQuery(), ct);
        return Ok(result);
    }

    [HttpPost("wallet/instant-payout")]
    [ProducesResponseType(typeof(InstantPayoutResult), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<InstantPayoutResult>> RequestInstantPayout(CancellationToken ct)
    {
        var userId = User.FindFirst("nameid")?.Value ?? User.FindFirst("sub")?.Value;
        if (string.IsNullOrEmpty(userId))
            return Unauthorized();

        var driver = await _mediator.Send(new GetDriverByUserIdQuery(Guid.Parse(userId)), ct);
        if (driver is null)
            return BadRequest(new { Message = "Driver profile not found." });

        var result = await _payoutService.RequestInstantPayout(driver.Id, ct);
        return Ok(result);
    }

    [HttpGet("tasks")]
    [ProducesResponseType(typeof(IReadOnlyList<DispatchTaskResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<DispatchTaskResponse>>> GetTasks(CancellationToken ct)
    {
        var result = await _mediator.Send(new GetAvailableTasksQuery(), ct);
        return Ok(result);
    }

    [HttpPost("tasks/{taskId:guid}/accept")]
    [ProducesResponseType(typeof(DispatchTaskResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<DispatchTaskResponse>> AcceptTask(Guid taskId, CancellationToken ct)
    {
        try
        {
            var result = await _mediator.Send(new AcceptTaskCommand(taskId), ct);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
    }

    [HttpPost("tasks/{taskId:guid}/complete")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> CompleteTask(Guid taskId, CancellationToken ct)
    {
        try
        {
            await _mediator.Send(new CompleteTaskCommand(taskId), ct);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
    }

    // -----------------------------------------------------------------------
    // Self-onboarding: tutorial, safety agreement, extended KYC
    // -----------------------------------------------------------------------

    /// <summary>
    /// Marks the mandatory safety tutorial as completed for the current driver.
    /// Drivers cannot accept rides until this is done.
    /// </summary>
    [HttpPost("complete-tutorial")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> CompleteTutorial(CancellationToken ct)
    {
        var driver = await GetCurrentUserDriverAsync(ct);
        if (driver is null)
            return NotFound(new { Message = "Driver profile not found." });

        driver.CompleteTutorial();
        await _dbContext.SaveChangesAsync(ct);
        return Ok(new { Message = "Tutorial completed.", CompletedAt = driver.TutorialCompletedAt });
    }

    /// <summary>
    /// Records the driver's digital signature on the safety agreement.
    /// </summary>
    [HttpPost("sign-agreement")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> SignAgreement(CancellationToken ct)
    {
        var driver = await GetCurrentUserDriverAsync(ct);
        if (driver is null)
            return NotFound(new { Message = "Driver profile not found." });

        driver.SignAgreement();
        await _dbContext.SaveChangesAsync(ct);
        return Ok(new { Message = "Agreement signed." });
    }

    /// <summary>
    /// Uploads extended KYC documents (insurance + selfie) supplementing the
    /// base KYC (Aadhaar, DL, RC).
    /// </summary>
    [HttpPost("upload-extended-kyc")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UploadExtendedKyc(
        [FromForm] IFormFile? insurance,
        [FromForm] IFormFile? selfie,
        CancellationToken ct)
    {
        var driver = await GetCurrentUserDriverAsync(ct);
        if (driver is null)
            return NotFound(new { Message = "Driver profile not found." });

        string? insuranceKey = null;
        string? selfieKey = null;

        if (insurance != null)
        {
            insuranceKey = await _storage.UploadFileAsync(
                insurance.OpenReadStream(), insurance.FileName, insurance.ContentType,
                isPrivate: true, cancellationToken: ct);
        }
        if (selfie != null)
        {
            selfieKey = await _storage.UploadFileAsync(
                selfie.OpenReadStream(), selfie.FileName, selfie.ContentType,
                isPrivate: true, cancellationToken: ct);
        }

        driver.UploadExtendedKyc(insuranceKey, selfieKey);
        await _dbContext.SaveChangesAsync(ct);

        return Ok(new { Message = "Extended KYC uploaded.", InsuranceUploaded = insuranceKey != null, SelfieUploaded = selfieKey != null });
    }

    private async Task<Domain.Entities.Driver?> GetCurrentUserDriverAsync(CancellationToken ct)
    {
        var userIdStr = User.FindFirst("nameid")?.Value ?? User.FindFirst("sub")?.Value;
        if (string.IsNullOrEmpty(userIdStr))
            return null;
        var userId = Guid.Parse(userIdStr);
        return await _dbContext.Drivers.FirstOrDefaultAsync(d => d.UserId == userId, ct);
    }
}

public sealed record RegisterDriverRequest(string Name, string Phone, VehicleType VehicleType, string? VehiclePlate = null);
public sealed record UpdateLocationRequest(double Latitude, double Longitude);

public sealed record DriverProfileResponse(
    Guid Id,
    string Name,
    string Phone,
    VehicleType VehicleType,
    string? VehiclePlate,
    bool IsApproved,
    bool IsKycUploaded,
    bool HasCompletedTutorial,
    bool HasSignedAgreement,
    bool IsOnline);
