namespace PondyConnect.Infrastructure.Services;

/// <summary>
/// Thrown when an SMS delivery attempt fails after all retries.
/// Contains the phone number and underlying error for diagnostics.
/// </summary>
public sealed class SmsDeliveryException : Exception
{
    public string Phone { get; }
    public int? StatusCode { get; }

    public SmsDeliveryException(string phone, string message, int? statusCode = null, Exception? inner = null)
        : base($"SMS delivery to {phone} failed: {message}", inner)
    {
        Phone = phone;
        StatusCode = statusCode;
    }
}
