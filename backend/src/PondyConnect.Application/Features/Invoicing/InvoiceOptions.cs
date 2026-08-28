namespace PondyConnect.Application.Features.Invoicing;

/// <summary>
/// Configuration options for GST invoice generation.
/// Bound to the "Invoicing" section of appsettings.json.
/// </summary>
public sealed class InvoiceOptions
{
    public const string SectionName = "Invoicing";

    /// <summary>Platform GSTIN as it should appear on generated invoices.</summary>
    public string PlatformGstin { get; set; } = string.Empty;

    /// <summary>Legal entity name of the platform operator.</summary>
    public string PlatformName { get; set; } = string.Empty;

    /// <summary>Registered address of the platform operator.</summary>
    public string PlatformAddress { get; set; } = string.Empty;
}
