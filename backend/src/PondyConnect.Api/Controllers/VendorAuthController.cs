namespace PondyConnect.Api.Controllers;

using FluentValidation;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Vendor;

[ApiController]
[Route("api/vendor/auth")]
[EnableRateLimiting("AuthPolicy")]
public sealed class VendorAuthController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly IOtpService _otpService;

    public VendorAuthController(IMediator mediator, IOtpService otpService)
    {
        _mediator = mediator;
        _otpService = otpService;
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
            return BadRequest(new { Errors = ex.Errors.Select(e => e.ErrorMessage) });
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
            return BadRequest(new { Errors = ex.Errors.Select(e => e.ErrorMessage) });
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
            return NotFound(new { message = "OTP not available for peek." });

        return Ok(new { phone, code });
    }
}