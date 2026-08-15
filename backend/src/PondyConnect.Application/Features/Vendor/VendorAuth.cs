namespace PondyConnect.Application.Features.Vendor;

using FluentValidation;
using MediatR;

/// <summary>
/// Issues a fresh OTP for a vendor owner phone number. Reuses the same
/// OTP infrastructure as the consumer auth flow.
/// </summary>
public sealed record RequestVendorOtpCommand(string Phone) : IRequest<VendorOtpRequestedResponse>;

public sealed class RequestVendorOtpCommandValidator : AbstractValidator<RequestVendorOtpCommand>
{
    public RequestVendorOtpCommandValidator()
    {
        RuleFor(x => x.Phone)
            .NotEmpty()
            .Matches("^[0-9]{10,15}$")
            .WithMessage("A valid 10+ digit phone number is required.");
    }
}

public sealed record VendorOtpRequestedResponse(string Phone, int OtpExpirySeconds);

/// <summary>
/// Exchanges a verified OTP for a vendor-scoped JWT. The phone number must
/// resolve to an approved vendor, otherwise the login is rejected.
/// </summary>
public sealed record VerifyVendorOtpCommand(
    string Phone,
    string OtpCode,
    string? OwnerName = null) : IRequest<VendorLoginResponse>;

public sealed class VerifyVendorOtpCommandValidator : AbstractValidator<VerifyVendorOtpCommand>
{
    public VerifyVendorOtpCommandValidator()
    {
        RuleFor(x => x.Phone)
            .NotEmpty()
            .Matches("^[0-9]{10,15}$")
            .WithMessage("A valid 10+ digit phone number is required.");

        RuleFor(x => x.OtpCode)
            .NotEmpty()
            .Length(4, 8)
            .WithMessage("The OTP is invalid.");

        RuleFor(x => x.OwnerName)
            .MaximumLength(120);
    }
}

public sealed record VendorLoginResponse(
    string AccessToken,
    Guid VendorId,
    string VendorName,
    string Category,
    Guid UserId,
    string UserName,
    string Phone);