namespace PondyConnect.Application.Features.Vendor;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;

public sealed class RequestVendorOtpHandler : IRequestHandler<RequestVendorOtpCommand, VendorOtpRequestedResponse>
{
    private readonly IOtpService _otpService;
    private readonly ISmsSender _smsSender;
    private readonly IApplicationDbContext _context;

    public RequestVendorOtpHandler(IOtpService otpService, ISmsSender smsSender, IApplicationDbContext context)
    {
        _otpService = otpService;
        _smsSender = smsSender;
        _context = context;
    }

    public async Task<VendorOtpRequestedResponse> Handle(RequestVendorOtpCommand request, CancellationToken cancellationToken)
    {
        var code = await _otpService.IssueCodeAsync(request.Phone, cancellationToken);
        await _smsSender.SendAsync(request.Phone, $"Your PondyConnect vendor login OTP is {code}", cancellationToken);
        return new VendorOtpRequestedResponse(request.Phone, OtpExpirySeconds: 300);
    }
}

public sealed class VerifyVendorOtpHandler : IRequestHandler<VerifyVendorOtpCommand, VendorLoginResponse>
{
    private readonly IOtpService _otpService;
    private readonly IJwtTokenFactory _jwtTokenFactory;
    private readonly IUserResolver _userResolver;
    private readonly IApplicationDbContext _context;

    public VerifyVendorOtpHandler(
        IOtpService otpService,
        IJwtTokenFactory jwtTokenFactory,
        IUserResolver userResolver,
        IApplicationDbContext context)
    {
        _otpService = otpService;
        _jwtTokenFactory = jwtTokenFactory;
        _userResolver = userResolver;
        _context = context;
    }

    public async Task<VendorLoginResponse> Handle(VerifyVendorOtpCommand request, CancellationToken cancellationToken)
    {
        var isValid = await _otpService.VerifyCodeAsync(request.Phone, request.OtpCode, cancellationToken);
        if (!isValid)
            throw new UnauthorizedAccessException("Invalid or expired OTP.");

        var owner = await _userResolver.GetOrCreateAsync(request.OwnerName ?? "Vendor", request.Phone, UserRole.Vendor, cancellationToken);

        var vendor = await _context.Vendors
            .FirstOrDefaultAsync(v => v.ContactPhone == request.Phone && v.IsApproved && v.IsActive, cancellationToken);
        if (vendor is null)
            throw new UnauthorizedAccessException("No approved vendor account is linked to this phone number.");

        var accessToken = _jwtTokenFactory.CreateAccessToken(owner.Id, owner.Phone, UserRole.Vendor.ToString());

        return new VendorLoginResponse(
            accessToken,
            vendor.Id,
            vendor.Name,
            vendor.Category.ToString(),
            owner.Id,
            owner.Name,
            owner.Phone);
    }
}