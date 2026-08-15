namespace PondyConnect.Application.Features.Auth;

using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using System.Security.Cryptography;
using System.Text;

public sealed record VerifyAadhaarCommand(string AadhaarNumber) : IRequest<AadhaarVerificationResponse>;

public sealed record AadhaarVerificationResponse(
    bool IsVerifiedLocal,
    string Role,
    DateTimeOffset? VerifiedAt);

public sealed class VerifyAadhaarValidator : AbstractValidator<VerifyAadhaarCommand>
{
    public VerifyAadhaarValidator()
    {
        RuleFor(x => x.AadhaarNumber)
            .NotEmpty()
            .Matches(@"^\d{12}$")
            .WithMessage("Aadhaar number must be exactly 12 digits.");
    }
}

public sealed class VerifyAadhaarCommandHandler : IRequestHandler<VerifyAadhaarCommand, AadhaarVerificationResponse>
{
    private const string Salt = "pondyconnect-aadhaar-v1";

    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly IJwtTokenFactory _jwtTokenFactory;

    public VerifyAadhaarCommandHandler(
        IApplicationDbContext context,
        ICurrentUserService currentUser,
        IJwtTokenFactory jwtTokenFactory)
    {
        _context = context;
        _currentUser = currentUser;
        _jwtTokenFactory = jwtTokenFactory;
    }

    public async Task<AadhaarVerificationResponse> Handle(VerifyAadhaarCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == userId, cancellationToken)
            ?? throw new UnauthorizedAccessException("User not found.");

        var hash = HashAadhaar(request.AadhaarNumber);
        user.VerifyAsLocal(hash);

        await _context.SaveChangesAsync(cancellationToken);

        return new AadhaarVerificationResponse(user.IsVerifiedLocal, user.Role.ToString(), user.VerifiedAt);
    }

    internal static string HashAadhaar(string aadhaarNumber)
    {
        var raw = Encoding.UTF8.GetBytes($"{Salt}|{aadhaarNumber}");
        var hash = SHA256.HashData(raw);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }
}
