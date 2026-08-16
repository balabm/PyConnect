namespace PondyConnect.Application.Features.Auth;

using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Wallet;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed class VerifyOtpCommandHandler : IRequestHandler<VerifyOtpCommand, AuthResponse>
{
    private readonly IOtpService _otpService;
    private readonly IUserResolver _userResolver;
    private readonly IJwtTokenFactory _jwtTokenFactory;
    private readonly IApplicationDbContext _dbContext;
    private readonly ILogger<VerifyOtpCommandHandler> _logger;

    public VerifyOtpCommandHandler(
        IOtpService otpService,
        IUserResolver userResolver,
        IJwtTokenFactory jwtTokenFactory,
        IApplicationDbContext dbContext,
        ILogger<VerifyOtpCommandHandler> logger)
    {
        _otpService = otpService;
        _userResolver = userResolver;
        _jwtTokenFactory = jwtTokenFactory;
        _dbContext = dbContext;
        _logger = logger;
    }

    public async Task<AuthResponse> Handle(VerifyOtpCommand request, CancellationToken cancellationToken)
    {
        var isValid = await _otpService.VerifyCodeAsync(request.Phone, request.Otp, cancellationToken);
        if (!isValid)
        {
            _logger.LogWarning("Failed OTP verification attempt for phone {Phone}", request.Phone);
            throw new UnauthorizedAccessException("Invalid or expired OTP.");
        }

        _logger.LogInformation("Successful OTP verification for phone {Phone}", request.Phone);

        // Role is always Tourist for standard users; vendor role is issued via
        // the separate /api/vendor/auth/verify endpoint after DB validation.
        const UserRole role = UserRole.Tourist;
        var user = await _userResolver.GetOrCreateAsync(request.Name ?? "PondyTripper", request.Phone, role, cancellationToken);

        // Block deleted/deactivated accounts from getting new tokens.
        if (!user.IsActive)
            throw new UnauthorizedAccessException("This account has been deactivated.");

        // Waitlist conversion: if this phone number was on the pre-launch
        // waitlist, mark it converted and seed the user's wallet with promo
        // credits. Only runs on first registration (wallet doesn't exist yet).
        var waitlistEntry = await _dbContext.WaitlistEntries
            .FirstOrDefaultAsync(w => w.PhoneNumber == request.Phone, cancellationToken);

        if (waitlistEntry is not null && !waitlistEntry.IsConverted)
        {
            var existingWallet = await _dbContext.UserWallets
                .FirstOrDefaultAsync(w => w.UserId == user.Id, cancellationToken);

            if (existingWallet is null)
            {
                var wallet = UserWallet.Create(user.Id, promoBalance: PromoCreditService.WaitlistSignupBonus);
                _dbContext.UserWallets.Add(wallet);
            }
            else
            {
                existingWallet.CreditPromo(PromoCreditService.WaitlistSignupBonus);
            }

            waitlistEntry.MarkConverted();
            await _dbContext.SaveChangesAsync(cancellationToken);
        }

        var accessToken = _jwtTokenFactory.CreateAccessToken(user.Id, user.Phone, user.Role.ToString());

        return new AuthResponse(accessToken, user.Id, user.Name, user.Phone, user.Role.ToString(), user.IsProMember, user.IsVerifiedLocal);
    }
}

public sealed record AuthResponse(string AccessToken, Guid UserId, string Name, string Phone, string Role, bool IsProMember = false, bool IsVerifiedLocal = false);