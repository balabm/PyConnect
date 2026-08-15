namespace PondyConnect.Infrastructure.Configuration;

public sealed class FirebaseOptions
{
    public const string SectionName = "Firebase";

    public string ServiceAccountPath { get; set; } = string.Empty;

    public bool IsEnabled { get; set; }
}
