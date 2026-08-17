namespace PondyConnect.Api.Controllers;

public sealed class AppVersionConfigResponse
{
    public string ConsumerMinVersion { get; set; } = "1.0.0";
    public string CaptainMinVersion { get; set; } = "1.0.0";
    public string PartnerMinVersion { get; set; } = "1.0.0";
    public bool ForceUpdate { get; set; } = true;
}
