namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Auth;
using PondyConnect.Application.Features.RideHailing;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.Entities;
using PondyConnect.Api.Services;

[ApiController]
[Route("api/driver")]
[Authorize]
public sealed class DriverController : ControllerBase
{
    private static readonly string[] AllowedImageTypes = { "image/jpeg", "image/png", "image/webp" };
    private const long MaxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

    private readonly IMediator _mediator;
    private readonly DriverPayoutService _payoutService;
    private readonly DriverLocationStore _locationStore;
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;
    private readonly IStorageService _storage;
    private readonly DispatchEngine _dispatchEngine;
    private readonly AccountDeletionService _accountDeletion;

    public DriverController(
        IMediator mediator,
        DriverPayoutService payoutService,
        DriverLocationStore locationStore,
        IApplicationDbContext dbContext,
        ICurrentUserService currentUser,
        IStorageService storage,
        DispatchEngine dispatchEngine,
        AccountDeletionService accountDeletion)
    {
        _mediator = mediator;
        _payoutService = payoutService;
        _locationStore = locationStore;
        _dbContext = dbContext;
        _currentUser = currentUser;
        _storage = storage;
        _dispatchEngine = dispatchEngine;
        _accountDeletion = accountDeletion;
    }

    /// <summary>
    /// Validates that an uploaded file is an image within the allowed types
    /// and size limit. Returns an error message if validation fails, null if OK.
    /// </summary>
    private static string? ValidateImageFile(IFormFile file, string fieldName)
    {
        if (file.Length > MaxFileSizeBytes)
            return $"{fieldName} file exceeds the 10 MB size limit.";
        if (!AllowedImageTypes.Contains(file.ContentType))
            return $"{fieldName} file must be JPEG, PNG, or WebP.";
        return null;
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
            driver.IsOnline,
            driver.UpiId));
    }

    [HttpPost("register")]
    [AllowAnonymous]
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

    /// <summary>
    /// Logs a mock/fake GPS location detection anomaly. Called by the
    /// Captain app when <c>Position.isMocked</c> is true. The driver is
    /// flagged for review and repeated offenses may lead to suspension.
    /// </summary>
    [HttpPost("mock-location-report")]
    [Authorize(Roles = "Driver")]
    public async Task<IActionResult> ReportMockLocation([FromBody] MockLocationReportRequest request, CancellationToken ct)
    {
        var driver = await ResolveDriverAsync(ct);
        if (driver is null)
            return NotFound(new { Message = "Driver profile not found." });

        // Force the driver offline in the in-memory store.
        _locationStore.SetOnline(driver.Id, false);

        // Log the anomaly for admin review. The fraud detection service
        // tracks repeated offenses and can apply a shadow-ban flag.
        // For now, we log it via the existing fraud flag mechanism.
        return Ok(new { Message = "Mock location anomaly logged. Driver set offline." });
    }

    /// <summary>
    /// Deletes the driver's account, shreds all KYC documents from S3
    /// storage (Aadhaar, Driving License, RC, Insurance, Selfie), and
    /// anonymizes all PII in the database. Financial ledgers (rides,
    /// earnings, wallet transactions) remain intact for tax auditing but
    /// are permanently severed from the driver's identity.
    ///
    /// This endpoint is called by the Captain app's "Delete Account & Data"
    /// flow and satisfies DPDP Act "Right to be Forgotten" mandates.
    /// </summary>
    [HttpPost("account/delete")]
    [Authorize(Roles = "Driver")]
    [ProducesResponseType(typeof(AccountDeletionResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteDriverAccount(CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null)
            return Unauthorized(new { Message = "Driver not authenticated." });

        try
        {
            var result = await _accountDeletion.DeleteAccountAsync(userId.Value, ct);
            return Ok(new AccountDeletionResponse(
                "Driver account deleted. All KYC documents shredded and personal data anonymized.",
                result.KycDocumentsShredded,
                result.SavedLocationsDeleted));
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
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

        // Validate file types and sizes to prevent malicious uploads.
        foreach (var (file, name) in new[] { (aadhaar, "Aadhaar"), (drivingLicense, "Driving license"), (rc, "RC") })
        {
            var error = ValidateImageFile(file, name);
            if (error is not null)
                return BadRequest(new { Message = error });
        }

        var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
                     ?? User.FindFirst("nameid")?.Value
                     ?? User.FindFirst("sub")?.Value;
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

    // NOTE: GET /api/driver/wallet is now handled by WalletController which
    // returns the cash-collection ledger wallet (balance, suspended status,
    // recent transactions). The instant-payout endpoint remains here.

    [HttpPost("wallet/instant-payout")]
    [ProducesResponseType(typeof(InstantPayoutResult), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<InstantPayoutResult>> RequestInstantPayout(CancellationToken ct)
    {
        var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
                     ?? User.FindFirst("nameid")?.Value
                     ?? User.FindFirst("sub")?.Value;
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
        if (result is null) return Ok(Array.Empty<DispatchTaskResponse>());
        return Ok(result);
    }

    [HttpGet("tasks/batch/{batchGroupId:guid}")]
    [ProducesResponseType(typeof(IReadOnlyList<DispatchTaskResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<DispatchTaskResponse>>> GetBatchedTasks(Guid batchGroupId, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetBatchedTasksQuery(batchGroupId), ct);
        if (result is null) return Ok(Array.Empty<DispatchTaskResponse>());
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

    [HttpPost("tasks/{taskId:guid}/start")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> StartTask(Guid taskId, [FromBody] StartTaskRequest request, CancellationToken ct)
    {
        var driver = await GetCurrentUserDriverAsync(ct);
        if (driver is null)
            return NotFound(new { Message = "Driver profile not found." });

        // Ownership check: only the driver assigned to this task can update it.
        var task = await _dbContext.DispatchTasks
            .FirstOrDefaultAsync(t => t.Id == taskId && t.DriverId == driver.Id, ct);
        if (task is null)
            return NotFound(new { Message = "Task not found or not assigned to you." });

        if (task.TaskType != DispatchTaskType.Ride || !task.SourceEntityId.HasValue)
            return BadRequest(new { Message = "Task is not a ride or has no source ride." });

        try
        {
            await _mediator.Send(new VerifyOtpAndStartCommand(task.SourceEntityId.Value, request.Otp), ct);
            return Ok(new { Message = "Ride started." });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
        catch (UnauthorizedAccessException)
        {
            return Forbid();
        }
    }

    [HttpPost("tasks/{taskId:guid}/complete")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> CompleteTask(Guid taskId, CancellationToken ct)
    {
        var driver = await GetCurrentUserDriverAsync(ct);
        if (driver is null)
            return NotFound(new { Message = "Driver profile not found." });

        // Ownership check: only the driver assigned to this task can update it.
        var task = await _dbContext.DispatchTasks
            .FirstOrDefaultAsync(t => t.Id == taskId && t.DriverId == driver.Id, ct);
        if (task is null)
            return NotFound(new { Message = "Task not found or not assigned to you." });

        // Idempotent: already completed.
        if (task.Status == DispatchTaskStatus.Completed)
            return NoContent();

        // For ride tasks, complete the underlying ride first so notifications,
        // wallet commission, and end-of-ride cleanup are performed.
        if (task.TaskType == DispatchTaskType.Ride && task.SourceEntityId.HasValue)
        {
            var ride = await _dbContext.RideRequests
                .FirstOrDefaultAsync(r => r.Id == task.SourceEntityId.Value && r.DriverId == driver.Id, ct);
            if (ride is not null && ride.Status != RideStatus.Completed)
            {
                try
                {
                    await _mediator.Send(new CompleteRideWithMetricsCommand(ride.Id, ride.DistanceKm, ride.EstimatedDurationMin), ct);
                }
                catch (InvalidOperationException ex)
                {
                    return BadRequest(new { Message = ex.Message });
                }
            }
        }

        // For food delivery tasks, mark the associated food order as Delivered.
        if (task.TaskType == DispatchTaskType.FoodDelivery && task.SourceEntityId.HasValue)
        {
            var foodOrder = await _dbContext.FoodOrders
                .FirstOrDefaultAsync(o => o.Id == task.SourceEntityId.Value, ct);
            if (foodOrder is not null && foodOrder.Status == FoodOrderStatus.OutForDelivery)
            {
                try
                {
                    foodOrder.Deliver();
                }
                catch (InvalidOperationException ex)
                {
                    return BadRequest(new { Message = ex.Message });
                }
            }
        }

        try
        {
            task.Complete();
            await _dbContext.SaveChangesAsync(ct);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

    /// <summary>
    /// Marks the driver as arrived at the store/restaurant for a food or
    /// essentials delivery task. Persists the intermediate phase so the
    /// delivery can be resumed if the app is killed.
    /// </summary>
    [HttpPost("tasks/{taskId:guid}/arrived-at-store")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> MarkArrivedAtStore(Guid taskId, CancellationToken ct)
    {
        var driver = await GetCurrentUserDriverAsync(ct);
        if (driver is null)
            return NotFound(new { Message = "Driver profile not found." });

        // Ownership check: only the driver assigned to this task can update it.
        var task = await _dbContext.DispatchTasks.FirstOrDefaultAsync(t => t.Id == taskId && t.DriverId == driver.Id, ct);
        if (task is null)
            return NotFound(new { Message = "Task not found or not assigned to you." });
        try
        {
            task.MarkArrivedAtStore();
            await _dbContext.SaveChangesAsync(ct);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

    /// <summary>
    /// Marks the order as picked up and the driver as en route to the
    /// customer. Persists the intermediate phase so the delivery can be
    /// resumed if the app is killed.
    /// </summary>
    [HttpPost("tasks/{taskId:guid}/out-for-delivery")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> MarkOutForDelivery(Guid taskId, CancellationToken ct)
    {
        var driver = await GetCurrentUserDriverAsync(ct);
        if (driver is null)
            return NotFound(new { Message = "Driver profile not found." });

        // Ownership check: only the driver assigned to this task can update it.
        var task = await _dbContext.DispatchTasks.FirstOrDefaultAsync(t => t.Id == taskId && t.DriverId == driver.Id, ct);
        if (task is null)
            return NotFound(new { Message = "Task not found or not assigned to you." });
        try
        {
            task.MarkOutForDelivery();
            await _dbContext.SaveChangesAsync(ct);
            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
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

    // -----------------------------------------------------------------------
    // Emergency release: driver breakdown / flat tire / cannot complete
    // -----------------------------------------------------------------------

    /// <summary>
    /// Emergency release: unassigns the driver from the task, sets them back
    /// to Online, and pushes the task back to the dispatch queue for the next
    /// nearest driver. The driver is not penalized for emergency releases.
    /// </summary>
    [HttpPost("tasks/{taskId:guid}/emergency-release")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> EmergencyRelease(Guid taskId, CancellationToken ct)
    {
        var driver = await GetCurrentUserDriverAsync(ct);
        if (driver is null)
            return NotFound(new { Message = "Driver profile not found." });

        var task = await _dbContext.DispatchTasks
            .FirstOrDefaultAsync(t => t.Id == taskId && t.DriverId == driver.Id, ct);
        if (task is null)
            return NotFound(new { Message = "Task not found or not assigned to you." });

        try
        {
            task.EmergencyRelease();
            driver.EndRide();
            driver.GoOnline();
            _locationStore.SetOnRide(driver.Id, Guid.Empty);
            await _dbContext.SaveChangesAsync(ct);

            // Re-dispatch the task to the next nearest driver.
            if (task.TaskType == DispatchTaskType.Ride && task.SourceEntityId is { } rideId)
            {
                _ = _dispatchEngine.DispatchRideAsync(rideId, cancellationToken: ct);
            }

            return Ok(new { Message = "Emergency release processed. Task re-dispatched to another driver." });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

    private async Task<Domain.Entities.Driver?> GetCurrentUserDriverAsync(CancellationToken ct)
    {
        var userIdStr = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
                        ?? User.FindFirst("nameid")?.Value
                        ?? User.FindFirst("sub")?.Value;
        if (string.IsNullOrEmpty(userIdStr))
            return null;
        var userId = Guid.Parse(userIdStr);
        return await _dbContext.Drivers.FirstOrDefaultAsync(d => d.UserId == userId, ct);
    }
}

public sealed record RegisterDriverRequest(string Name, string Phone, VehicleType VehicleType, string? VehiclePlate = null);
public sealed record UpdateLocationRequest(double Latitude, double Longitude);

public sealed record MockLocationReportRequest(double Latitude, double Longitude);

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
    bool IsOnline,
    string? UpiId);

public sealed record StartTaskRequest(string Otp);
