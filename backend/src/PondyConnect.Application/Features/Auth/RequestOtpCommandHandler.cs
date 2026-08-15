namespace PondyConnect.Application.Features.Auth;

using MediatR;
using PondyConnect.Application.Common.Interfaces;

public sealed class RequestOtpCommandHandler : IRequestHandler<RequestOtpCommand, OtpRequestedResponse>
{
    private readonly IOtpService _otpService;
    private readonly ISmsSender _smsSender;

    public RequestOtpCommandHandler(IOtpService otpService, ISmsSender smsSender)
    {
        _otpService = otpService;
        _smsSender = smsSender;
    }

    public async Task<OtpRequestedResponse> Handle(RequestOtpCommand request, CancellationToken cancellationToken)
    {
        var code = await _otpService.IssueCodeAsync(request.Phone, cancellationToken);

        // Never log or return the OTP itself in production. For the demo phase
        // the SMS sender "sends" it to the console so local flows can be tested.
        await _smsSender.SendAsync(request.Phone, $"Your PondyConnect OTP is {code}", cancellationToken);

        return new OtpRequestedResponse(request.Phone, OtpExpirySeconds: 300);
    }
}

public sealed record OtpRequestedResponse(string Phone, int OtpExpirySeconds);