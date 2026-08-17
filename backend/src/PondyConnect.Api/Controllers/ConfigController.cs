namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

[ApiController]
[Route("api/config")]
public sealed class ConfigController : ControllerBase
{
    private readonly IConfiguration _configuration;

    public ConfigController(IConfiguration configuration) => _configuration = configuration;

    [AllowAnonymous]
    [HttpGet("app-versions")]
    [ProducesResponseType(typeof(AppVersionConfigResponse), StatusCodes.Status200OK)]
    public ActionResult<AppVersionConfigResponse> GetAppVersions()
    {
        var appVersions = _configuration.GetSection("AppVersions");

        var response = new AppVersionConfigResponse
        {
            ConsumerMinVersion = appVersions["ConsumerMinVersion"] ?? "1.0.0",
            CaptainMinVersion = appVersions["CaptainMinVersion"] ?? "1.0.0",
            PartnerMinVersion = appVersions["PartnerMinVersion"] ?? "1.0.0",
            ForceUpdate = true,
        };

        return Ok(response);
    }
}
