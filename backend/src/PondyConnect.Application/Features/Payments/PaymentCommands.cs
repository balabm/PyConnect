namespace PondyConnect.Application.Features.Payments;

using FluentValidation;
using MediatR;
using PondyConnect.Domain.Enums;

public sealed record InitiatePaymentCommand(
    Guid? ServiceBookingId,
    Guid? TransitTripId,
    Guid? LuggageDropOffId,
    Guid? ScooterRentalId,
    Guid? FoodOrderId,
    decimal Amount,
    string Currency = "INR",
    PaymentProvider Provider = PaymentProvider.Razorpay,
    PaymentMethod Method = PaymentMethod.Upi) : IRequest<InitiatePaymentResponse>;

public sealed class InitiatePaymentCommandValidator : AbstractValidator<InitiatePaymentCommand>
{
    public InitiatePaymentCommandValidator()
    {
        RuleFor(x => x)
            .Must(x => (x.ServiceBookingId != null ? 1 : 0) +
                       (x.TransitTripId != null ? 1 : 0) +
                       (x.LuggageDropOffId != null ? 1 : 0) +
                       (x.ScooterRentalId != null ? 1 : 0) +
                       (x.FoodOrderId != null ? 1 : 0) == 1)
            .WithMessage("Exactly one booking reference must be provided.");
        RuleFor(x => x.Amount).GreaterThan(0);
        RuleFor(x => x.Currency).NotEmpty().Length(3);
    }
}

public sealed record InitiatePaymentResponse(
    Guid PaymentId,
    string ProviderOrderId,
    string? PaymentUrl);

public sealed record VerifyPaymentWebhookCommand(
    string Payload,
    string Signature) : IRequest<VerifyPaymentWebhookResponse>;

public sealed record VerifyPaymentWebhookResponse(
    bool Success,
    string? PaymentId = null,
    PaymentStatus? Status = null);

public sealed record RefundPaymentCommand(
    Guid PaymentId,
    decimal Amount,
    string Reason) : IRequest<RefundPaymentResponse>;

public sealed class RefundPaymentCommandValidator : AbstractValidator<RefundPaymentCommand>
{
    public RefundPaymentCommandValidator()
    {
        RuleFor(x => x.PaymentId).NotEmpty();
        RuleFor(x => x.Amount).GreaterThan(0);
        RuleFor(x => x.Reason).NotEmpty().MaximumLength(200);
    }
}

public sealed record RefundPaymentResponse(
    bool Success,
    string? RefundId = null);