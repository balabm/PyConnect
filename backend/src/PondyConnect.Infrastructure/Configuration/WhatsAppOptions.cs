namespace PondyConnect.Infrastructure.Configuration;

public sealed class WhatsAppOptions
{
    public const string SectionName = "WhatsApp";

    public string WebhookVerifyToken { get; set; } = string.Empty;
    public string AppSecret { get; set; } = string.Empty;
    public string PhoneNumberId { get; set; } = string.Empty;
    public string AccessToken { get; set; } = string.Empty;
}
