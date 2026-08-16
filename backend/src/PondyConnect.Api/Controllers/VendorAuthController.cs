namespace PondyConnect.Api.Controllers;

using FluentValidation;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Vendor;

[ApiController]
[Route("api/vendor/auth")]
[EnableRateLimiting("AuthPolicy")]
public sealed class VendorAuthController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly IOtpService _otpService;
    private readonly ICurrentUserService _currentUser;
    private readonly IApplicationDbContext _dbContext;
    private readonly IJwtTokenFactory _jwtTokenFactory;

    public VendorAuthController(
        IMediator mediator,
        IOtpService otpService,
        ICurrentUserService currentUser,
        IApplicationDbContext dbContext,
        IJwtTokenFactory jwtTokenFactory)
    {
        _mediator = mediator;
        _otpService = otpService;
        _currentUser = currentUser;
        _dbContext = dbContext;
        _jwtTokenFactory = jwtTokenFactory;
    }

    [HttpPost("otp/request")]
    [ProducesResponseType(typeof(VendorOtpRequestedResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<VendorOtpRequestedResponse>> RequestOtp([FromBody] RequestVendorOtpCommand command)
    {
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

    [HttpPost("otp/verify")]
    [ProducesResponseType(typeof(VendorLoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<VendorLoginResponse>> VerifyOtp([FromBody] VerifyVendorOtpCommand command)
    {
        try
        {
            var result = await _mediator.Send(command);
            return Ok(result);
        }
        catch (UnauthorizedAccessException)
        {
            return Unauthorized(new { Message = "Login failed. Please check your OTP and that an approved vendor profile exists." });
        }
        catch (ValidationException ex)
        {
            return BadRequest(new { Message = "Validation failed.", Errors = ex.Errors.Select(e => e.ErrorMessage) });
        }
    }

    [HttpGet("otp/peek")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult> PeekOtp(
        [FromQuery] string phone,
        CancellationToken cancellationToken)
    {
        // Retrieves the most recently issued vendor OTP plaintext. Only
        // available when the system is in test/SMS-mock mode.
        var code = await _otpService.PeekCodeAsync(phone, cancellationToken);
        if (code is null)
            return NotFound(new { Message = "OTP not available for peek." });

        return Ok(new { phone, code });
    }

    [HttpPost("refresh")]
    [Authorize]
    [ProducesResponseType(typeof(VendorLoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<VendorLoginResponse>> RefreshToken(CancellationToken cancellationToken)
    {
        // The current vendor JWT must still be valid to reach this point.
        // Issue a fresh 60-minute access token for the same vendor owner.
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("Not authenticated.");
        var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
        if (user is null)
            return Unauthorized(new { Message = "User not found." });

        var vendor = await _dbContext.Vendors
            .FirstOrDefaultAsync(v => v.ContactPhone == user.Phone, cancellationToken);
        if (vendor is null)
            return Unauthorized(new { Message = "No vendor profile is linked to this account." });

        string status;
        string? rejectionReason = null;
        if (!vendor.IsActive)
        {
            status = "Rejected";
            rejectionReason = "Account has been deactivated. Contact support for details.";
        }
        else if (!vendor.IsApproved)
        {
            status = "Pending";
        }
        else
        {
            status = "Approved";
        }

        var accessToken = _jwtTokenFactory.CreateAccessToken(user.Id, user.Phone, user.Role.ToString());

        return Ok(new VendorLoginResponse(
            accessToken,
            vendor.Id,
            vendor.Name,
            vendor.Category.ToString(),
            user.Id,
            user.Name,
            user.Phone,
            status,
            rejectionReason));
    }
}