namespace PondyConnect.Api.Controllers;

using FluentValidation;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Auth;
using PondyConnect.Application.Services;

[ApiController]
[Route("api/auth")]
[EnableRateLimiting("AuthPolicy")]
public sealed class AuthController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ICurrentUserService _currentUser;
    private readonly IApplicationDbContext _dbContext;
    private readonly IOtpService _otpService;
    private readonly IJwtTokenFactory _jwtTokenFactory;
    private readonly IOtpRateLimiter _rateLimiter;

    public AuthController(IMediator mediator, ICurrentUserService currentUser, IApplicationDbContext dbContext, IOtpService otpService, IJwtTokenFactory jwtTokenFactory, IOtpRateLimiter rateLimiter)
    {
        _mediator = mediator;
        _currentUser = currentUser;
        _dbContext = dbContext;
        _otpService = otpService;
        _jwtTokenFactory = jwtTokenFactory;
        _rateLimiter = rateLimiter;
    }

    [HttpGet("me")]
    [Authorize]
    [ProducesResponseType(typeof(AuthResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<AuthResponse>> GetMe(CancellationToken cancellationToken)
    {
        try
        {
            var result = await _mediator.Send(new GetMeQuery(), cancellationToken);
            return Ok(result);
        }
        catch (UnauthorizedAccessException)
        {
            return Unauthorized(new { Message = "Not authenticated." });
        }
    }

    [HttpPut("me")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> UpdateMe([FromBody] UpdateProfileRequest request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("Not authenticated.");
        var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
        if (user is null)
            return NotFound(new { Message = "User not found." });

        if (!string.IsNullOrWhiteSpace(request.Name))
            user.UpdateProfile(request.Name);

        await _dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    [HttpPost("otp/request")]
    [HttpPost("otp")]
    [ProducesResponseType(typeof(OtpRequestedResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status429TooManyRequests)]
    public async Task<ActionResult<OtpRequestedResponse>> RequestOtp([FromBody] RequestOtpCommand command)
    {
        // Enforce per-IP and per-phone OTP rate limiting (3 requests / 15 min).
        var ip = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        var phone = command.Phone ?? string.Empty;

        if (!await _rateLimiter.TryConsumeAsync($"otp:{ip}"))
            return OtpRateLimited();

        if (!string.IsNullOrEmpty(phone) && !await _rateLimiter.TryConsumeAsync($"otp:{phone}"))
            return OtpRateLimited();

        try
        {
            var result = await _mediator.Send(command);
            return Ok(result);
        }
        catch (ValidationException ex)
        {
            return BadRequest(new { Message = "Validation failed.", Errors = ex.Errors.Select(e => e.ErrorMessage) });
        }
    }

    /// <summary>
    /// Returns a 429 response with a Retry-After header and a user-friendly
    /// message indicating how long the caller should wait before retrying.
    /// </summary>
    private ObjectResult OtpRateLimited()
    {
        var minutes = (int)Math.Ceiling(_rateLimiter.Window.TotalMinutes);
        Response.Headers["Retry-After"] = ((int)_rateLimiter.Window.TotalSeconds).ToString(System.Globalization.CultureInfo.InvariantCulture);
        return StatusCode(StatusCodes.Status429TooManyRequests,
            new { Message = $"Too many OTP requests. Please try again in {minutes} minutes." });
    }

    [HttpPost("otp/verify")]
    [ProducesResponseType(typeof(AuthResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<AuthResponse>> VerifyOtp([FromBody] VerifyOtpCommand command)
    {
        try
        {
            var result = await _mediator.Send(command);
            return Ok(result);
        }
        catch (UnauthorizedAccessException)
        {
            return Unauthorized(new { Message = "Invalid or expired OTP." });
        }
        catch (ValidationException ex)
        {
            return BadRequest(new { Message = "Validation failed.", Errors = ex.Errors.Select(e => e.ErrorMessage) });
        }
    }

    [HttpPost("aadhaar/verify")]
    [Authorize]
    [ProducesResponseType(typeof(AadhaarVerificationResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<AadhaarVerificationResponse>> VerifyAadhaar(
        [FromBody] VerifyAadhaarCommand command, CancellationToken cancellationToken)
    {
        try
        {
            var result = await _mediator.Send(command, cancellationToken);
            return Ok(result);
        }
        catch (UnauthorizedAccessException)
        {
            return Unauthorized(new { Message = "Not authenticated." });
        }
        catch (ValidationException ex)
        {
            return BadRequest(new { Message = "Validation failed.", Errors = ex.Errors.Select(e => e.ErrorMessage) });
        }
    }

    [HttpPost("social/google")]
    [ProducesResponseType(typeof(SocialAuthResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<SocialAuthResponse>> GoogleSignIn(
        [FromBody] GoogleSignInCommand command,
        CancellationToken cancellationToken)
    {
        try
        {
            var result = await _mediator.Send(command, cancellationToken);
            return Ok(result);
        }
        catch (UnauthorizedAccessException)
        {
            return Unauthorized(new { Message = "Invalid or expired Google token." });
        }
        catch (ValidationException ex)
        {
            return BadRequest(new { Message = "Validation failed.", Errors = ex.Errors.Select(e => e.ErrorMessage) });
        }
    }

    [HttpPost("social/google/link")]
    [Authorize]
    [ProducesResponseType(typeof(AuthResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<AuthResponse>> LinkGoogle(
        [FromBody] LinkGoogleCommand command,
        CancellationToken cancellationToken)
    {
        try
        {
            var result = await _mediator.Send(command, cancellationToken);
            return Ok(result);
        }
        catch (UnauthorizedAccessException)
        {
            return Unauthorized(new { Message = "Not authenticated." });
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { Message = ex.Message });
        }
        catch (ValidationException ex)
        {
            return BadRequest(new { Message = "Validation failed.", Errors = ex.Errors.Select(e => e.ErrorMessage) });
        }
    }

    [HttpPost("waiver/accept")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> AcceptWaiver(CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
        if (user is null)
            return NotFound(new { Message = "User not found." });

        user.AcceptLiabilityWaiver();
        await _dbContext.SaveChangesAsync(cancellationToken);

        return Ok(new { Message = "Liability waiver accepted.", AcceptedAt = user.WaiverAcceptedAt });
    }

    [HttpPost("refresh")]
    [Authorize]
    [ProducesResponseType(typeof(AuthResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<AuthResponse>> RefreshToken(CancellationToken cancellationToken)
    {
        // The current JWT must still be valid to reach this point.
        // Issue a fresh 60-minute access token for the same user.
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("Not authenticated.");
        var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
        if (user is null)
            return Unauthorized(new { Message = "User not found." });

        var token = _jwtTokenFactory.CreateAccessToken(user.Id, user.Phone, user.Role.ToString());
        return Ok(new AuthResponse(token, user.Id, user.Phone, user.Name, user.Role.ToString()));
    }

    // ── FCM device token hygiene ──

    [HttpPut("fcm-token")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateFcmToken(
        [FromBody] UpdateFcmTokenRequest request,
        CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var user = await _dbContext.Users
            .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);

        if (user is null)
            return NotFound(new { Message = "User not found." });

        user.UpdateFcmDeviceToken(request.Token);

        var driver = await _dbContext.Drivers
            .FirstOrDefaultAsync(d => d.UserId == userId, cancellationToken);
        driver?.UpdateFcmDeviceToken(request.Token);

        var vendor = await _dbContext.Vendors
            .FirstOrDefaultAsync(v => v.ContactPhone == user.Phone, cancellationToken);
        vendor?.UpdateFcmDeviceToken(request.Token);

        await _dbContext.SaveChangesAsync(cancellationToken);

        return NoContent();
    }

    [HttpDelete("fcm-token")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteFcmToken(CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var user = await _dbContext.Users
            .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);

        if (user is null)
            return NotFound(new { Message = "User not found." });

        user.ClearFcmDeviceToken();

        var driver = await _dbContext.Drivers
            .FirstOrDefaultAsync(d => d.UserId == userId, cancellationToken);
        driver?.ClearFcmDeviceToken();

        var vendor = await _dbContext.Vendors
            .FirstOrDefaultAsync(v => v.ContactPhone == user.Phone, cancellationToken);
        vendor?.ClearFcmDeviceToken();

        await _dbContext.SaveChangesAsync(cancellationToken);

        return NoContent();
    }

    [HttpGet("otp/peek")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ApiExplorerSettings(IgnoreApi = true)] // Hide from Swagger docs
    public async Task<ActionResult> PeekOtp(
        [FromQuery] string phone,
        CancellationToken cancellationToken)
    {
        // PeekCodeAsync returns null when test mode is disabled (production
        // with real SMS). This keeps the endpoint safe without blocking
        // the deployed backend during the testing phase.
        var code = await _otpService.PeekCodeAsync(phone, cancellationToken);
        if (code is null)
            return NotFound(new { Message = "OTP not available for peek. Either no code was issued, it expired, or peek is disabled in production." });

        return Ok(new { phone, code });
    }

    // ── Phone number change flow ──

    /// <summary>
    /// Step 1 of phone change: sends an OTP to the NEW phone number to
    /// verify that the user owns it. The user must be authenticated.
    /// </summary>
    [HttpPost("change-phone/request")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult> RequestPhoneChange(
        [FromBody] RequestPhoneChangeRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request?.NewPhone) || request.NewPhone.Length < 10)
            return BadRequest(new { Message = "A valid new phone number is required." });

        // Ensure the new phone isn't already in use by another account.
        var existing = await _dbContext.Users.AsNoTracking()
            .AnyAsync(u => u.Phone == request.NewPhone && u.IsActive, cancellationToken);
        if (existing)
            return BadRequest(new { Message = "This phone number is already associated with an account." });

        await _otpService.IssueCodeAsync(request.NewPhone, cancellationToken);
        return Ok(new { Message = "OTP sent to the new phone number." });
    }

    /// <summary>
    /// Step 2 of phone change: verifies the OTP sent to the new number
    /// and updates the authenticated user's phone. Returns a fresh JWT
    /// with the new phone claim.
    /// </summary>
    [HttpPost("change-phone/verify")]
    [Authorize]
    [ProducesResponseType(typeof(AuthResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<AuthResponse>> VerifyPhoneChange(
        [FromBody] VerifyPhoneChangeRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request?.NewPhone) || request.NewPhone.Length < 10)
            return BadRequest(new { Message = "A valid new phone number is required." });
        if (string.IsNullOrWhiteSpace(request?.OtpCode))
            return BadRequest(new { Message = "OTP code is required." });

        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("Not authenticated.");

        var verified = await _otpService.VerifyCodeAsync(request.NewPhone, request.OtpCode, cancellationToken);
        if (!verified)
            return BadRequest(new { Message = "Invalid or expired OTP." });

        var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
        if (user is null)
            return Unauthorized(new { Message = "User not found." });

        // Double-check the new phone wasn't claimed while OTP was in flight.
        var claimed = await _dbContext.Users.AsNoTracking()
            .AnyAsync(u => u.Phone == request.NewPhone && u.Id != userId && u.IsActive, cancellationToken);
        if (claimed)
            return BadRequest(new { Message = "This phone number is already associated with an account." });

        user.ChangePhone(request.NewPhone);
        await _dbContext.SaveChangesAsync(cancellationToken);

        // Issue a fresh JWT with the updated phone claim.
        var token = _jwtTokenFactory.CreateAccessToken(user.Id, user.Phone, user.Role.ToString());
        return Ok(new AuthResponse(token, user.Id, user.Phone, user.Name, user.Role.ToString()));
    }

    // -----------------------------------------------------------------------
    // Right to be Forgotten: delete account & anonymize PII
    // -----------------------------------------------------------------------

    /// <summary>
    /// Deletes the user's account and anonymizes all PII. The user record
    /// is kept (anonymized) so historical order/payment data remains intact
    /// for financial auditing. All personally identifiable information is
    /// hard-deleted: Name, Phone, Email, DietaryPreference, FcmDeviceToken,
    /// GoogleId, PictureUrl, DrivingLicenseNumber, AadhaarHash, SavedLocations.
    /// The account is deactivated so it can never be logged into again.
    /// </summary>
    [HttpDelete("account")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteAccount(CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId;
        if (userId is null)
            return Unauthorized(new { Message = "User not authenticated." });

        var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
        if (user is null)
            return NotFound(new { Message = "User not found." });

        // Anonymize the user record (keeps it for financial auditing).
        user.AnonymizeForDeletion();

        // Hard-delete all saved locations (PII).
        var savedLocations = await _dbContext.SavedLocations
            .Where(l => l.UserId == userId)
            .ToListAsync(cancellationToken);
        if (savedLocations.Count > 0)
            _dbContext.SavedLocations.RemoveRange(savedLocations);

        // Deactivate any driver profile associated with this user.
        var driver = await _dbContext.Drivers.FirstOrDefaultAsync(d => d.UserId == userId, cancellationToken);
        if (driver is not null)
        {
            driver.GoOffline();
        }

        await _dbContext.SaveChangesAsync(cancellationToken);

        return Ok(new { Message = "Account deleted. All personal data has been anonymized." });
    }
}

public sealed record UpdateProfileRequest(string? Name);
public sealed record RequestPhoneChangeRequest(string? NewPhone);
public sealed record VerifyPhoneChangeRequest(string? NewPhone, string? OtpCode);
public sealed record UpdateFcmTokenRequest(string Token);