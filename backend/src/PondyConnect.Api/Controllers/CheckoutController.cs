namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Fraud;
using PondyConnect.Domain.Enums;

/// <summary>
/// Returns available payment methods for the current user.
/// Users with low trust scores have COD filtered out.
/// </summary>
[ApiController]
[Route("api/checkout")]
[Authorize]
public sealed class CheckoutController : ControllerBase
{
    private readonly RiskInterceptor _riskInterceptor;
    private readonly ICurrentUserService _currentUser;

    public CheckoutController(
        RiskInterceptor riskInterceptor,
        ICurrentUserService currentUser)
    {
        _riskInterceptor = riskInterceptor;
        _currentUser = currentUser;
    }

    /// <summary>
    /// Gets available payment methods for the current user.
    /// COD (Cash) is filtered out for users with trust score below 40.
    /// </summary>
    [HttpGet("payment-methods")]
    [ProducesResponseType(typeof(IReadOnlyList<PaymentMethodResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<PaymentMethodResponse>>> GetPaymentMethods(
        CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        var codDisabled = await _riskInterceptor.IsCodDisabledAsync(userId, ct);

        var methods = new List<PaymentMethodResponse>
        {
            new("upi", "UPI", "Pay via any UPI app", IsEnabled: true),
            new("card", "Card", "Credit / Debit Card", IsEnabled: true),
            new("netbanking", "Net Banking", "All major banks", IsEnabled: true),
            new("wallet", "PY Wallet", "Pay from your PY Connect wallet", IsEnabled: true),
            new("cash", "Cash on Delivery", "Pay with cash when your order arrives", IsEnabled: !codDisabled)
        };

        // Filter out disabled methods (COD for low-trust users)
        var available = methods.Where(m => m.IsEnabled).ToList();

        return Ok(available);
    }
}

public sealed record PaymentMethodResponse(
    string Code,
    string Label,
    string Description,
    bool IsEnabled);
