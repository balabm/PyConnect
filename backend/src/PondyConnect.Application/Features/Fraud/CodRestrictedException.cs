namespace PondyConnect.Application.Features.Fraud;

/// <summary>
/// Thrown when a consumer who is currently restricted from Cash-on-Delivery
/// attempts to place a COD order. Mapped to HTTP 403 Forbidden by the
/// exception-handling middleware.
/// </summary>
public sealed class CodRestrictedException : Exception
{
    public const string DefaultMessage = "Cash on Delivery is temporarily unavailable for your account. Please pay online.";

    public CodRestrictedException() : base(DefaultMessage)
    {
    }

    public CodRestrictedException(string message) : base(message)
    {
    }
}
